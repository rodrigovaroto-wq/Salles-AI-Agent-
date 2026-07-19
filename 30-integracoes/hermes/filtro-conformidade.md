# Filtro Automático de Conformidade

Camada de pré-triagem que roda **antes** de qualquer sugestão do Hermes
chegar à fila de aprovação humana (`fila-aprovacao.md`). Não substitui a
revisão manual — reduz o volume e cria um segundo registro de auditoria.

## Como funciona
Cada `[SUGESTÃO N]` gerada pelo Hermes é avaliada contra os padrões abaixo,
derivados de `../../10-skills/CONFORMIDADE.md` e do `CONTEXT8` de
`../../00-nucleo/objetivo.md`. Se a "Mudança proposta" da sugestão contém
qualquer um dos padrões de reprovação automática, ela é bloqueada antes da
fila.

## Padrões de reprovação automática (🔴 bloqueio direto)

| Padrão detectado | Exemplo do que dispara |
|---|---|
| Afirmação de cura/resultado de saúde | "sumiu a dor", "exame voltou limpo", "curou a doença" |
| Estatística sem fonte rastreável no catálogo/dados reais | "97 mil pessoas...", números que não batem com `20-memoria/schema-aprendizado.md` |
| Atribuição de fala a pessoa real (viva ou morta) sem fonte pública verificável | "Papa disse...", "Padre Pio deixou recado..." |
| Escassez/urgência sem lastro em dado real de estoque/vaga | "só restam X vagas" sem existir controle de estoque real |
| Alegação de garantia não registrada como política real da empresa | qualquer garantia que não está documentada como oferta oficial |
| Reforço de tática já listada como 🔴 em `CONFORMIDADE.md` | qualquer variação das táticas já mapeadas |

## Padrões que exigem confiança mínima de dados (🟡 exige volume antes de liberar)

Sugestões nestas categorias passam ao filtro, mas só seguem para a fila se o
volume de dados que as sustenta for suficiente (evita otimizar em cima de
ruído/poucas conversas):

| Categoria | Confiança mínima exigida |
|---|---|
| Mudança de ângulo de oferta (`10-skills/ofertas/`) | Baseada em ≥ N conversas com desfecho registrado *(definir N ao operar)* |
| Ajuste de tom por estado emocional (`00-nucleo/ciclos-emocionais.md`) | Idem |
| Nova alternativa no catálogo (pivô por objeção) | Idem, e produto deve já existir em `30-integracoes/catalogo-produtos.md` |

## O que passa livre (🟢)
Sugestões sobre estrutura de conversa, ordem de perguntas de descoberta,
formatação de mensagem, timing de follow-up — desde que não envolvam nenhum
padrão 🔴 acima — vão direto para a fila sem retenção adicional.

## Registro de auditoria
Toda sugestão bloqueada automaticamente é gravada com:

| Campo | Descrição |
|---|---|
| `sugestao_id` | referência à sugestão original do Hermes |
| `padrao_disparado` | qual regra da tabela acima motivou o bloqueio |
| `texto_proposto` | a "Mudança proposta" literal que foi barrada |
| `timestamp` | quando foi gerada e bloqueada |

Isso permite auditar periodicamente **o que o Hermes tentou propor e por
quê foi barrado** — um sinal de saúde do próprio experimento: se o volume de
bloqueios crescer, é indício de que o otimizador está de fato convergindo
para táticas problemáticas, e vale revisar se ele deveria continuar analisando
esses dados sem ajuste.

## Manutenção
Este filtro deve ser atualizado sempre que `../../10-skills/CONFORMIDADE.md`
mudar. Ele é uma derivação automatizável daquele documento, não uma fonte
paralela de regras.
