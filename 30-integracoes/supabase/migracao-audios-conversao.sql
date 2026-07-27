-- Migração: áudios que o agente envia DURANTE a conversa, na voz do Padre Frei.
-- Rode no SQL Editor do Supabase. Idempotente.
--
-- Diferente de `produtos.entrega_midia` (o que a cliente recebe DEPOIS de
-- pagar), estes entram antes da compra, em momentos específicos do funil.

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
  'Audios enviados durante a conversa. O prompt recebe chave + descricao + '
  'quando_usar; o agente devolve a chave no campo `audio` do JSON e o workflow '
  'envia antes do texto. URL publica (Supabase Storage).';

-- ---------------------------------------------------------------------------
-- Os 15 áudios enviados em 27/07. As URLs assumem o bucket público `entrega`
-- com os arquivos em `audios-conversao/`, mantendo os nomes do repositório.
--
-- As URLs já apontam para o projeto rmvmqmcfcjmcjtonewgi. Rode direto.
--
-- `quando_usar` foi derivado do título de cada arquivo — revise. É este texto
-- que o agente lê para decidir, e é o que evita o áudio sair na hora errada.
-- ---------------------------------------------------------------------------

insert into audios_agente (chave, url, descricao, quando_usar, ordem) values

  ('saudacao',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-01-saudacao.mp3',
   'Padre Frei cumprimenta e acolhe quem acabou de chegar',
   'Logo na abertura, na primeira resposta a quem chegou pelo anuncio. Nao usar se a lead ja abriu falando de dor ou de preco.',
   1),

  ('aquecimento',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-02-aquecimento.mp3',
   'Padre Frei conta do que se trata o trabalho e cria conexao',
   'Depois da saudacao, quando a lead respondeu mas ainda nao demonstrou intencao clara. Momento de aproximar antes de qualquer oferta.',
   2),

  ('transicao_oracao',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-08-transicao-oracao.mp3',
   'Padre Frei apresenta a Oracao Sagrada de Sao Bento',
   'Na transicao da conversa para o produto, quando a lead demonstrou interesse e voce vai apresentar a Oracao pela primeira vez.',
   3),

  ('recebe_agora',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-13-recebe-agora.mp3',
   'Padre Frei explica o que a pessoa recebe ao adquirir',
   'Quando a lead pergunta o que vem incluido, o que exatamente vai receber, ou como funciona (objecao K).',
   4),

  ('explicacao_audio_opcional',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-10-explicacao-audio-opcional.mp3',
   'Padre Frei explica a Oracao em Audio como complemento',
   'Ao apresentar o order bump da Oracao em Audio, ou quando a lead pergunta o que e esse item (objecao G).',
   5),

  ('antes_do_valor',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-05-antes-do-valor.mp3',
   'Padre Frei prepara o terreno antes de a lead ver o preco',
   'Imediatamente antes de apresentar o valor pela primeira vez. Nao usar se a lead ja sabe o preco.',
   6),

  ('contribuicao',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-15-contribuicao.mp3',
   'Padre Frei explica por que o trabalho tem um valor',
   'Quando a lead questiona por que algo religioso e cobrado, ou demonstra desconforto com pagar por isso (objecao H).',
   7),

  ('acolhimento_preco',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-11-acolhimento-preco.mp3',
   'Padre Frei acolhe quem diz que esta apertado de dinheiro',
   'Quando a lead diz que esta caro, sem condicoes ou apertada. Acolhe sem pressionar -- nao emendar oferta na mesma mensagem.',
   8),

  ('duvida',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-07-duvida.mp3',
   'Padre Frei responde a desconfianca sobre o trabalho ser serio',
   'Quando a lead demonstra receio de golpe, pergunta quem esta por tras, ou duvida que funcione (objecoes C e J).',
   9),

  ('antes_de_decidir',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-14-antes-de-decidir.mp3',
   'Padre Frei fala com quem esta em cima do muro',
   'Quando a lead diz "vou pensar", hesita ou trava sem dar um nao claro. Uma vez so -- se ela repetir, respeite.',
   10),

  ('acolhimento_dor',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-04-acolhimento-dor.mp3',
   'Padre Frei acolhe quem esta passando por sofrimento',
   'Quando a lead compartilha dor real sem risco a vida (P2): luto, doenca na familia, solidao, divida pesada. NUNCA em P1.',
   11),

  ('ajuda_primeira_compra',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-12-ajuda-primeira-compra.mp3',
   'Padre Frei tranquiliza quem nunca comprou pela internet',
   'Quando a lead demonstra inseguranca com comprar online, diz que nao entende de internet ou tem medo de errar.',
   12),

  ('orientacao_cadastro',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-09-orientacao-cadastro.mp3',
   'Padre Frei orienta no preenchimento dos dados',
   'Ao pedir e-mail e CPF, ou quando a lead estranha o pedido de dado pessoal, trava ou erra no preenchimento.',
   13),

  ('como_pagar_pix',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-06-como-pagar-pix.mp3',
   'Padre Frei ensina o passo a passo do pagamento por Pix',
   'Depois de enviar o link, quando a lead nao sabe pagar por Pix, pergunta como faz ou diz que nao conseguiu.',
   14),

  ('pos_pagamento',
   'https://rmvmqmcfcjmcjtonewgi.supabase.co/storage/v1/object/public/entrega/audios-conversao/audio-03-pos-pagamento.mp3',
   'Padre Frei agradece e recebe a pessoa depois da compra',
   'Depois da confirmacao do pagamento, junto da entrega. Fecha o ciclo com a voz dele.',
   15)

on conflict (chave) do update set
  url = excluded.url,
  descricao = excluded.descricao,
  quando_usar = excluded.quando_usar,
  ordem = excluded.ordem;

-- Conferência
select chave, descricao, quando_usar from audios_agente where ativo order by ordem;
