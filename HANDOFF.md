# Handoff — 2026-07-27

Estado do projeto para retomar sem reconstruir o histórico.

> O documento vivo do que falta é [`CHECKLIST-PRE-LEADS.md`](CHECKLIST-PRE-LEADS.md).
> Este aqui é o contexto: o que mudou por último e por quê.

## Estado

- `main` em `3a107cd` (PR #20 mergeado). Trabalho posterior na branch
  `claude/ensaio-funil-local`.
- **Nada desta sessão está ao vivo.** Os `.md` são fonte no git; o que roda é a
  cópia em `prompt_ativo` (Supabase) e a cópia dos workflows dentro do n8n.
  Os dois precisam de um passo manual — ver "Para valer ao vivo", abaixo.
- Os 7 workflows no n8n estão **inativos** e datam de 26/07, antes de tudo que
  foi feito em 27/07.

## O que mudou em 27/07

### Custo por lead: R$ 2,89 → ~R$ 1,07
Medido com `tiktoken` (`o200k_base`). O system prompt tinha 9.958 tokens e era
reenviado inteiro a cada mensagem — 252 mil tokens por lead numa conversa de 20
trocas. Três mudanças no node `Montar mensagens OpenAI`:

- **`BLOCO_A` / `BLOCO_B`.** A OpenAI cacheia o maior prefixo comum (≥1024
  tokens) e cobra 25% nele. ~950 tokens de instrução fixa ficavam *depois* do
  catálogo e da tabela de preços, que variam por lead, e por isso nunca
  cacheavam. Agora tudo que é estático vem primeiro. **Uma única interpolação
  de dado de lead dentro do `BLOCO_A` quebra o cache e triplica o custo** — o
  ensaio local testa isso.
- **Objeções sob demanda.** `objecoes.md` é fatiado pelos cabeçalhos `## `;
  entra o núcleo mais as seções cujo gatilho aparece na mensagem atual ou nas 4
  últimas trocas. Seleção por palavra-chave, sem chamada extra de modelo.
- **Cap de histórico.** Últimas 8 trocas na íntegra, o resto resumido numa linha.

### Sofrimento: duas faixas (P1/P2)
O gatilho era binário e largo — "perda, doença grave, desesperança" derrubava a
venda inteira. Neste público isso é assunto corriqueiro, então conversa normal
caía no filtro de crise.

- **P2 — dor real sem risco à vida** (luto, doença na família, dívida, solidão):
  **não para a venda, não notifica ninguém.** O agente acolhe primeiro e de
  verdade, não abre com produto, não emenda oferta na dor. Daí segue normal com
  os intents de sempre.
- **P1 — risco à vida**: só menção explícita a se ferir, morrer ou desistir de
  viver. Para a venda, orienta CVV 188, retorna `intent="sofrimento"` e notifica
  um humano. A seção lista os exemplos que contam **e os que não contam**, com
  regra de desempate: na dúvida, é P2.

### Conteúdo
- `testemunhos.md`: os 4 depoimentos são relatos reais recebidos pelo Padre Frei
  (a classificação anterior no `CONFORMIDADE.md` estava errada). A nota "para
  parecer real" virou proibição de criar novos. Saiu o claim de cura e a frase
  "quem não viu resultado estava fazendo errado". Números agregados marcados
  `[fonte pendente]`.
- `gatilhos-espirituais.md`: escassez mantida, agora lastreada em
  `produtos.oferta_encerra_em` (sem data ⇒ não fala em vagas). Abertura
  aprovada: *"{nome}, São Bento não te trouxe até mim por um acaso do destino —
  Ele tem um plano pra você."* Ao ser perguntado quem fala: **"falo em nome do
  Padre Frei"** — não afirma ser o padre.
- Prova social aprovada: *"Mais de duzentos relatos por semana, sem falhar.
  Duzentas famílias que estavam onde você está e hoje não estão mais."*
- `[CONTEXT10]` saiu do `objetivo.md` para o Hermes: instruía o agente a emitir
  blocos `[SUGESTÃO N]`, o que podia vazar numa conversa real.

## Para valer ao vivo (2 passos manuais)

1. **Supabase** — regenerar e rodar o seed:
   ```bash
   python3 30-integracoes/supabase/gerar-seed-prompt.py
   ```
   Colar `30-integracoes/supabase/seed-prompt.sql` no SQL Editor. Cobre as três
   chaves (`objetivo`, `compliance`, `objecoes`).
   Rodar também `migracao-escassez.sql` se quiser escassez datada.
   > O antigo `seed-prompt-objecoes.sql` foi removido: cobria só duas chaves e
   > rodá-lo hoje reverteria o prompt.

2. **n8n** — recolar os workflows. Os `.json` do git são a fonte; o n8n tem
   cópia própria. Abrir o workflow → Ctrl+A → deletar → colar o `.json` →
   salvar. Detalhe em [`30-integracoes/APLICAR-AO-VIVO.md`](30-integracoes/APLICAR-AO-VIVO.md).

## Ferramentas

- **n8n MCP**: os 7 workflows estão com `availableInMCP: false`. Habilitando o
  acesso MCP no card de cada um, dá para recolar e testar direto daqui, sem
  cliques. Instância: `https://salles-ai-agent.pikapod.net`.
- **Ensaio local**: `node 30-integracoes/n8n/ensaio/ensaio-prompt.js` roda o
  `jsCode` real do node contra 13 cenários, sem n8n, sem OpenAI, sem custo.
  Valida os guardrails e o prefixo de cache. **Rode a cada mudança no node.**
  Não substitui o `VALIDACAO.md` §3.5: valida o prompt montado, não a resposta
  do modelo.

## Padrões (manter consistência)

- **Camadas**: `00-nucleo/` (prompt sempre ativo) → `10-skills/` (sob demanda,
  NÃO carregado ao vivo) → `20-memoria/` (schemas) → `30-integracoes/`.
- **Prompt ao vivo carrega só** `objetivo`, `compliance`, `objecoes` de
  `prompt_ativo`. Nada de `10-skills/` entra automaticamente.
- **`compliance-e-etica.md` é a fonte única de conduta** e vence em conflito.
  As regras operativas de como-fazer vivem no `objecoes.md`; o compliance tem os
  princípios. Não são duplicata uma da outra.
- **Editou um `.md` de `00-nucleo/`?** Rode o gerador do seed. Sem isso a
  mudança existe no git e não existe ao vivo.
- **Editou o node?** Rode o ensaio local antes de recolar.
- Segredos só como Credentials nativas do n8n (PikaPods não tem `$env`).
- Desconto sempre aplicado de verdade no valor cobrado.
