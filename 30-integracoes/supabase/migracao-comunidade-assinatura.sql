-- Migração: Comunidade vira assinatura (entrada 1x + mensalidade) e a entrega
-- ganha suporte a mídia (PDF e áudios enviados no próprio chat do WhatsApp).
-- Rode no SQL Editor do Supabase. Idempotente — pode rodar de novo sem risco.
--
-- Modelo comercial definido em 27/07:
--   Comunidade = R$ 44,90 de entrada (1x, é o preço já cadastrado)
--              + R$ 9,78/mês, com os primeiros 30 dias grátis.
--   A mensalidade só começa a ser cobrada no dia 31.

-- ---------------------------------------------------------------------------
-- 1. produtos: campos de recorrência e de entrega por mídia
-- ---------------------------------------------------------------------------

alter table produtos add column if not exists mensalidade_centavos integer;
alter table produtos add column if not exists trial_dias           integer;
-- entrega_midia: lista de partes enviadas ANTES do entrega_texto, no chat.
-- Formato: [{"tipo":"documento","url":"https://...","filename":"...","legenda":"..."},
--           {"tipo":"audio","url":"https://..."}]
-- URLs públicas (Supabase Storage). Áudio não aceita legenda na API do WhatsApp.
alter table produtos add column if not exists entrega_midia jsonb not null default '[]'::jsonb;

comment on column produtos.mensalidade_centavos is
  'Assinatura mensal em centavos. NULL = produto sem recorrencia.';
comment on column produtos.trial_dias is
  'Dias gratis antes da primeira mensalidade. NULL ou 0 = cobra desde o inicio.';
comment on column produtos.entrega_midia is
  'Partes de midia da entrega (documento/audio), enviadas antes do entrega_texto.';

update produtos
   set mensalidade_centavos = 978,
       trial_dias           = 30
 where produto_id = 'comunidade';

-- Contato Direto com o Padre: entrada R$ 19,90 + R$ 5,47/mes, tambem com 30
-- dias gratis (decidido 27/07).
update produtos
   set mensalidade_centavos = 547,
       trial_dias           = 30
 where produto_id = 'contato_padre';

-- ---------------------------------------------------------------------------
-- 2. assinaturas: uma linha por lead que entrou num produto recorrente
-- ---------------------------------------------------------------------------

create table if not exists assinaturas (
  assinatura_id     bigint generated always as identity primary key,
  lead_id           text not null references leads(lead_id) on delete cascade,
  produto_id        text not null references produtos(produto_id),
  status            text not null default 'trial'
                    check (status in ('trial','ativa','inadimplente','cancelada')),
  criada_em         timestamptz not null default now(),
  trial_ate         timestamptz,          -- fim dos dias gratis
  proxima_cobranca  timestamptz,          -- proxima mensalidade a gerar
  ultimo_pagamento  timestamptz,
  valor_centavos    integer not null,     -- congelado na adesao: reajuste nao pega quem ja entrou
  cancelada_em      timestamptz,
  unique (lead_id, produto_id)
);

comment on table assinaturas is
  'Recorrencia da Comunidade (e futuros produtos recorrentes). Criada no webhook '
  'paid da entrada; a mensalidade e gerada por workflow a partir de proxima_cobranca.';

create index if not exists idx_assinaturas_cobranca
  on assinaturas (proxima_cobranca)
  where status in ('trial','ativa');

-- ---------------------------------------------------------------------------
-- 3. Conferência
-- ---------------------------------------------------------------------------

select produto_id, nome, preco_centavos as entrada_centavos,
       mensalidade_centavos, trial_dias,
       jsonb_array_length(entrega_midia) as partes_midia,
       case when entrega_texto is null then '❌ FALTA' else '✅ ok' end as entrega_texto
from produtos where ativo order by ordem;

-- ---------------------------------------------------------------------------
-- 4. Textos de entrega aprovados em 27/07
-- ---------------------------------------------------------------------------
-- {LINK_COMUNIDADE} é substituído em runtime pelo valor da chave
-- 'link_comunidade' em configuracoes (ver migracao-config.sql).

update produtos set entrega_texto =
'Aqui está a sua Oração Sagrada de São Bento 🙏
Ela é sua para sempre — salve este arquivo com carinho.
O Padre Frei recomenda começar hoje mesmo, num momento de silêncio.'
where produto_id = 'oracao_sagrada';

update produtos set entrega_texto =
'Estes são os áudios da Oração, gravados pelo próprio Padre Frei.
Pode ouvir onde estiver — em casa, no ônibus, antes de dormir.'
where produto_id = 'oracao_audio';

update produtos set entrega_texto =
'Seja bem-vinda à Comunidade do Padre Frei 🙏
Toque aqui para entrar: {LINK_COMUNIDADE}
Lá você recebe áudios e mensagens diárias do padre, além de conteúdos exclusivos antes de todo mundo. Seus primeiros 30 dias são um presente; depois são só R$ 9,78 por mês, e você cancela quando quiser.'
where produto_id = 'comunidade';

update produtos set entrega_texto =
'Seu Contato Direto com o Padre está ativo.
Ele acontece aqui pelo WhatsApp: é neste canal que você deixa sua mensagem e seus pedidos de oração, e o Padre Frei lê e responde.
Seus primeiros 30 dias são um presente; depois são R$ 5,47 por mês, e você cancela quando quiser.'
where produto_id = 'contato_padre';
