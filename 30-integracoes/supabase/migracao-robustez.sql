-- Migração de robustez — corrige os 13 achados da auditoria de 2026-07-26.
-- Rode no SQL Editor do Supabase. Idempotente.
--
-- Cada bloco diz qual defeito fecha. A lógica que exige atomicidade (upsert que
-- não sobrescreve estado, append de compra, buffer de mensagens) virou função:
-- em PostgREST não dá para expressar "atualize só se ainda for nulo" nem
-- "concatene ao array existente" num PATCH, e tentar fazer isso em dois passos
-- abre janela de corrida.

begin;

-- ══════════════════════════════════════════════════════════════════
-- 1. Colunas novas
-- ══════════════════════════════════════════════════════════════════

-- #1 follow-up reenviado de hora em hora, para sempre
alter table leads add column if not exists ultimo_followup_em timestamptz;
alter table leads add column if not exists followups_enviados integer not null default 0;

-- #8 mensagens concorrentes (buffer de debounce)
alter table leads add column if not exists buffer_mensagens text[] not null default '{}';
alter table leads add column if not exists ultima_msg_id text;

-- #13 link duplicado quando a lead pede duas vezes
alter table leads add column if not exists ultimo_link_url text;
alter table leads add column if not exists ultimo_link_em timestamptz;

-- #12 digest do Hermes reenvia as mesmas sugestões todo dia
alter table fila_sugestoes add column if not exists notificado_em timestamptz;

comment on column leads.followups_enviados is
  'Quantos follow-ups pós-24h já foram enviados. O teto vive na query do '
  'followup-24h; sem este contador o mesmo lead recebia template toda hora.';
comment on column leads.buffer_mensagens is
  'Mensagens recebidas aguardando o debounce. Quem manda 3 mensagens seguidas '
  'recebe UMA resposta que considera as três, em vez de três respostas cegas.';

-- ══════════════════════════════════════════════════════════════════
-- 2. Idempotência de webhook  (#5)
-- ══════════════════════════════════════════════════════════════════
-- WhatsApp e BlackCat reenviam o webhook quando não recebem 200 a tempo. Sem
-- isto, o reenvio gera resposta duplicada e — no pagamento — ENTREGA duplicada.
create table if not exists eventos_processados (
  chave      text primary key,   -- ex.: 'wa:<message_id>' | 'bc:<transactionId>:<event>'
  criado_em  timestamptz not null default now()
);
create index if not exists idx_eventos_criado on eventos_processados(criado_em);

alter table eventos_processados enable row level security;

comment on table eventos_processados is
  'Trava de idempotência. O workflow insere com Prefer: resolution=ignore-duplicates; '
  'resposta vazia significa "já processado" e a execução para ali.';

-- ══════════════════════════════════════════════════════════════════
-- 3. registrar_lead  (#2 e origem sobrescrita)
-- ══════════════════════════════════════════════════════════════════
-- O upsert antigo mandava status='ativo' em TODA mensagem, apagando três
-- estados que importam: opt_out (a pessoa pediu para parar), aguardando_humano
-- (escalada por sofrimento) e cliente. Também sobrescrevia a origem: quem veio
-- da LP e depois mandava mensagem sem o marcador virava tiktok_ads.
--
-- Aqui o status NUNCA é tocado, e a origem só entra se ainda não houver uma.
create or replace function registrar_lead(
  p_lead_id text,
  p_nome    text,
  p_origem  text
)
returns leads
language plpgsql
as $$
declare
  v_lead leads;
begin
  insert into leads (lead_id, nome, origem_canal, ultima_interacao, consentimento_contato)
  values (
    p_lead_id,
    p_nome,
    p_origem,
    now(),
    true   -- a conversa começou por iniciativa dela (o webhook só dispara em mensagem recebida)
  )
  on conflict (lead_id) do update set
    ultima_interacao = now(),
    nome         = coalesce(excluded.nome, leads.nome),
    origem_canal = coalesce(leads.origem_canal, excluded.origem_canal)
    -- status, consentimento_contato e produtos_comprados ficam intactos de propósito
  returning * into v_lead;

  return v_lead;
end;
$$;

comment on function registrar_lead is
  'Upsert que preserva estado. consentimento_contato=true só na criação: a lead '
  'iniciou o contato. Quem pede para parar vira opt_out, e daí em diante nem o '
  'status nem o consentimento são reescritos por mensagem nova.';

-- ══════════════════════════════════════════════════════════════════
-- 4. Debounce de mensagens  (#8)
-- ══════════════════════════════════════════════════════════════════
-- Três mensagens seguidas disparavam três execuções paralelas; cada uma lia o
-- histórico sem as outras e respondia. Três respostas desencontradas.
--
-- Agora cada mensagem entra num buffer e a execução espera. Só a ÚLTIMA
-- consome o buffer inteiro e responde; as anteriores encerram em silêncio.

create or replace function bufferizar_mensagem(
  p_lead_id text,
  p_msg_id  text,
  p_texto   text
)
returns void
language sql
as $$
  update leads
     set buffer_mensagens = buffer_mensagens || p_texto,
         ultima_msg_id    = p_msg_id
   where lead_id = p_lead_id;
$$;

create or replace function consumir_buffer(
  p_lead_id text,
  p_msg_id  text
)
returns text
language plpgsql
as $$
declare
  v_texto text;
begin
  -- Só quem ainda é a última mensagem tem direito de responder.
  -- Se outra chegou durante a espera, esta execução sai de mãos vazias.
  update leads
     set buffer_mensagens = '{}'
   where lead_id = p_lead_id
     and ultima_msg_id = p_msg_id
  returning array_to_string(buffer_mensagens, E'\n') into v_texto;

  return v_texto;   -- NULL = superada por mensagem mais nova
end;
$$;

-- ══════════════════════════════════════════════════════════════════
-- 5. registrar_compra  (#6)
-- ══════════════════════════════════════════════════════════════════
-- produtos_comprados era SOBRESCRITO: quem comprava o principal e depois a
-- Comunidade perdia o registro do primeiro. Agora acumula.
create or replace function registrar_compra(
  p_lead_id text,
  p_items   jsonb
)
returns leads
language plpgsql
as $$
declare
  v_lead leads;
begin
  update leads
     set produtos_comprados = coalesce(produtos_comprados, '[]'::jsonb) || coalesce(p_items, '[]'::jsonb),
         status             = 'cliente',
         etapa_funil        = case
                                when etapa_funil = 'comprou_principal' then 'comprou_upsell'
                                else 'comprou_principal'
                              end,
         ultima_interacao   = now(),
         ultimo_link_url    = null,   -- link consumido
         ultimo_link_em     = null
   where lead_id = p_lead_id
  returning * into v_lead;

  return v_lead;
end;
$$;

-- ══════════════════════════════════════════════════════════════════
-- 6. carregar_contexto v2  (#10 e #11)
-- ══════════════════════════════════════════════════════════════════
-- Mudanças: janela de 10 → 20 eventos, e só eventos que têm mensagem. Entrega,
-- fechamento e follow-up também gravam em `conversas`; sem o filtro, uma
-- conversa com compra gastava slots do histórico com registros sem texto e o
-- agente perdia o começo da conversa.
--
-- Passa a devolver também o lead — o agente precisa saber o que a pessoa JÁ
-- COMPROU (senão tenta vender de novo) e em que estado ela está.
create or replace function carregar_contexto(p_lead_id text)
returns json
language sql
stable
as $$
  select json_build_object(

    'historico', coalesce((
      select json_agg(h) from (
        select mensagem_lead, mensagem_agente, ocorrido_em
        from conversas
        where lead_id = p_lead_id
          and (mensagem_lead is not null or mensagem_agente is not null)
        order by ocorrido_em desc
        limit 20
      ) h
    ), '[]'::json),

    'prompts', coalesce((
      select json_agg(p) from (
        select chave, conteudo
        from prompt_ativo
        where ativo and chave in ('objetivo','compliance','objecoes')
      ) p
    ), '[]'::json),

    'produtos', coalesce((
      select json_agg(pr) from (
        select produto_id, nome, tipo, preco_centavos, ordem,
               resolve_objecao, arquetipos
        from produtos
        where ativo
        order by ordem
      ) pr
    ), '[]'::json),

    'lead', (
      select json_build_object(
        'status',             l.status,
        'email',              l.email,
        'cpf',                l.cpf,
        'produtos_comprados', coalesce(l.produtos_comprados, '[]'::jsonb),
        'ultimo_link_url',    l.ultimo_link_url,
        'link_recente',       (l.ultimo_link_em is not null
                               and l.ultimo_link_em > now() - interval '30 minutes')
      )
      from leads l where l.lead_id = p_lead_id
    )
  );
$$;

grant execute on function carregar_contexto(text)                 to service_role;
grant execute on function registrar_lead(text, text, text)        to service_role;
grant execute on function bufferizar_mensagem(text, text, text)   to service_role;
grant execute on function consumir_buffer(text, text)             to service_role;
grant execute on function registrar_compra(text, jsonb)           to service_role;

commit;

-- ══════════════════════════════════════════════════════════════════
-- Conferir
-- ══════════════════════════════════════════════════════════════════
--   select proname from pg_proc
--   where proname in ('registrar_lead','bufferizar_mensagem','consumir_buffer',
--                     'registrar_compra','carregar_contexto');
--   -- devem aparecer as 5
--
--   select carregar_contexto('lead_inexistente');
--   -- historico/prompts/produtos preenchidos, lead = null
