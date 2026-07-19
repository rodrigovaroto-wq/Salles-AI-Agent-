# Eventos de Webhook — BlackCat

Confirmados na documentação oficial (docs.blackcatoficial.com). O BlackCat
envia POST para o `postbackUrl` configurado a cada mudança de status; responder
HTTP 200 em até 10s.

## Os 3 eventos e o que cada um dispara

| Evento BlackCat | Significado | Ação no orquestrador (n8n) |
|---|---|---|
| `transaction.created` | Pix/boleto **gerado**, ainda não pago | 1. Casa `externalRef` (= `wa_id`) com o lead na memória.<br>2. Marca `status = checkout_abandonado` (provisório).<br>3. **Arma timer de 2h.** |
| `transaction.paid` | Pagamento **confirmado** | 1. Casa `externalRef` com o lead.<br>2. Marca `status = cliente`, grava produto(s)/valor em `produtos_comprados`.<br>3. Envia confirmação + entrega pelo WhatsApp (texto livre — dentro das 24h porque o lead iniciou a conversa).<br>4. Cancela o timer de 2h, se ainda ativo. |
| `transaction.failed` | Transação expirou ou falhou | 1. Marca `status = checkout_falhou`.<br>2. Cancela o timer de 2h.<br>3. Entra na fila de follow-up (`> 24h → template`, ver `../../00-nucleo/`). |

Existe também um evento coringa `all` para receber todas as notificações num
único endpoint, útil em ambiente de teste.

## O timer de recuperação de 2h (regra combinada)

- Dispara a partir de `transaction.created` sem `transaction.paid` correspondente.
- Ao completar 2h: se **ainda não pago** e a última mensagem do lead foi **há
  menos de 24h**, dispara **recuperação em texto livre** (o agente reabre
  tratando a objeção mais provável para aquele produto/carrinho).
- Se as 24h já se esgotaram, a reabertura vira responsabilidade do fluxo de
  **follow-up com template aprovado** (fora do escopo desta integração — ver
  `../../00-nucleo/`).

## Payload de referência (campos usados pelo orquestrador)

```json
{
  "event": "transaction.paid",
  "externalRef": "5511999999999",       // wa_id do lead
  "status": "paid",
  "items": [
    { "title": "Produto principal", "quantity": 1, "unitPrice": 0 },
    { "title": "Order bump 1", "quantity": 1, "unitPrice": 0 }
  ],
  "utm": {
    "utm_source": "tiktok",
    "utm_campaign": "[A DEFINIR]",
    "utm_content": "[A DEFINIR]"
  },
  "metadata": { "arquetipo": "mae_protetora" }
}
```

`unitPrice` fica zerado neste exemplo de referência — os valores reais vêm do
catálogo (`../catalogo-produtos.md`), ainda pendente de definição com os sócios.
