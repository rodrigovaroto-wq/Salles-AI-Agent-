# Criação de Transação — do Catálogo ao Link BlackCat

Como o orquestrador (n8n) monta o link de pagamento a partir da decisão do
agente, usando `POST https://api.blackcathub.com/api/sales/create-sale`.

## Passo a passo

1. **Agente decide o carrinho** (durante a conversa): produto principal +
   order bumps aceitos, ou o produto alternativo do pivô (ver
   `../catalogo-produtos.md`, seções 2 e 3).
2. **Orquestrador busca os dados de cada `produto_id`** no catálogo (nome,
   preço, `item_blackcat`).
3. **Calcula o desconto**: 10% sobre o valor total do pedido a cada item
   adicionado além do principal (ver catálogo, seção 2).
4. **Monta o payload** `create-sale`:

```json
{
  "items": [
    { "title": "<nome produto principal>", "quantity": 1, "unitPrice": "<preço em centavos>" },
    { "title": "<nome order bump 1>", "quantity": 1, "unitPrice": "<preço em centavos>" }
  ],
  "externalRef": "<wa_id do lead>",
  "postbackUrl": "<endpoint do orquestrador>",
  "metadata": { "arquetipo": "<arquetipo do lead>", "etapa_funil": "<etapa>" },
  "utm_source": "<origem: tiktok | meta>",
  "utm_campaign": "<campanha de origem, se disponível>",
  "utm_content": "<criativo de origem, se disponível>"
}
```

5. **Aplicação do desconto**: recalcular os `unitPrice` (ou aplicar um item de
   desconto negativo, a definir conforme a API aceite) para que o **total
   cobrado já reflita o desconto real** — nunca prometer desconto em texto sem
   ele aparecer no valor da transação.
6. **BlackCat retorna o link de pagamento** → agente envia ao lead pelo
   WhatsApp.
7. Grava em `../../20-memoria/schema-conversa.md`: produtos ofertados,
   aceitos, valor final e link gerado.

## Por que o `externalRef = wa_id`
É o único jeito do webhook de resposta (`../eventos-webhook.md`) saber a qual
conversa aquele pagamento pertence. Sem isso, o orquestrador recebe a
confirmação de pagamento mas não sabe para qual lead responder.

## Pendências antes de codar o node no n8n
- [ ] Preços reais do catálogo (`../catalogo-produtos.md`) — aguardando
      definição com os sócios.
- [ ] Confirmar no painel BlackCat se desconto é aplicado via recálculo de
      `unitPrice` ou via campo/cupom dedicado.
- [ ] Definir teto de desconto, se houver.
