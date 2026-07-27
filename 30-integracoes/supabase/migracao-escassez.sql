-- Migração: prazo real da oferta (lastro para o gatilho de escassez).
-- Rode no SQL Editor do Supabase. Idempotente — pode rodar de novo sem risco.
--
-- Por que existe: "as vagas fecham hoje" dito todo dia é falso em todos os dias
-- menos um. Com esta coluna o agente só fala em fechamento quando existe
-- fechamento. NULL = sem prazo cadastrado => o agente vende por valor, não por
-- relógio. Ver 10-skills/gatilhos/gatilhos-espirituais.md, seção Escassez.

alter table produtos add column if not exists oferta_encerra_em timestamptz;

comment on column produtos.oferta_encerra_em is
  'Prazo real da oferta. NULL = sem prazo; o agente nao fala em vagas/fechamento.';

-- Exemplo — turma que encerra num domingo às 23h59 (descomente e ajuste):
-- update produtos set oferta_encerra_em = '2026-08-09 23:59:00-03'
--  where produto_id = 'comunidade';

-- Conferência:
select produto_id,
       nome,
       case
         when oferta_encerra_em is null then 'sem prazo (nao fala em vagas)'
         when oferta_encerra_em < now() then 'VENCIDO — corrigir ou limpar'
         else 'encerra em ' || to_char(oferta_encerra_em, 'DD/MM HH24:MI')
       end as escassez
from produtos
where ativo
order by ordem;
