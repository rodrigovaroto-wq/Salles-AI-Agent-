-- Role Postgres restrito para o Hermes, no lugar da service_role key.
-- Rode no SQL Editor do Supabase. Idempotente: pode rodar de novo sem estragar nada.
--
-- POR QUE: a service_role key dá acesso total ao banco e ignora RLS. O Hermes é um
-- analista assíncrono -- ele só precisa ler conversas/métricas e escrever sugestões
-- na fila. Com a service_role key, um prompt mal formulado (ou comprometido) podia
-- apagar leads, reescrever prompt_ativo ou vazar PII. Este role torna isso
-- impossível no nível do banco, não por confiança no agente.
--
-- O QUE ELE **NÃO** ALCANÇA, DE PROPÓSITO:
--   * `leads`         -- nome, e-mail, CPF, telefone. O Hermes analisa o texto das
--                        conversas; não tem por que ver PII (LGPD, minimização).
--   * `prompt_ativo`  -- quem aplica mudança aprovada é o n8n (fila-decidir), depois
--                        do seu aval. O Hermes propõe, nunca aplica.
--   * `produtos`      -- catálogo e preço são fatos operacionais, não hipóteses.
--   * qualquer UPDATE/DELETE -- ele só insere sugestões; nunca edita nem apaga.

begin;

-- ========== 1. O role ==========
-- NOLOGIN: ninguém se conecta como ele diretamente. O PostgREST assume este role
-- via `SET ROLE` quando o JWT traz a claim role=hermes_agent.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'hermes_agent') then
    create role hermes_agent nologin;
  end if;
end
$$;

-- O `authenticator` é o role com que o PostgREST se conecta; ele precisa poder
-- assumir o hermes_agent, senão o JWT é aceito mas o SET ROLE falha.
grant hermes_agent to authenticator;

grant usage on schema public to hermes_agent;

-- ========== 2. Privilégios de tabela (mínimo necessário) ==========
-- Leitura: o material de análise.
grant select on conversas        to hermes_agent;
grant select on metricas_periodo to hermes_agent;

-- fila_sugestoes: lê para saber onde parou (cursor = criado_em mais recente)
-- e insere as hipóteses novas. Sem update/delete -- não pode decidir a própria
-- sugestão nem apagar rastro.
grant select, insert on fila_sugestoes to hermes_agent;

-- ========== 3. RLS ==========
-- As tabelas têm RLS ligado e nenhuma policy: a service_role passa porque tem
-- BYPASSRLS. O hermes_agent NÃO tem BYPASSRLS (de propósito), então sem policy
-- explícita ele enxergaria zero linha. As policies abaixo abrem exatamente o
-- que o GRANT acima já permite -- as duas camadas precisam concordar.
drop policy if exists hermes_le_conversas on conversas;
create policy hermes_le_conversas on conversas
  for select to hermes_agent using (true);

drop policy if exists hermes_le_metricas on metricas_periodo;
create policy hermes_le_metricas on metricas_periodo
  for select to hermes_agent using (true);

drop policy if exists hermes_le_fila on fila_sugestoes;
create policy hermes_le_fila on fila_sugestoes
  for select to hermes_agent using (true);

-- Só aceita inserção com status='pendente': o Hermes não consegue gravar uma
-- sugestão já marcada como aprovada e pular o seu aval. O gate humano vira
-- garantia do banco, não convenção.
drop policy if exists hermes_insere_pendente on fila_sugestoes;
create policy hermes_insere_pendente on fila_sugestoes
  for insert to hermes_agent with check (status = 'pendente');

commit;

-- ========== 4. Conferir ==========
-- Deve listar conversas/metricas_periodo (SELECT) e fila_sugestoes (SELECT, INSERT).
-- Se `leads`, `prompt_ativo` ou `produtos` aparecerem aqui, algo saiu errado.
--
--   select table_name, privilege_type
--   from information_schema.role_table_grants
--   where grantee = 'hermes_agent'
--   order by table_name, privilege_type;
