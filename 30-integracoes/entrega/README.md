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
| `audios-conversao/` | ⏳ **vazio** — aguardando envio |
| `audios-produto/` | ⏳ **vazio** — aguardando envio |

Ao receber os áudios: converter para `.ogg/opus`, colocar na pasta certa, subir
ao Storage e cadastrar (`audios_agente` para conversão, `produtos.entrega_midia`
para produto).
