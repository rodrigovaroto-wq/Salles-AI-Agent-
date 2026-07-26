-- Migração: entrega do produto pelo WhatsApp após o pagamento.
-- Rode no SQL Editor do Supabase. Idempotente.
--
-- POR QUE: até aqui, `transaction.paid` marcava o lead como cliente, mandava
-- "em instantes você recebe os detalhes de acesso" -- e nada entregava. A
-- cliente pagava e não recebia. Agora o agente entrega pelo WhatsApp, lendo o
-- conteúdo de cada produto daqui.
--
-- O conteúdo mora no catálogo (e não no código do workflow) pelo mesmo motivo
-- que o preço: quando o Padre Frei trocar um áudio ou o link do grupo mudar,
-- é um UPDATE nesta tabela, sem mexer em workflow nem republicar nada.

begin;

-- ========== 1. O que cada produto entrega ==========
alter table produtos add column if not exists entrega_texto text;

comment on column produtos.entrega_texto is
  'Mensagem de acesso enviada pelo WhatsApp após o pagamento confirmado. '
  'Escreva como o padre falaria com a pessoa -- é a primeira coisa que ela '
  'recebe depois de pagar. Inclua o link/instrução real de acesso. '
  'NULL = produto sem entrega definida: o cliente recebe um aviso de que o '
  'acesso chega em seguida e o Rodrigo é alertado para entregar na mão.';

-- ========== 2. Registrar a entrega no histórico ==========
-- 'entrega' não existia na lista de etapas; sem isso o INSERT é rejeitado
-- pelo CHECK e a entrega acontece sem deixar rastro.
alter table conversas drop constraint if exists conversas_etapa_processo_check;

alter table conversas add constraint conversas_etapa_processo_check
  check (etapa_processo in ('conexao','descoberta','apresentacao','objecao',
                            'fechamento','recuperacao','upsell','entrega'));

commit;

-- ========== 3. PREENCHER O CONTEÚDO REAL ==========
-- Sem isto, todo cliente cai no caminho de "acesso em seguida" e você entrega
-- na mão. Substitua os textos abaixo pelos links e instruções de verdade e
-- rode este bloco.
--
-- update produtos set entrega_texto =
--   'Que alegria ter você aqui. Sua Oração Sagrada está pronta: <LINK>. '
--   'Guarde essa mensagem para acessar quando quiser.'
--   where produto_id = 'oracao_sagrada';
--
-- update produtos set entrega_texto =
--   'Aqui está a sua Oração em Áudio, gravada pelo Padre Frei: <LINK>'
--   where produto_id = 'oracao_audio';
--
-- update produtos set entrega_texto =
--   'Seu acesso à Comunidade: <LINK DO GRUPO>. É só entrar que já te recebemos.'
--   where produto_id = 'comunidade';
--
-- update produtos set entrega_texto =
--   'Pronto: você já pode acompanhar as mensagens e orientações do Padre Frei '
--   'por aqui: <LINK/INSTRUÇÃO>'
--   where produto_id = 'contato_padre';

-- ========== Conferir ==========
--   select produto_id, nome,
--          case when entrega_texto is null then '❌ FALTA' else '✅ ok' end as entrega
--   from produtos where ativo order by ordem;
