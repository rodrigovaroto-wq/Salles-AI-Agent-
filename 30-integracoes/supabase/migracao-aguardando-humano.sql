-- Migração: permite o status 'aguardando_humano' em leads.
-- Rode no SQL Editor do Supabase. Idempotente.
--
-- POR QUE É OBRIGATÓRIA: o handoff por sofrimento real (agente-vendas.json, nó
-- "Marcar sofrimento na conversa") grava `status = 'aguardando_humano'`. O CHECK
-- original de `leads.status` só aceitava ('ativo','abandonou','cliente','opt_out'),
-- então o Postgres REJEITARIA essa gravação -- e o mecanismo de segurança falharia
-- exatamente na situação em que ele existe para agir.
--
-- Sem esta migração, o handoff não funciona. Rode antes de ativar o workflow novo.
--
-- Quem já rodou o `schema.sql` atualizado num banco limpo não precisa desta
-- migração (o CHECK já nasce com o valor); ela existe para bancos que foram
-- criados antes.

begin;

alter table leads drop constraint if exists leads_status_check;

alter table leads add constraint leads_status_check
  check (status in ('ativo','abandonou','cliente','opt_out','aguardando_humano'));

commit;

-- ========== Conferir ==========
-- Deve listar os cinco valores, incluindo aguardando_humano:
--
--   select pg_get_constraintdef(oid)
--   from pg_constraint
--   where conname = 'leads_status_check';
--
-- Teste real do caminho todo (use um lead_id que exista):
--
--   update leads set status = 'aguardando_humano' where lead_id = '<algum_lead>';
--   -- se der erro de constraint, a migração não pegou
--   update leads set status = 'ativo' where lead_id = '<algum_lead>';  -- desfaz
