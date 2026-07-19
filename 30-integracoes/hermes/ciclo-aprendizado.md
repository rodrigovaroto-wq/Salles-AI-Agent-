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
FILTRO DE CONFORMIDADE (automático — ver filtro-conformidade.md)
  → descarta sugestões que violam CONTEXT8/CONFORMIDADE.md
  → tudo descartado fica registrado (nunca invisível)
        │
        ▼
FILA DE APROVAÇÃO (ver fila-aprovacao.md)
  → sugestões que passaram no filtro esperam decisão humana
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
núcleo ou na skill, não uma ideia vaga. Isso é o que o filtro e você avaliam.

### 3. Filtro automático (ver `filtro-conformidade.md`)
Toda sugestão passa por uma checagem de padrões antes de chegar à fila.
Sugestões reprovadas **não desaparecem** — ficam registradas com o motivo da
reprovação, para você poder auditar o que o Hermes tentou propor e foi barrado.

### 4. Fila de aprovação (ver `fila-aprovacao.md`)
Sugestões aprovadas no filtro entram numa fila com status `pendente`. Nada
sai daqui sem decisão sua.

### 5. Decisão humana
Você revisa cada sugestão pendente e marca `aprovada` ou `rejeitada`. Uma
sugestão aprovada vira uma edição real em `00-nucleo/` ou `10-skills/` — o
Hermes prepara o diff, mas **a aplicação exige seu aprovado explícito**.

### 6. Aplicação e fechamento do ciclo
Mudança aprovada entra em produção → volta a gerar dados de conversa → o
próximo ciclo do Hermes já mede o efeito da mudança anterior.

## O que garante que isso não vira burocracia lenta
- O filtro automático já elimina o volume óbvio antes de chegar a você.
- Sugestões de baixo risco/alta confiança podem ser aprovadas em lote (ex.:
  revisão de 10-15 min por ciclo, não uma por uma em profundidade).
- O Hermes nunca fica bloqueado esperando: ele continua analisando o próximo
  ciclo de dados mesmo com sugestões antigas pendentes de decisão.

## O que nunca muda
- O Hermes não tem permissão de escrita direta em `00-nucleo/` ou
  `10-skills/`. Ele só escreve na fila (`fila-aprovacao.md` / equivalente em
  banco).
- Nenhuma mudança pula o filtro de conformidade, mesmo com alta confiança de
  conversão.
- Nenhuma mudança pula a aprovação humana, mesmo passando no filtro.
