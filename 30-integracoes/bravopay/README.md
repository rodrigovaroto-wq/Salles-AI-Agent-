# BravoPay — Pix e cobranças avulsas

Gateway que substitui o BlackCat nas cobranças pontuais. **Divisão definida em
27/07:**

- **BravoPay** → produto principal e order bumps (as cobranças de entrada)
- **Pagar.me** → todas as assinaturas

São **duas** assinaturas hoje, ambas com 30 dias grátis:
| Produto | Entrada (BravoPay) | Mensalidade (Pagar.me) |
|---|---|---|
| Comunidade | R$ 44,90 | R$ 9,78/mês |
| Contato Direto com o Padre | R$ 19,90 | R$ 5,47/mês |

O porquê da divisão está na seção de taxas, mais abaixo.

- Painel: https://bravopay.club/dashboard
- Docs: https://bravopay.club/docs
- Base da API: `https://bravopay.club/api/v1`
- Auth: `Authorization: Bearer bp_live_...` (chave gerada em Dashboard → API Keys)

## Por que serve bem para o nosso caso

| Recurso | Situação |
|---|---|
| Pix com QR/copia-e-cola imediato | ✅ `POST /transactions` com `method: "pix"` |
| Cartão sem tocar em dado de cartão | ✅ devolve `card.hosted_url` (checkout Stripe, PCI do lado deles) |
| `external_reference` para religar à conversa | ✅ máx. 120 chars — é onde vai o `wa_id` |
| `metadata` devolvido no webhook | ✅ até 20 chaves |
| UTMs nativos (Meta, TikTok, Kwai, Google) | ✅ `utm.*`, incl. `fbclid`/`ttclid` |
| Webhook assinado | ✅ HMAC-SHA256, retry exponencial, dead-letter queue |

O `hosted_url` do cartão resolve o mesmo problema que o Pagar.me resolve na
assinatura: **o cartão nunca passa pelo WhatsApp, pelo n8n nem pelo Supabase.**

## Criar cobrança

```
POST /api/v1/transactions
Authorization: Bearer bp_live_...
```

```json
{
  "amount_cents": 7112,
  "method": "pix",
  "customer": {
    "name":  "Maria da Silva",
    "email": "maria@exemplo.com",
    "cpf":   "11144477735",
    "phone": "5511988887777"
  },
  "description": "Oração Sagrada + Áudio + Comunidade + Contato",
  "external_reference": "5511988887777",
  "metadata": { "wa_id": "5511988887777", "arquetipo": "mae_protetora", "origem": "lp" },
  "utm": { "source": "meta", "campaign": "...", "content": "...", "fbclid": "..." }
}
```

Resposta (Pix):
```json
{ "id": "tx_...", "status": "PENDING", "amount_cents": 7112,
  "fee_cents": 697, "net_cents": 6415,
  "pix": { "copy_paste": "00020126...", "expires_at": "..." } }
```

Com `"method": "card"`, no lugar de `pix` vem
`card.hosted_url` — é essa URL que o agente manda no WhatsApp.

**Mínimo de R$ 5,00** (`amount_cents >= 500`). Todos os nossos itens passam
disso, mas o downsell não pode furar esse piso.

## Webhooks

Envelope:
```json
{ "id": "evt_...", "type": "transaction.paid", "created": 1730476320,
  "data": { "id": "tx_...", "external_reference": "5511988887777",
            "metadata": {...}, "tracking": {...}, "customer": {...},
            "status": "PAID", "paid_at": "..." } }
```

Eventos: `transaction.created` · `transaction.paid` · `transaction.refunded` ·
`transaction.chargeback` · `transaction.expired` · `transaction.failed` ·
`withdrawal.paid` · `withdrawal.failed`

### Validação de assinatura — obrigatória

Cabeçalhos `BravoPay-Signature` / `X-Bravopay-Signature`, no formato
`t=<timestamp>,v1=<hex>`, com HMAC-SHA256 sobre `${timestamp}.${rawBody}`.

Sem validar, qualquer um que descubra a URL do webhook pode forjar um
`transaction.paid` e receber a entrega sem pagar. O BlackCat não tinha
assinatura e o workflow atual não valida nada — **com o BravoPay isso passa a
ser obrigatório no primeiro node do fluxo.**

## Diferenças em relação ao BlackCat (o que muda no workflow)

| | BlackCat | BravoPay |
|---|---|---|
| Valor | `items[]` com `unitPrice` | `amount_cents` (um total só) |
| Nosso ID | `externalRef` | `external_reference` |
| No webhook | `body.externalReference` | `data.external_reference` |
| Evento | `event: "transaction.paid"` | `type: "transaction.paid"` |
| Itens comprados | `body.items[]` | **não vem** — usar `metadata` |
| Assinatura | não tem | HMAC-SHA256 obrigatória |

⚠️ **A mudança que mais afeta a entrega:** o BravoPay cobra um valor único, sem
lista de itens. O node "Montar entrega" hoje lê `body.items[]` para saber o que
entregar. Com o BravoPay, os `produto_id` comprados precisam ir no `metadata`
na criação da cobrança e voltar de lá.

## Taxas — e por que a assinatura NÃO fica aqui ⚠️

Pix: **6,99% + R$ 2,00** · Cartão: **9,90% + R$ 3,60**

A parte fixa é o problema. Em valores baixos ela domina:

| Cobrança | Bruto | Taxa | Líquido | % |
|---|---|---|---|---|
| Oração Sagrada (Pix) | 22,90 | 3,60 | 19,30 | 15,7% |
| Oração Sagrada (cartão) | 22,90 | 5,87 | 17,03 | 25,6% |
| Stack completo (Pix) | 71,12 | 6,97 | 64,15 | 9,8% |
| **Mensalidade 9,78 (cartão)** | 9,78 | 4,57 | 5,21 | **46,7%** |
| **Mensalidade 5,47 (cartão)** | 5,47 | 4,14 | 1,33 | **75,7%** |

A de R$ 9,78 entregaria R$ 5,21 líquidos. A de **R$ 5,47 entregaria R$ 1,33** —
**76% some em taxa**, porque a parte fixa de R$ 3,60 sozinha já é 66% do valor
cobrado. No Pagar.me, com recorrência (~3,79% e sem fixa por transação), as
mesmas mensalidades rendem R$ 9,41 e R$ 5,26.

| Mensalidade | BravoPay | Pagar.me | Diferença/mês |
|---|---|---|---|
| R$ 9,78 (Comunidade) | 5,21 | 9,41 | **+4,20** |
| R$ 5,47 (Contato) | 1,33 | 5,26 | **+3,93** |

Uma cliente com as duas assinaturas rende **R$ 8,13 a mais por mês** no
Pagar.me. Em 1.000 clientes, R$ 8.130/mês.

Por isso a divisão: **BravoPay** fica com as entradas (R$ 13,90 a R$ 71,12,
onde a taxa fixa dilui), **Pagar.me** com as assinaturas (ver
[`../pagarme/README.md`](../pagarme/README.md)).

Vale confirmar as taxas no seu painel: elas variam por conta e volume, e a doc
pública pode não refletir o que foi negociado com você.

## Assinatura no BravoPay — documentação incompleta

A doc menciona produtos com `type: "SUBSCRIPTION"` e `interval_days` (padrão
30), e que o split se aplica "a toda renovação". Mas **não documenta** o
endpoint de recorrência, a tokenização do cartão, nem campo de trial.

Como a economia já aponta para o Pagar.me na mensalidade, não vale perseguir
isso. Se você quiser manter tudo num gateway só, pergunte ao suporte deles:
existe endpoint de assinatura com trial de 30 dias e qual a taxa de renovação?

## O que falta

- [x] API key gerada e credential `BravoPay API` criada no n8n
- [x] Webhook cadastrado em `/webhook/bravopay`
- [x] Taxas confirmadas (ver acima)
- [x] Workflow `pagamento-bravopay.json` construído
- [ ] **Cadastrar o webhook secret** em `configuracoes.bravopay_webhook_secret`
      (rode `migracao-config.sql`, depois o `update` com o valor real)
- [ ] Recolar os workflows no n8n

> ⚠️ O segredo do webhook **não** fica em Credential do n8n nem em `$env`: o
> PikaPods não expõe variáveis de ambiente e um node Code não consegue ler
> Credential. Ele mora em `configuracoes`, que é o único lugar que o node de
> validação alcança. A credential `BravoPay Webhook Secret` que você criou não
> é usada por nada — pode apagar.

## Como o workflow ficou

```
BravoPay IN (rawBody)
   → Buscar segredo do webhook      (configuracoes)
   → Validar assinatura             (HMAC-SHA256 + janela de 5 min + timingSafeEqual)
   → Assinatura válida?  ──não──→   descarta em silêncio
        │sim
   → Normalizar payload             (traduz o formato BravoPay para o do fluxo)
   → Marcar webhook processado      (idempotência: chave `bp:<tx>:<tipo>`)
   → Webhook inédito?    ──não──→   reenvio ignorado
        │sim
   → paid / created / failed
```

Teste: `node 30-integracoes/n8n/ensaio/ensaio-hmac.js` — 12 casos, incluindo
assinatura forjada, corpo adulterado depois de assinado e replay antigo.

### O elo que não pode quebrar: `metadata.produtos`

Como não há `items[]`, o node "Montar items do carrinho" grava os `produto_id`
em `metadata.produtos` (string separada por vírgula — `metadata` só aceita
valores simples), e o webhook lê de volta de lá. **Se isso não for gravado, o
pagamento entra mas a entrega não sabe o que mandar.**
