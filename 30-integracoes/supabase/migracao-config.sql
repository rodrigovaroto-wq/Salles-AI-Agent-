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

-- ---------------------------------------------------------------------------
-- Segredo do webhook do BravoPay (adicionado 30/07)
-- ---------------------------------------------------------------------------
-- Mora aqui e não em variável de ambiente porque o PikaPods não expõe $env, e
-- um node Code do n8n não consegue ler Credential. O banco é o único lugar que
-- o node de validação alcança.
--
-- Trocar o segredo = UPDATE nesta linha, sem republicar workflow.

insert into configuracoes (chave, valor, descricao) values
  ('bravopay_webhook_secret',
   '<<COLE_AQUI_O_WEBHOOK_SECRET_DO_BRAVOPAY>>',
   'Segredo HMAC-SHA256 do webhook BravoPay. Lido pelo node "Validar assinatura" '
   'do workflow pagamento-bravopay.')
on conflict (chave) do nothing;

select chave,
       case when valor like '<<%' then '❌ FALTA PREENCHER'
            else '✅ preenchido (' || length(valor) || ' chars)' end as estado
from configuracoes order by chave;
