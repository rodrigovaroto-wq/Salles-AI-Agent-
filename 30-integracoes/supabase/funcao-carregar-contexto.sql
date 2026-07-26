-- Função que carrega, numa chamada só, tudo que o agente precisa para responder.
-- Rode no SQL Editor do Supabase. Idempotente (`create or replace`).
--
-- POR QUE: o `agente-vendas` fazia três GETs em paralelo (histórico, prompt ativo,
-- catálogo) e precisava de DOIS nós `Merge` só para esperar os três terminarem --
-- sem essa barreira, o nó seguinte rodava mais de uma vez e duplicava a chamada à
-- OpenAI e o envio no WhatsApp. Isso é 3 idas ao banco por mensagem recebida, na
-- latência que o lead sente, mais dois nós cuja única função era sincronizar.
--
-- Com esta função vira 1 ida, sem merge nenhum. Some a fragilidade do
-- `mergeByPosition` (que casa itens por índice e erra em silêncio se um dos lados
-- vier com contagem diferente) e caem 4 nós do caminho quente.
--
-- Chamada pelo n8n:
--   POST {SUPABASE_URL}/rest/v1/rpc/carregar_contexto
--   body: {"p_lead_id": "<wa_id>"}

create or replace function carregar_contexto(p_lead_id text)
returns json
language sql
stable
as $$
  select json_build_object(

    -- Mesma janela de antes: 10 eventos mais recentes. Vem em ordem decrescente;
    -- quem monta o prompt inverte, para a conversa chegar ao modelo em ordem
    -- cronológica.
    'historico', coalesce((
      select json_agg(h) from (
        select mensagem_lead, mensagem_agente, ocorrido_em
        from conversas
        where lead_id = p_lead_id
        order by ocorrido_em desc
        limit 10
      ) h
    ), '[]'::json),

    -- As três chaves que compõem o system prompt.
    'prompts', coalesce((
      select json_agg(p) from (
        select chave, conteudo
        from prompt_ativo
        where ativo and chave in ('objetivo','compliance','objecoes')
      ) p
    ), '[]'::json),

    -- Catálogo real. Fonte de verdade em runtime -- preço nunca é hardcoded no
    -- workflow.
    'produtos', coalesce((
      select json_agg(pr) from (
        select produto_id, nome, tipo, preco_centavos, ordem,
               resolve_objecao, arquetipos
        from produtos
        where ativo
        order by ordem
      ) pr
    ), '[]'::json)
  );
$$;

-- Sem `security definer` de propósito: a função roda com os privilégios de quem
-- chama. O n8n usa a service_role (que ignora RLS), então funciona; e se um dia
-- for chamada por um role restrito, ela respeita as permissões desse role em vez
-- de virar um contorno silencioso do RLS.
grant execute on function carregar_contexto(text) to service_role;

-- ========== Conferir ==========
--   select carregar_contexto('lead_que_existe');
--
-- Deve devolver as três chaves. `historico` vazio é normal num lead novo;
-- `prompts` ou `produtos` vazios significam que o seed não rodou -- o agente
-- responderia sem playbook e sem catálogo.
