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

## Fluxo da assinatura — dois momentos, de propósito

A entrada e a mensalidade **não** acontecem no mesmo checkout. Isso foi decisão,
não limitação:

```
lead aceita a Comunidade / Contato com o Padre
        │
        ▼
BravoPay: cobrança da ENTRADA por Pix (R$ 44,90 ou R$ 19,90)
        │  a cliente paga no app do banco, sem cartão
        ▼
webhook transaction.paid → entrega (PDF, áudios, link do grupo)
        │
        ▼
Pagar.me: POST /paymentlinks devolve a url do checkout
        │  o agente manda: "seus 30 dias são um presente; cadastre seu cartão aqui"
        ▼
cliente digita o cartão NA PÁGINA DO PAGAR.ME
        │
        ▼
webhook subscription.created → assinaturas: status='trial', até o dia 30
        │
        ▼
dia 31: Pagar.me cobra o cartão sozinho, todo mês
        charge.paid           → proxima_cobranca += 30d, status='ativa'
        charge.payment_failed → status='inadimplente'
        subscription.canceled → status='cancelada'
```

**Por que não tudo no Pagar.me, num checkout só?** Porque assinatura exige
cartão, e o público é 45–60+ — boa parte paga por Pix e pode nem ter cartão de
crédito. Jogar a entrada para dentro do checkout de assinatura trocaria Pix por
cartão na hora da compra, que é justamente onde está o dinheiro mais garantido.

**O custo dessa escolha:** existe uma janela em que a cliente pagou a entrada,
recebeu tudo, e ainda não cadastrou o cartão. Ela tem 30 dias de acesso de
qualquer forma (é o trial), então ninguém é prejudicado — mas quem não cadastrar
some no dia 31 sem nunca ter pago mensalidade. Vale acompanhar essa conversão
nos primeiros meses:

```sql
select produto_id, count(*) filter (where status = 'trial') as sem_cartao,
       count(*) filter (where status = 'ativa') as pagando
from assinaturas group by produto_id;
```

Se muita gente ficar em `trial` sem virar `ativa`, o convite precisa de reforço
(um lembrete no dia 25, por exemplo) — hoje ele é enviado uma vez só.

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

## Autenticação do webhook — resolvida por confirmação na fonte

A documentação pública do Pagar.me **não especifica** o mecanismo de
autenticação do webhook (não há HMAC documentado, como o BravoPay tem). Em vez
de adivinhar um esquema de assinatura, o workflow **não confia no payload**:
o node `Confirmar no Pagar.me` faz um `GET /subscriptions/{id}` antes de gravar
qualquer coisa.

Um webhook forjado aponta para uma assinatura que não existe (ou não é da nossa
conta) e a chamada falha — o evento é descartado. Custa uma requisição por
evento, e remove a dúvida por completo.

Quando a conta existir, vale confirmar no painel se há Basic Auth ou assinatura
disponível; se houver, dá para somar às duas verificações.

## O que falta

- [x] Workflow `pagamento-pagarme.json` construído (17 nodes)
- [x] Criação do link de assinatura embutida no fluxo de entrega
- [ ] Criar a conta e pegar a `secret_key`
- [ ] Credential `Pagar.me API` no n8n — Header Auth,
      `Authorization` = `Basic <base64 de "sk_xxx:">`
- [ ] **Trocar `<<PAGARME_CREDENTIAL_ID>>`** nos dois workflows pelo id real da
      credential (aparece na URL ao abrir a credential no n8n)
- [ ] Webhook no painel → `https://salles-ai-agent.pikapod.net/webhook/pagarme`,
      eventos: `charge.paid`, `charge.payment_failed`, `subscription.created`,
      `subscription.canceled`

## BravoPay — documentado, divisão fechada

A doc está em https://bravopay.club/docs e foi mapeada em
[`../bravopay/README.md`](../bravopay/README.md). Divisão final:

- **BravoPay** → entradas (principal + order bumps)
- **Pagar.me** → as duas assinaturas

O motivo é econômico: a taxa fixa do BravoPay (R$ 3,60 no cartão) consome 66%
de uma mensalidade de R$ 5,47. Números completos na seção de taxas do doc deles.
