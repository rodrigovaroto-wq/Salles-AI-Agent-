# Classificador de Risco de Conformidade

Camada que roda **antes** de as sugestões do Hermes chegarem à fila de
aprovação (`fila-aprovacao.md`). Ela **não descarta e não bloqueia nada** — sua
função é anexar a cada sugestão um **rótulo de risco de conformidade** e o
motivo, para que a triagem humana seja mais rápida e informada. Toda sugestão
segue para a fila; quem decide o que fazer com cada uma é sempre você.

## Como funciona
Cada `[SUGESTÃO N]` gerada pelo Hermes é avaliada e recebe:
- `risco_conformidade`: `alto` / `medio` / `baixo`
- `padrao_disparado`: qual padrão motivou o rótulo (ou vazio, se nenhum)

E encaminha **todas** as sugestões para a fila. Nenhuma some no caminho — as de
risco alto chegam sinalizadas para você olhar primeiro.

## Risco ALTO (🔴 — sinalizado para atenção prioritária)
A sugestão bate com uma das **proibições absolutas da seção 2 de
[`../../00-nucleo/compliance-e-etica.md`](../../00-nucleo/compliance-e-etica.md)**
(cura/saúde, resultado financeiro, prova social fabricada, fala atribuída a
pessoa real sem fonte, escassez/garantia falsa, pseudo-ciência como fato,
coerção). Essa lista é a fonte única — o classificador deriva dela, não a
repete. **Não é bloqueada** — é marcada e enviada para o topo da sua triagem,
porque é o tipo de sugestão que você provavelmente vai rejeitar, mas quer ver
com os próprios olhos.

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
| `padrao_disparado` | qual proibição (seção 2 do compliance) marcou a sugestão (ou vazio) |
| `texto_proposto` | a "Mudança proposta" literal, para você ler antes de decidir |

Como **nada é descartado**, você audita 100% do que o Hermes propõe direto na
fila. Se o volume de sugestões de risco alto crescer, é sinal de que o
otimizador está convergindo para táticas problemáticas — e aí vale revisar se
ele deveria seguir analisando esses dados sem ajuste.

## Manutenção
Este classificador deve ser atualizado sempre que a seção 2 de
`../../00-nucleo/compliance-e-etica.md` mudar. Ele é uma derivação
automatizável daquele arquivo, não uma fonte paralela de regras.
