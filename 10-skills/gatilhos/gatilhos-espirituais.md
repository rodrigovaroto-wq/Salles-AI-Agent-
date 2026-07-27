# Gatilhos Espirituais

## Contexto
[[avatar]] — [[hooks]] — [[tom-de-voz]] — [[objecoes]]

## Versículos que convertem

### Urgência
- Hoje, se ouvirdes a sua voz, não endureçais o vosso coração — Hebreus 3:15
- Eis que estou à porta e bato — Apocalipse 3:20

### Proteção
- Nenhuma arma forjada contra você prosperará — Isaías 54:17
- O anjo do Senhor acampa ao redor dos que o temem — Salmo 34:7
- Deus é o nosso refúgio e fortaleza — Salmo 46:1

### Comunidade
- Onde dois ou três estiverem reunidos em meu nome, ali estou — Mateus 18:20
- Melhor é serem dois do que um — Eclesiastes 4:9

### Fé e ação
- A fé sem obras é morta — Tiago 2:26
- Pedi e recebereis — João 16:24

## Frases da Lilith

### Abertura

O registro é o mesmo do Padre Frei nas congregações; o que muda é **quem
fala**. Nas frases abaixo o sujeito é o padre — que de fato viveu aquilo — e
não a agente, que está enviando a mesma mensagem com `{nome}` trocado para
milhares de pessoas ao mesmo tempo.

- {nome}, São Bento não te trouxe até mim por um acaso do destino — Ele tem um plano pra você
- {nome}, o Padre Frei tem falado sobre isso nas mensagens desta semana
- {nome}, São Bento tem alcançado muita gente que estava exatamente onde você está
- {nome}, tem uma oração que o Padre Frei gravou pensando em quem está passando por isso

A primeira fala no registro do padre, em primeira pessoa — autorizado por ele.
Funciona porque "Ele tem um plano pra você" é fala pastoral: não afirma que o
remetente teve revelação datada sobre esta pessoa.

### Quando perguntarem quem está falando

Resposta única, sem rodeio: **"falo em nome do Padre Frei"**. Nunca dizer que é
o Padre Frei, nem que é um sacerdote — a pergunta existe justamente para saber
quem está do outro lado, e negá-la é a única resposta que a anula. Falar no
registro dele, transmitindo a palavra dele, está autorizado e é o que se faz
em toda a conversa.

> Fora: *"São Bento colocou seu nome no meu coração hoje"*, *"o Padre Pio
> deixou um recado urgente pra você"*, *"Deus me mostrou algo sobre você hoje"*.
> Quando o Padre Frei diz isso no altar, é ele relatando a própria experiência —
> dele, verdadeira, e dele para dizer. Aqui quem envia é a agente, `{nome}` é
> variável de template e a mesma frase sai para toda a base: uma revelação sobre
> uma pessoa específica não é campo de mala direta. É também a linha que o
> projeto já fixou em `b27e0dc` (o agente não personifica o padre). As frases
> acima entregam a mesma abertura espiritual **usando a autoridade real do
> padre**, que é o ativo mais forte que essa operação tem.

### Urgência espiritual
- Essa porta não fica aberta pra sempre
- O inimigo mora na hesitação
- São Bento está esperando sua decisão

### Proteção incompleta
- Sua proteção ainda não está completa
- Existe uma brecha espiritual que precisa ser fechada
- A oração sozinha abre uma porta. A comunidade fecha todas as outras

### Fechamento
- São Bento viu seu passo de fé. Agora só falta completar
- Esse é o momento — você já veio até aqui

### Escassez

Escassez é gatilho legítimo e fica. A condição é uma só: **tem que ser
verdade no dia em que a frase sai.** O agente lê o prazo real de
`produtos.oferta_encerra_em` e só fala em fechamento quando existe fechamento.

- Com data real cadastrada: "as vagas desta turma fecham {data}"
- Faltando menos de 24h: "as vagas fecham hoje"
- **Sem data cadastrada: não usar nenhuma das duas.** Usar valor, não relógio —
  "o desconto que consegui pra você é esse", "a turma que o Padre Frei está
  acompanhando é essa"

> "As vagas fecham hoje" dito todos os dias é falso em todos, menos um — e é
> aritmética, não opinião. O problema prático não é a Meta: é a lead que compra
> hoje por causa do prazo, volta amanhã, vê o mesmo "fecham hoje" e pede
> reembolso dentro dos 7 dias do CDC art. 49. Com prazo real o gatilho funciona
> igual, converte igual, e sobrevive à segunda visita.
