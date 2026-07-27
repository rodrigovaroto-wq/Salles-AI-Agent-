# Mídia de entrega e de conversão

Duas famílias de arquivo, com caminhos diferentes no fluxo:

| Pasta | Quando é enviado | Onde é configurado |
|---|---|---|
| `audios-produto/` | **depois** do pagamento, como parte do produto | `produtos.entrega_midia` |
| `audios-conversao/` | **durante** a conversa, para converter | tabela `audios_agente` |
| `oracao-sagrada-de-sao-bento.pdf` | depois do pagamento | `produtos.entrega_midia` |

## Hospedagem

Os arquivos versionados aqui são a **fonte**; o WhatsApp precisa de uma URL
pública. Suba para o Supabase Storage, bucket público `entrega`, mantendo os
mesmos nomes:

```
entrega/oracao-sagrada-de-sao-bento.pdf
entrega/audios-produto/<arquivo>
entrega/audios-conversao/<arquivo>
```

A URL fica `https://<projeto>.supabase.co/storage/v1/object/public/entrega/...`

## Formato dos áudios

A Cloud API do WhatsApp aceita `audio/ogg` (codec **opus**), `audio/mpeg`,
`audio/mp4`, `audio/amr`. Limite de 16 MB.

`.ogg/opus` é o formato nativo do WhatsApp — chega como mensagem de voz, com a
forma de onda, e não como arquivo anexado. É o que soa como o padre falando de
verdade. Converter:

```bash
ffmpeg -i entrada.mp3 -c:a libopus -b:a 32k saida.ogg
```

**Áudio não aceita legenda** na Cloud API. Qualquer texto que acompanhe vai em
mensagem separada.

## Áudios de conversão — como o agente decide

O prompt recebe a lista de `audios_agente` (chave, descrição, quando usar). O
agente devolve `"audio": "<chave>"` no JSON quando julgar o momento certo, e o
workflow envia antes das mensagens de texto.

Regras que valem para todos:
- **No máximo um áudio por conversa**, salvo indicação explícita no `quando_usar`
- Nunca emendar oferta no mesmo turno de um áudio de acolhimento
- Nunca em P1 (risco à vida) — nesse caminho o agente não envia mídia nenhuma

## Status dos arquivos

| Arquivo | Estado |
|---|---|
| `oracao-sagrada-de-sao-bento.pdf` | ✅ no repo (4 páginas, 8,4 MB) |
| `audios-conversao/` | ✅ **15 áudios** — cadastrados em `migracao-audios-conversao.sql` |
| `audios-produto/` | ⏳ vazio — aguardando os áudios que são o produto |

### Os 15 áudios de conversão

Mapeados por momento do funil, na ordem em que tendem a aparecer:

| # | Chave | Momento |
|---|---|---|
| 01 | `saudacao` | abertura |
| 02 | `aquecimento` | criar conexão antes de ofertar |
| 08 | `transicao_oracao` | apresentar a Oração |
| 13 | `recebe_agora` | "o que eu recebo?" (objeção K) |
| 10 | `explicacao_audio_opcional` | order bump do Áudio (objeção G) |
| 05 | `antes_do_valor` | logo antes de dizer o preço |
| 15 | `contribuicao` | "por que cobra por algo religioso?" (H) |
| 11 | `acolhimento_preco` | "tá caro / tô apertada" |
| 07 | `duvida` | receio de golpe (C e J) |
| 14 | `antes_de_decidir` | "vou pensar" |
| 04 | `acolhimento_dor` | dor real **sem** risco à vida (P2) |
| 12 | `ajuda_primeira_compra` | nunca comprou pela internet |
| 09 | `orientacao_cadastro` | ao pedir e-mail/CPF |
| 06 | `como_pagar_pix` | não sabe pagar por Pix |
| 03 | `pos_pagamento` | junto da entrega |

### ⚠️ Formato — vale converter

Os arquivos vieram em **`.mp3`**. A Cloud API aceita (`audio/mpeg`), mas chega
como **arquivo anexado**, com ícone de documento. Em `.ogg/opus` chega como
**mensagem de voz**, com a forma de onda e o play — que é o que soa como o
padre falando, e não como um anexo de propaganda. Nesse público a diferença é
grande.

```bash
for f in audios-conversao/*.mp3; do
  ffmpeg -i "$f" -c:a libopus -b:a 32k "${f%.mp3}.ogg"
done
```

Se converter, atualize as URLs em `migracao-audios-conversao.sql` de `.mp3`
para `.ogg`. Não tenho ffmpeg neste ambiente, então não converti.
