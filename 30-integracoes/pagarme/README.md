# Pagar.me — assinaturas (Comunidade e Contato com o Padre)

Gateway escolhido para **todas as assinaturas**, substituindo o BlackCat nesse
papel (o BlackCat não tem tokenização nem recorrência — ver
`../comunidade-assinatura.md`).

Base da API: `https://api.pagar.me/core/v5`
Autenticação: **Basic**, com a `secret_key` como usuário e senha vazia
(`Authorization: Basic base64(sk_xxx:)`).

## A decisão que define a arquitetura

O cartão **nunca passa pelo nosso lado**. Nem pelo WhatsApp, nem pelo n8n, nem
pelo Supabase, nem pelo contexto da OpenAI.

O Pagar.me oferece dois caminhos para isso:

| Caminho | Como funciona | Quando usar |
|---|---|---|
| **Link de Pagamento** (checkout hospedado) | `POST /paymentlinks` devolve uma `url`; o agente manda a URL no WhatsApp, a cliente preenche o cartão na página do Pagar.me | **Escolhido.** Zero código de frontend, zero PCI do nosso lado |
| Tokenização no browser | `POST /tokens?appId=pk_xxx` chamado do navegador da cliente, devolve `card_token` de uso único; o backend cria a assinatura com ele | Só se um dia houver checkout próprio |

A `secret_key` fica **apenas** como Credential do n8n. A `public_key` (`pk_`) é
a única que pode aparecer em página; hoje não usamos nenhuma.

## Fluxo da assinatura

```
lead aceita a Comunidade na conversa
        │
        ▼
agente pede e-mail + CPF (já faz isso hoje)
        │
        ▼
n8n: POST /core/v5/paymentlinks   → devolve url do checkout
        │                            (entrada R$ 44,90 + assinatura R$ 9,78/mes,
        │                             trial de 30 dias)
        ▼
agente manda a url no WhatsApp
        │
        ▼
cliente preenche o cartão na página do Pagar.me
        │
        ▼
webhook subscription.created  → assinaturas: status='trial', trial_ate=+30d
webhook order.paid            → entrega (PDF, áudios, link do grupo)
        │
        ▼
dia 31 em diante: Pagar.me cobra o cartão sozinho
        charge.paid   → proxima_cobranca += 30d, status='ativa'
        charge.failed → status='inadimplente' + alerta ao Rodrigo
```

A diferença prática para o BlackCat: **a partir do dia 31 ninguém precisa fazer
nada**. Sem link mensal, sem a cliente lembrar de pagar, sem churn por
esquecimento.

## Endpoints usados

| O quê | Método e rota |
|---|---|
| Criar link de pagamento | `POST /core/v5/paymentlinks` |
| Criar assinatura direta (sem plano) | `POST /core/v5/subscriptions` |
| Consultar assinatura | `GET /core/v5/subscriptions/{id}` |
| Cancelar assinatura | `DELETE /core/v5/subscriptions/{id}` |
| Criar pedido avulso (produtos sem recorrência) | `POST /core/v5/orders` |

`POST /subscriptions` exige `plan_id` **ou** os itens inline, mais
`payment_method`, e `customer` ou `customer_id`. Para cartão, exige
`card_id` ou `card_token` — por isso o caminho do link hospedado, que resolve
o cartão do lado do Pagar.me.

Campos que usamos em todas as chamadas:
- `code` — nosso identificador (o `wa_id` da lead), o elo de volta à conversa
- `metadata` — `{ wa_id, arquetipo, origem }`
- `closed: true` nos itens, para o valor não ser editável pela cliente

## Webhooks

Configurar no painel do Pagar.me apontando para
`https://salles-ai-agent.pikapod.net/webhook/pagarme`.

| Evento | O que dispara |
|---|---|
| `order.paid` | Entrega dos produtos comprados |
| `subscription.created` | Cria a linha em `assinaturas` como `trial` |
| `charge.paid` | Mensalidade paga → `proxima_cobranca += 30d`, `status='ativa'` |
| `charge.payment_failed` | → `status='inadimplente'` + alerta ao Rodrigo |
| `subscription.canceled` | → `status='cancelada'` |

O Pagar.me assina os webhooks; a validação da assinatura é obrigatória antes de
confiar no payload (ver `webhooks.md` quando for implementado).

## Valores (centavos, como o BlackCat)

| Produto | Entrada (BravoPay) | Mensalidade (Pagar.me) | Trial |
|---|---|---|---|
| Comunidade | `4490` | `978` | 30 dias |
| Contato Direto com o Padre | `1990` | `547` | 30 dias |

São duas assinaturas independentes: a cliente pode ter uma, outra ou as duas.
Com as duas, são R$ 15,25/mês a partir do dia 31. A tabela `assinaturas` já tem
`unique (lead_id, produto_id)`, então cada uma vira uma linha própria.

## O que falta

- [ ] `secret_key` de produção como Credential `Pagar.me API` no n8n
      (Header Auth, `Authorization: Basic base64(sk_xxx:)`)
- [ ] Webhook cadastrado no painel apontando para `/webhook/pagarme`
- [ ] Workflow `pagamento-pagarme.json` — **ainda não construído**. Agora
      desbloqueado: a doc do BravoPay chegou e a divisão está fechada

## BravoPay — documentado, divisão fechada

A doc está em https://bravopay.club/docs e foi mapeada em
[`../bravopay/README.md`](../bravopay/README.md). Divisão final:

- **BravoPay** → entradas (principal + order bumps)
- **Pagar.me** → as duas assinaturas

O motivo é econômico: a taxa fixa do BravoPay (R$ 3,60 no cartão) consome 66%
de uma mensalidade de R$ 5,47. Números completos na seção de taxas do doc deles.
