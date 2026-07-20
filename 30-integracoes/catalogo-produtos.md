# Catálogo de Produtos

Fonte única de verdade sobre o que o agente pode oferecer, por quanto, e em que
situação. O agente só oferta o que está registrado aqui. As restrições de
conduta estão em [`../00-nucleo/compliance-e-etica.md`](../00-nucleo/compliance-e-etica.md).

status: 🟢 catálogo fechado — produtos, preços, desconto real, pivô por
objeção e mapa de arquétipo definidos e conectados em runtime (não só
documentação).

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
| `oracao_audio` | Oração em Áudio | `order_bump` | 13,90 | title: "Oração em Áudio", unitPrice: 1390 |
| `comunidade` | Comunidade | `order_bump` | 44,90 | title: "Comunidade", unitPrice: 4490 |
| `contato_padre` | Contato Direto com o Padre | `order_bump` | 19,90 | title: "Contato Direto com o Padre", unitPrice: 1990 |

Tipos possíveis: `principal` (o produto-alvo da conversa) · `order_bump`
(complemento oferecido em stack após aceite do principal) · `alternativo`
(reservado para um futuro produto de entrada dedicado — **decisão tomada:
não criar um agora**; o pivô por objeção reaproveita `oracao_audio`, ver
seção 3).

**Nota de integridade de preço:** os valores acima são o preço real de venda
avulsa de cada order bump — não uma âncora inflada criada só para depois ser
"descontada" de volta a um valor menor. O desconto da seção 2 é aplicado em
cima desses preços reais, e o valor final cobrado reflete exatamente o
percentual anunciado. Isso não é apenas estilo — é o que mantém a operação
dentro do art. 37 do CDC (publicidade enganosa) e da seção 2 do
`compliance-e-etica.md`: nunca anunciar desconto sobre um preço "de" que não
seja o preço real do produto.

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
- **Teto de desconto — decidido:** nenhum teto artificial. Com os 3 order
  bumps de hoje, 30% (principal + todos) já é o limite natural — não há como
  passar disso com o catálogo atual. Revisitar esta decisão quando (e se) o
  catálogo crescer além de 3 order bumps, para não deixar o desconto máximo
  subir sem controle.

## 3. Mapa de objeção/recusa → alternativa (pivô)

Usado quando o lead recusa o principal ou insiste numa objeção forte. Em vez
de insistir no mesmo produto, o agente consulta esta tabela e oferece a
alternativa cadastrada.

| Objeção / sinal | `produto_id` alternativo a ofertar | Observação |
|---|---|---|
| "Está caro" | `oracao_audio` (R$13,90 — mais barato que o principal) | Downsell real, não o mesmo produto com desconto inventado |
| "Não tenho interesse no principal" | `oracao_audio` | Formato diferente (áudio) e menor compromisso, mesma linha de proteção |
| "Vou pensar" (2ª recusa) | `oracao_audio` | Oferta de menor compromisso, mais fácil de decidir agora |

**Limitação atual:** hoje só existe **um** produto realmente mais barato que
o principal no catálogo, então as 3 linhas convergem no mesmo `produto_id`.
Isso é honesto (não fabricamos variedade que não existe), mas se quiser
respostas mais diferenciadas por tipo de objeção no futuro, o caminho é criar
um produto de entrada dedicado — não inflar preço nem fingir opções.

Regra: o pivô só acontece **depois** de ao menos uma tentativa honesta de
tratar a objeção (ver `../00-nucleo/objetivo.md`, PROCESSO 4). Ele não substitui
o tratamento de objeção — entra quando o tratamento não resolveu.

**Runtime:** implementado via a coluna `resolve_objecao` (array) na tabela
`produtos` do Supabase — o agente recebe essa tag no catálogo injetado no
system prompt e é instruído a usá-la nesse cenário. Não é só documentação.

## 4. Mapa de perfil (arquétipo) → produto em destaque

Cruza com `../10-skills/copy/copy-persuasao-avancada.md` (arquétipos de Jung)
e os ângulos já existentes em `../10-skills/ofertas/angulos-upsell.md`.

| Arquétipo | Produto priorizado no stack | Por quê |
|---|---|---|
| Mãe Protetora | `comunidade` | Ângulo "legado para a família" — a proteção da comunidade se estende aos filhos/netos |
| Guerreira de Fé | `oracao_audio` | Ferramenta prática de uso diário — ouvir a oração para seguir "na batalha" sem desistir |
| Devota em Busca | `contato_padre` | Busca ativa por resposta/sinal — contato direto entrega isso literalmente |
| Mulher que Pertence | `comunidade` | Pertencimento é o próprio produto — match direto |

`comunidade` atende dois arquétipos com ângulos diferentes (família/legado vs.
pertencimento) — isso é normal, não uma inconsistência: o mesmo produto pode
resolver dores distintas dependendo de como é apresentado.

**Runtime:** implementado via a coluna `arquetipos` (array) em `produtos`, e
o agente agora também **detecta e grava** o arquétipo do lead
(`leads.arquetipo`) a partir de sinais da própria conversa — não inventa sem
evidência (ver `n8n/workflows/agente-vendas.json`, nodes "Arquetipo
detectado?" e "Atualizar arquetipo do lead").

## 5. Como o agente consulta este catálogo

1. Lead aceita o principal → agente apresenta o **stack completo de uma vez**
   (não item a item), mostrando uma **tabela de economia** clara: quanto cai
   o total e quanto o lead economiza a cada order bump adicionado (10%/20%/30%).
   Ver seção 6 — os números são calculados em código, nunca pelo modelo, para
   garantir que o que o lead vê bate com o que será cobrado.
2. Lead monta o carrinho → agente calcula o total com desconto (seção 2) e
   monta o `items[]` do BlackCat.
3. Lead recusa o principal ou repete objeção forte → agente consulta a
   seção 3 e oferece a alternativa, sem insistir mais de uma vez na mesma
   linha de recusa.

## 6. Tabela de economia mostrada ao lead

Calculada em código no node "Montar mensagens OpenAI"
(`n8n/workflows/agente-vendas.json`), com os preços reais da seção 1 — o
modelo recebe o texto pronto e só o apresenta, nunca recalcula. Exemplo com
os valores atuais (adicionando na ordem do catálogo):

| Ação | Subtotal sem desconto | Desconto | Total cobrado | Economia |
|---|---|---|---|---|
| Só a Oração Sagrada | R$ 22,90 | — | R$ 22,90 | — |
| + Oração em Áudio | R$ 36,80 | 10% | R$ 33,12 | R$ 3,68 |
| + Comunidade | R$ 81,70 | 20% | R$ 65,36 | R$ 16,34 |
| + Contato Direto com o Padre | R$ 101,60 | 30% | R$ 71,12 | R$ 30,48 |

Verificado: o total da linha "+ Contato Direto com o Padre" (R$ 71,12) bate
exatamente com o que "Montar items do carrinho" cobraria no BlackCat pelos
mesmos 4 itens — mesma fórmula, mesmo arredondamento por item.

## Relacionado
- [`../00-nucleo/compliance-e-etica.md`](../00-nucleo/compliance-e-etica.md) — restrições de conduta
- [`../00-nucleo/objetivo.md`](../00-nucleo/objetivo.md) — processo de objeção
- [`../10-skills/ofertas/`](../10-skills/ofertas/) — ângulos de oferta
- [`blackcat/criacao-transacao.md`](blackcat/criacao-transacao.md) — como o catálogo vira `items[]`
- [`../20-memoria/schema-conversa.md`](../20-memoria/schema-conversa.md) — registro do que foi ofertado/aceito/recusado
