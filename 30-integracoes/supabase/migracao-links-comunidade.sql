-- Migração: pool de links individuais da Comunidade (1 acesso por link) e
-- controle de cobrança mensal por link enviado.
-- Rode no SQL Editor do Supabase. Idempotente.
--
-- Decisão 27/07: cada compradora recebe um link próprio, com direito a 1
-- acesso. Como não existe API do WhatsApp para gerar convite de grupo, os
-- links são criados em lote no app pelo admin e cadastrados aqui; a entrega
-- consome um da fila.

create table if not exists links_comunidade (
  link_id      bigint generated always as identity primary key,
  url          text not null unique,
  status       text not null default 'disponivel'
               check (status in ('disponivel','entregue','revogado')),
  lead_id      text references leads(lead_id) on delete set null,
  entregue_em  timestamptz,
  criado_em    timestamptz not null default now()
);

comment on table links_comunidade is
  'Fila de links de convite individuais da Comunidade. Um link por compradora, '
  '1 acesso cada. Reabastecer manualmente quando o alerta de estoque baixo sair.';

create index if not exists idx_links_disponiveis
  on links_comunidade (link_id) where status = 'disponivel';

-- Consome um link da fila de forma atômica (evita entregar o mesmo link a duas
-- compradoras simultâneas). Devolve NULL se a fila estiver vazia -- nesse caso a
-- entrega avisa a cliente e alerta o Rodrigo, em vez de mandar link inválido.
create or replace function consumir_link_comunidade(p_lead_id text)
returns text
language plpgsql
as $$
declare
  v_url text;
begin
  -- se a lead já recebeu um link antes, devolve o mesmo (reenvio idempotente)
  select url into v_url from links_comunidade
   where lead_id = p_lead_id and status = 'entregue' limit 1;
  if v_url is not null then
    return v_url;
  end if;

  update links_comunidade
     set status = 'entregue', lead_id = p_lead_id, entregue_em = now()
   where link_id = (
     select link_id from links_comunidade
      where status = 'disponivel'
      order by link_id
      for update skip locked
      limit 1
   )
  returning url into v_url;

  return v_url;  -- NULL se a fila acabou
end;
$$;

-- Quantos links ainda restam. O workflow alerta o Rodrigo abaixo de 10.
create or replace view estoque_links_comunidade as
  select count(*) filter (where status = 'disponivel') as disponiveis,
         count(*) filter (where status = 'entregue')   as entregues
    from links_comunidade;

-- ---------------------------------------------------------------------------
-- Cadastro dos links (cole os convites gerados no WhatsApp, um por linha):
-- ---------------------------------------------------------------------------
-- insert into links_comunidade (url) values
--   ('https://chat.whatsapp.com/XXXXXXXXXXXX'),
--   ('https://chat.whatsapp.com/YYYYYYYYYYYY')
-- on conflict (url) do nothing;

select * from estoque_links_comunidade;
