-- Migração: tabela de configurações (chave/valor) para valores operacionais que
-- mudam sem republicar workflow — hoje, o link da Comunidade.
-- Rode no SQL Editor do Supabase. Idempotente.
--
-- Substitui a migracao-links-comunidade.sql (fila de links individuais), que foi
-- descartada em 27/07: decidido que o link do grupo é único e universal.

create table if not exists configuracoes (
  chave       text primary key,
  valor       text not null,
  descricao   text,
  atualizado_em timestamptz not null default now()
);

comment on table configuracoes is
  'Valores operacionais lidos em runtime. Trocar um valor e um UPDATE, sem '
  'republicar workflow nem reescrever texto de entrega.';

insert into configuracoes (chave, valor, descricao) values
  ('link_comunidade',
   '<<COLE_AQUI_O_LINK_DO_GRUPO>>',
   'Link de convite do grupo da Comunidade. Unico e universal. Substituido em '
   'runtime no lugar de {LINK_COMUNIDADE} no entrega_texto.')
on conflict (chave) do nothing;

-- Trocar o link depois:
-- update configuracoes set valor = 'https://chat.whatsapp.com/XXXX',
--        atualizado_em = now()
--  where chave = 'link_comunidade';

select chave,
       case when valor like '<<%' then '❌ FALTA PREENCHER' else valor end as valor,
       atualizado_em
from configuracoes order by chave;
