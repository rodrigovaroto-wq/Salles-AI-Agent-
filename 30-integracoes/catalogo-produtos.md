# Catálogo de Produtos

Fonte única de verdade sobre o que o agente pode oferecer, por quanto, e em que
situação. O agente **nunca inventa produto, preço ou benefício** — ele só pode
oferecer o que está registrado aqui (ver `../00-nucleo/objetivo.md`, CONTEXT8).

status: 🟡 aguardando definição de produtos e preços com os sócios.
Preencher as tabelas abaixo substitui os placeholders `[A DEFINIR]`.

---

## 1. Tabela de produtos

| `produto_id` | nome | tipo | preço (R$) | `item_blackcat` (title/unitPrice em centavos) |
|---|---|---|---|---|
| `[A DEFINIR]` | Produto principal | `principal` | `[A DEFINIR]` | `[A DEFINIR]` |
| `[A DEFINIR]` | Order bump 1 | `order_bump` | `[A DEFINIR]` | `[A DEFINIR]` |
| `[A DEFINIR]` | Order bump 2 | `order_bump` | `[A DEFINIR]` | `[A DEFINIR]` |
| `[A DEFINIR]` | Alternativo / downsell | `alternativo` | `[A DEFINIR]` | `[A DEFINIR]` |

Tipos possíveis: `principal` (o produto-alvo da conversa) · `order_bump`
(complemento oferecido em stack após aceite do principal) · `alternativo`
(oferecido no pivô por objeção/recusa, ver seção 3).

## 2. Regra de desconto no stack (bundle)

Definida: **10% de desconto sobre o valor total da compra a cada item
adicional** aceito além do principal.

| Itens no carrinho | Desconto sobre o total |
|---|---|
| Só o principal | 0% |
| Principal + 1 adicional | 10% |
| Principal + 2 adicionais | 20% |
| Principal + 3 adicionais | 30% |

Regra de aplicação:
- O desconto incide sobre o **valor total do pedido**, não item a item.
- É sempre **real** — calculado e aplicado no momento de montar o `items[]`
  do BlackCat (ver `blackcat/criacao-transacao.md`), nunca apenas mencionado
  em texto sem refletir no valor cobrado.
- Definir com os sócios: existe um teto de desconto (ex.: máx. 30-40%) para
  não corroer a margem em pedidos muito grandes? `[A DEFINIR]`

## 3. Mapa de objeção/recusa → alternativa (pivô)

Usado quando o lead recusa o principal ou insiste numa objeção forte. Em vez
de insistir no mesmo produto, o agente consulta esta tabela e oferece a
alternativa cadastrada.

| Objeção / sinal | `produto_id` alternativo a ofertar | Observação |
|---|---|---|
| "Está caro" | `[A DEFINIR]` (versão mais barata) | Downsell real, não o mesmo produto com desconto inventado |
| "Não tenho interesse no principal" | `[A DEFINIR]` | Produto lateral que resolve outra dor do mesmo avatar |
| "Vou pensar" (2ª recusa) | `[A DEFINIR]` | Opcional: oferta de menor compromisso |

Regra: o pivô só acontece **depois** de ao menos uma tentativa honesta de
tratar a objeção (ver `../00-nucleo/objetivo.md`, PROCESSO 4). Ele não substitui
o tratamento de objeção — entra quando o tratamento não resolveu.

## 4. Mapa de perfil (arquétipo) → produto em destaque

Cruza com `../10-skills/copy/copy-persuasao-avancada.md` (arquétipos de Jung).

| Arquétipo | Produto priorizado no stack |
|---|---|
| Mãe Protetora | `[A DEFINIR]` |
| Guerreira de Fé | `[A DEFINIR]` |
| Devota em Busca | `[A DEFINIR]` |
| Mulher que Pertence | `[A DEFINIR]` |

## 5. Como o agente consulta este catálogo

1. Lead aceita o principal → agente apresenta o **stack completo de uma vez**
   (não item a item), citando o desconto real por item adicionado.
2. Lead monta o carrinho → agente calcula o total com desconto (seção 2) e
   monta o `items[]` do BlackCat.
3. Lead recusa o principal ou repete objeção forte → agente consulta a
   seção 3 e oferece a alternativa, sem insistir mais de uma vez na mesma
   linha de recusa.

## Relacionado
- [`../00-nucleo/objetivo.md`](../00-nucleo/objetivo.md) — regras éticas, processo de objeção
- [`../10-skills/ofertas/`](../10-skills/ofertas/) — ângulos de oferta
- [`blackcat/criacao-transacao.md`](blackcat/criacao-transacao.md) — como o catálogo vira `items[]`
- [`../20-memoria/schema-conversa.md`](../20-memoria/schema-conversa.md) — registro do que foi ofertado/aceito/recusado
