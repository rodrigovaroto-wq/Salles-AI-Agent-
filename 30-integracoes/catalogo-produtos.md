# Catálogo de Produtos

Fonte única de verdade sobre o que o agente pode oferecer, por quanto, e em que
situação. O agente só oferta o que está registrado aqui. As restrições de
conduta estão em [`../00-nucleo/compliance-e-etica.md`](../00-nucleo/compliance-e-etica.md).

status: 🟢 produtos e preços principais definidos. Pivô/downsell (seção 3) e
mapa de arquétipo (seção 4) ainda pendentes.

**Fonte de verdade em runtime:** a tabela `produtos` no Supabase (ver
`supabase/schema.sql`) — o agente e o node que monta o carrinho leem de lá,
não de um valor fixo no código do workflow. Esta tabela abaixo é a referência
legível/git-tracked; ao mudar um preço, atualize os dois lugares (ou rode de
novo o `insert ... on conflict` do `schema.sql`).

---

## 1. Tabela de produtos

| `produto_id` | nome | tipo | preço (R$) | `item_blackcat` (title/unitPrice em centavos) |
|---|---|---|---|---|
| `oracao_sagrada` | Oração Sagrada | `principal` | 22,90 | title: "Oração Sagrada", unitPrice: 2290 |
| `oracao_audio` | Oração em Áudio | `order_bump` | 9,90 | title: "Oração em Áudio", unitPrice: 990 |
| `comunidade` | Comunidade | `order_bump` | 34,90 | title: "Comunidade", unitPrice: 3490 |
| `contato_padre` | Contato Direto com o Padre | `order_bump` | 14,90 | title: "Contato Direto com o Padre", unitPrice: 1490 |
| `[A DEFINIR]` | Alternativo / downsell | `alternativo` | `[A DEFINIR]` | `[A DEFINIR]` |

Tipos possíveis: `principal` (o produto-alvo da conversa) · `order_bump`
(complemento oferecido em stack após aceite do principal) · `alternativo`
(oferecido no pivô por objeção/recusa, ver seção 3 — ainda sem produto
definido).

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
- É sempre **real** — o node "Montar items do carrinho" do
  `agente-vendas.json` aplica o percentual diretamente no `unitPrice` de cada
  item antes de mandar pro BlackCat (nunca só mencionado em texto sem
  refletir no valor cobrado — exigência do `compliance-e-etica.md`).
- Com os 3 order bumps disponíveis hoje, o teto natural é 30% (principal + 3).
  Falta definir com os sócios se um teto menor faz sentido se o catálogo
  crescer. `[A DEFINIR]`

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
- [`../00-nucleo/compliance-e-etica.md`](../00-nucleo/compliance-e-etica.md) — restrições de conduta
- [`../00-nucleo/objetivo.md`](../00-nucleo/objetivo.md) — processo de objeção
- [`../10-skills/ofertas/`](../10-skills/ofertas/) — ângulos de oferta
- [`blackcat/criacao-transacao.md`](blackcat/criacao-transacao.md) — como o catálogo vira `items[]`
- [`../20-memoria/schema-conversa.md`](../20-memoria/schema-conversa.md) — registro do que foi ofertado/aceito/recusado
