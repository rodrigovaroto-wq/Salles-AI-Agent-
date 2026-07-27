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
| `audios-conversao/` | ✅ **15 áudios** em `.ogg`/opus, normalizados e cadastrados no SQL |
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

### Formato — já convertidos ✅

Os originais vieram em `.mp3` (4,7 MB no total). Foram convertidos para
**`.ogg`/opus**, que é o formato nativo do WhatsApp: chega como **mensagem de
voz**, com forma de onda e botão de play, em vez de arquivo anexado com ícone
de documento. Neste público a diferença entre "o padre me mandou um áudio" e
"um anexo de propaganda" é grande.

O que foi aplicado:

| Ajuste | Valor | Por quê |
|---|---|---|
| Codec | libopus, 32 kbps VBR | nativo do WhatsApp; voz limpa nesse bitrate |
| Perfil | `-application voip` | otimiza o encoder para fala, não para música |
| Canais / taxa | mono, 48 kHz | opus trabalha internamente a 48 kHz |
| Loudness | `loudnorm I=-16 TP=-1.5` | os originais estavam a −25 dB médios, com 7–8 dB de folga |
| Metadados | removidos | corta peso inútil |

A normalização é a parte que mais importa na prática: rendeu **+8 dB** e deixou
os 15 no mesmo nível. Áudio baixo, num celular no viva-voz, numa cozinha com
barulho, simplesmente não é ouvido — e o público é 45–60+.

Resultado: **4,7 MB → 1,2 MB** (−77%), sem perda de duração.

Os `.mp3` originais foram removidos da árvore para não haver ambiguidade sobre
qual subir. Continuam no histórico do git:

```bash
git show 50132c6:30-integracoes/entrega/audios-conversao/audio-01-saudacao.mp3 > original.mp3
```

Para reconverter (o ffmpeg deste ambiente veio do pacote `imageio-ffmpeg`):

```bash
for f in *.mp3; do
  ffmpeg -y -i "$f" -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
    -c:a libopus -b:a 32k -vbr on -application voip \
    -ac 1 -ar 48000 -map_metadata -1 "${f%.mp3}.ogg"
done
```

