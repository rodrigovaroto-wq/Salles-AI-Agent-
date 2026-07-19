# Classificador de Risco de Conformidade

Camada que roda **antes** de as sugestões do Hermes chegarem à fila de
aprovação (`fila-aprovacao.md`). Ela **não descarta e não bloqueia nada** — sua
função é anexar a cada sugestão um **rótulo de risco de conformidade** e o
motivo, para que a triagem humana seja mais rápida e informada. Toda sugestão
segue para a fila; quem decide o que fazer com cada uma é sempre você.

## Como funciona
Cada `[SUGESTÃO N]` gerada pelo Hermes é avaliada contra os padrões abaixo,
derivados de `../../10-skills/CONFORMIDADE.md` e do `CONTEXT8` de
`../../00-nucleo/objetivo.md`. O classificador anexa à sugestão:
- `risco_conformidade`: `alto` / `medio` / `baixo`
- `padrao_disparado`: qual padrão motivou o rótulo (ou vazio, se nenhum)

E encaminha **todas** as sugestões para a fila. Nenhuma some no caminho — as de
risco alto chegam sinalizadas para você olhar primeiro.

## Risco ALTO (🔴 — sinalizado para atenção prioritária)
Bate com uma tática que o núcleo proíbe. **Não é bloqueada** — é marcada e
enviada para o topo da sua triagem, porque é o tipo de sugestão que você
provavelmente vai rejeitar, mas quer ver com os próprios olhos.

| Padrão detectado | Exemplo do que dispara |
|---|---|
| Afirmação de cura/resultado de saúde | "sumiu a dor", "exame voltou limpo", "curou a doença" |
| Estatística sem fonte rastreável no catálogo/dados reais | "97 mil pessoas...", números que não batem com `20-memoria/schema-aprendizado.md` |
| Atribuição de fala a pessoa real (viva ou morta) sem fonte pública verificável | "Papa disse...", "Padre Pio deixou recado..." |
| Escassez/urgência sem lastro em dado real de estoque/vaga | "só restam X vagas" sem existir controle de estoque real |
| Alegação de garantia não registrada como política real da empresa | qualquer garantia que não está documentada como oferta oficial |
| Reforço de tática já listada como 🔴 em `CONFORMIDADE.md` | qualquer variação das táticas já mapeadas |

## Risco MÉDIO (🟡 — depende de volume de dados)
A técnica é legítima, mas otimizar em cima de poucas conversas gera ruído. O
rótulo médio indica que vale conferir se o volume de dados sustenta a sugestão.

| Categoria | Observação para a triagem |
|---|---|
| Mudança de ângulo de oferta (`10-skills/ofertas/`) | Confirmar se baseada em ≥ N conversas com desfecho registrado *(definir N ao operar)* |
| Ajuste de tom por estado emocional (`00-nucleo/ciclos-emocionais.md`) | Idem |
| Nova alternativa no catálogo (pivô por objeção) | Idem, e produto deve já existir em `30-integracoes/catalogo-produtos.md` |

## Risco BAIXO (🟢)
Sugestões sobre estrutura de conversa, ordem de perguntas de descoberta,
formatação de mensagem, timing de follow-up — sem nenhum padrão 🔴 acima.
Chegam à fila com rótulo baixo, adequadas para aprovação mais ágil.

## Campos anexados a cada sugestão
Em vez de um log separado de "itens barrados", o classificador enriquece a
própria sugestão que vai para a fila:

| Campo | Descrição |
|---|---|
| `risco_conformidade` | `alto` / `medio` / `baixo` |
| `padrao_disparado` | qual regra das tabelas acima marcou a sugestão (ou vazio) |
| `texto_proposto` | a "Mudança proposta" literal, para você ler antes de decidir |

Como **nada é descartado**, você audita 100% do que o Hermes propõe direto na
fila. Se o volume de sugestões de risco alto crescer, é sinal de que o
otimizador está convergindo para táticas problemáticas — e aí vale revisar se
ele deveria seguir analisando esses dados sem ajuste.

## Manutenção
Este classificador deve ser atualizado sempre que
`../../10-skills/CONFORMIDADE.md` mudar. Ele é uma derivação automatizável
daquele documento, não uma fonte paralela de regras.
