-- Migração: áudios que o agente pode enviar durante a conversa para converter.
-- Rode no SQL Editor do Supabase. Idempotente.
--
-- Diferente de `produtos.entrega_midia` (o que a cliente recebe DEPOIS de
-- pagar), estes são áudios usados ANTES da compra — a voz do Padre Frei
-- entrando na conversa no momento certo.

create table if not exists audios_agente (
  chave        text primary key,
  url          text not null,
  descricao    text not null,   -- o que o áudio diz, em uma linha
  quando_usar  text not null,   -- critério que o agente lê para decidir
  duracao_seg  integer,
  ativo        boolean not null default true,
  ordem        integer not null default 0
);

comment on table audios_agente is
  'Audios que o agente pode enviar durante a conversa. O prompt recebe chave + '
  'descricao + quando_usar; o agente devolve a chave no campo `audio` do JSON '
  'e o workflow envia. URL publica (Supabase Storage).';

-- ---------------------------------------------------------------------------
-- Cadastro dos áudios — preencher quando os arquivos estiverem hospedados.
-- `quando_usar` é lido pelo agente: seja específico, é o que evita o áudio
-- sair na hora errada.
-- ---------------------------------------------------------------------------
-- insert into audios_agente (chave, url, descricao, quando_usar, duracao_seg, ordem) values
--   ('boas_vindas',
--    'https://<projeto>.supabase.co/storage/v1/object/public/entrega/audios-conversao/boas-vindas.ogg',
--    'Padre Frei se apresenta e acolhe quem chegou pelo anuncio',
--    'Na primeira ou segunda mensagem, quando a lead demonstra interesse real. Nunca duas vezes na mesma conversa.',
--    38, 0),
--   ('bencao',
--    'https://<projeto>.supabase.co/storage/v1/object/public/entrega/audios-conversao/bencao.ogg',
--    'Bencao curta do Padre Frei',
--    'Quando a lead compartilha uma dor (P2) ou pede oracao. Nunca emendar oferta na mesma mensagem.',
--    25, 1)
-- on conflict (chave) do update set
--   url = excluded.url, descricao = excluded.descricao,
--   quando_usar = excluded.quando_usar, duracao_seg = excluded.duracao_seg;

select chave, descricao, quando_usar, ativo from audios_agente order by ordem;
