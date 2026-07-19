# Schema — Aprendizado e Performance

Agregados calculados periodicamente (diário/semanal) a partir dos eventos de
conversa. É o que materializa o CONTEXT7 (Análise de Performance) e o CONTEXT10
(Auto-avaliação) do núcleo.

## 1. Métricas do período

| Métrica | Cálculo | Meta de referência |
|---|---|---|
| `receita_por_conversa` | Receita total ÷ conversas iniciadas | **métrica principal (CONTEXT2)** |
| `taxa_conversao` | Vendas ÷ leads qualificados | acompanhar tendência |
| `ticket_medio` | Receita ÷ nº de pedidos | acompanhar tendência |
| `taxa_recuperacao` | Vendas recuperadas ÷ abandonos | acompanhar tendência |
| `tempo_medio_decisao` | Média de `tempo_ate_decisao` | quanto menor, melhor |
| `taxa_resposta` | Leads que responderam ÷ total abordado | qualidade do follow-up |

## 2. Ranking de eficácia (o que otimizar)

Gerado a partir de `gatilho_usado` + `resultado_parcial`:

- **Gatilhos que mais converteram** (top 5)
- **Mensagens-pivô vencedoras** (frases que viraram a conversa)
- **Objeções mais frequentes** e taxa de superação de cada uma
- **Etapa que mais perde** (onde o funil vaza)

## 3. Sugestões de melhoria (formato CONTEXT10)

O agente produz, sem editar o núcleo diretamente, blocos como:

```
[SUGESTÃO 1] — <área>
Problema observado: <evidência dos dados>
Hipótese de impacto: <conversão / ticket / satisfação>
Teste proposto: <A/B ou experimento>
```

## Princípio inegociável
As sugestões devem nascer de **dados reais** (eventos de conversa efetivamente
ocorridos). Uma métrica bonita construída sobre provas fabricadas não mede nada —
só esconde o problema. Ver CONTEXT8 e CONTEXT9 do núcleo.
