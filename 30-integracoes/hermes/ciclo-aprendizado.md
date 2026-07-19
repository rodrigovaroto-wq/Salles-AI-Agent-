# Ciclo de Aprendizado — Hermes + Gate Humano

Materializa o `CONTEXT7` (Análise Periódica de Performance) e o `CONTEXT10`
(Auto-avaliação e Sugestões) de `../../00-nucleo/objetivo.md`, com o Hermes
Agent como o motor de análise assíncrona.

## Visão geral do fluxo

```
Conversas reais (WhatsApp)
        │
        ▼
20-memoria/schema-conversa.md + schema-aprendizado.md  (dados brutos)
        │
        ▼
HERMES roda em cron (ex.: diário ou semanal)
  → lê os dados acumulados
  → identifica padrões (o que converteu, onde travou, qual mensagem-pivô)
  → gera hipóteses de melhoria no formato [SUGESTÃO N]
        │
        ▼
CLASSIFICADOR DE CONFORMIDADE (automático — ver filtro-conformidade.md)
  → NÃO descarta nada; anexa a cada sugestão um rótulo de risco
    (alto / medio / baixo) + o padrão que disparou
  → encaminha TODAS as sugestões para a fila
        │
        ▼
FILA DE APROVAÇÃO (ver fila-aprovacao.md)
  → todas as sugestões esperam decisão humana; as de risco alto
    aparecem no topo, sinalizadas para atenção
        │
        ▼
VOCÊ (Rodrigo): aprova ou rejeita cada uma
        │
   ┌────┴────┐
   ▼         ▼
APROVADA   REJEITADA
   │         │
   ▼         ▼
Vira instrução     Fica registrada
ativa em                como aprendizado
00-nucleo/ ou            negativo (não
10-skills/                repetir a hipótese)
   │
   ▼
Volta a alimentar as conversas reais → fecha o ciclo
```

## Passo a passo detalhado

### 1. Coleta (contínua)
Cada conversa grava eventos em `../../20-memoria/schema-conversa.md`. Os
agregados de performance rodam em `../../20-memoria/schema-aprendizado.md`.

### 2. Análise (Hermes, em cron — ex.: semanal)
O Hermes lê os agregados e o log de eventos e produz um lote de hipóteses,
cada uma no formato já definido no `CONTEXT10` do núcleo:

```
[SUGESTÃO N] — <área: abertura / objeção / stack de oferta / follow-up / etc.>
Problema observado: <evidência concreta dos dados>
Hipótese de impacto: <conversão / ticket médio / satisfação>
Mudança proposta: <o texto/regra exata que mudaria, palavra por palavra>
Teste sugerido: <A/B ou janela de observação>
Confiança: <alta / média / baixa, baseada em volume de dados>
```

A "Mudança proposta" precisa ser **literal** — o texto exato que entraria no
núcleo ou na skill, não uma ideia vaga. Isso é o que o classificador rotula e
você avalia.

### 3. Classificador de conformidade (ver `filtro-conformidade.md`)
Toda sugestão passa por uma checagem de padrões que **não descarta nada** —
apenas anexa um rótulo de risco (`alto`/`medio`/`baixo`) e o padrão que
disparou. **Todas** as sugestões, inclusive as de risco alto, seguem para a
fila. A triagem é 100% sua: você vê tudo o que o Hermes propôs.

### 4. Fila de aprovação (ver `fila-aprovacao.md`)
Todas as sugestões entram na fila com status `pendente`, ordenadas por risco
(alto no topo). Nada sai daqui sem decisão sua.

### 5. Decisão humana
Você revisa cada sugestão pendente e marca `aprovada` ou `rejeitada`. Uma
sugestão aprovada vira uma edição real em `00-nucleo/` ou `10-skills/` — o
Hermes prepara o diff, mas **a aplicação exige seu aprovado explícito**.

### 6. Aplicação e fechamento do ciclo
Mudança aprovada entra em produção → volta a gerar dados de conversa → o
próximo ciclo do Hermes já mede o efeito da mudança anterior.

## O que garante que isso não vira burocracia lenta
- O rótulo de risco ordena a fila: você olha o crítico primeiro e trata o resto
  mais rápido, sem precisar ler tudo com a mesma profundidade.
- Sugestões de baixo risco/alta confiança podem ser aprovadas em lote (ex.:
  revisão de 10-15 min por ciclo, não uma por uma em profundidade).
- O Hermes nunca fica bloqueado esperando: ele continua analisando o próximo
  ciclo de dados mesmo com sugestões antigas pendentes de decisão.

## O que nunca muda
- O Hermes não tem permissão de escrita direta em `00-nucleo/` ou
  `10-skills/`. Ele só escreve na fila (`fila-aprovacao.md` / equivalente em
  banco).
- O classificador de conformidade nunca descarta uma sugestão sozinho — só
  rotula. A triagem é sempre humana.
- Nenhuma mudança pula a aprovação humana, qualquer que seja o rótulo de risco
  ou a confiança de conversão.
