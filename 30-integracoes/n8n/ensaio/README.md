# Ensaio local do prompt

```bash
node 30-integracoes/n8n/ensaio/ensaio-prompt.js
```

Roda o `jsCode` real do node **"Montar mensagens OpenAI"** — lido direto de
`../workflows/agente-vendas.json`, não uma cópia — contra 10 cenários
simulados, usando o conteúdo real de `00-nucleo/` e o catálogo real do
`schema.sql`.

Não chama a OpenAI, não escreve no Supabase, não cria cobrança no BlackCat.
Custo zero, roda em menos de um segundo.

## O que ele verifica

- **Guardrails**: CVV 188, `intent="sofrimento"`, `intent="opt_out"`, "Pare de
  vender", schema JSON e "nunca invente produto ou preço" presentes nos 10
  cenários.
- **Prefixo de cache**: que o `BLOCO_A` é byte-idêntico entre leads diferentes.
  Se alguém interpolar um dado de lead ali dentro, o cache quebra e o custo por
  lead triplica — este teste pega isso.
- **Seleção de objeções**: quais seções entram em cada cenário, e o tamanho do
  prompt resultante.
- **Modo sem venda**: que `status = 'aguardando_humano'` suprime a venda.
- **Cliente que já comprou**: que a tabela de desconto some.
- **Faixas P1/P2**: que as duas estão no prompt, com a regra de desempate
  ("na dúvida, P2") e a proibição de emendar oferta na dor. Os cenários 11–13
  são de dor real **sem** risco à vida — luto, dívida, doença na família — e
  existem para flagrar se o gatilho de crise voltar a pegar conversa normal.

## O que ele NÃO verifica

Comportamento do modelo. Ele valida o prompt **montado**, não a resposta.
Se o agente vai de fato parar de vender diante de sofrimento real depende da
OpenAI e só o ensaio com chamada real responde — ver `../../VALIDACAO.md` §3.5.

Rode este a cada mudança no node; rode o §3.5 antes de ligar anúncio.
