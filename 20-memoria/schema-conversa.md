# Schema — Eventos de Conversa

N registros por lead. Cada conversa gera eventos que alimentam a análise de
"onde a venda foi ganha ou perdida" (CONTEXT6 / CONTEXT7 do núcleo).

## Campos

| Campo | Tipo | Descrição | Exemplo |
|---|---|---|---|
| `evento_id` | string | Identificador único do evento | `uuid` |
| `lead_id` | string | Referência à ficha do lead | `5511987654321` |
| `timestamp` | datetime | Quando ocorreu | `2026-07-18T14:05:00Z` |
| `etapa_processo` | enum | Etapa do processo de venda (CONTEXT5) | `conexao` / `descoberta` / `apresentacao` / `objecao` / `fechamento` / `recuperacao` / `upsell` |
| `mensagem_agente` | text | O que o agente enviou | `"O que mais pesa hoje na sua família?"` |
| `mensagem_lead` | text | O que o lead respondeu | `"Meu filho se afastou"` |
| `objecao_detectada` | string \| null | Objeção identificada neste ponto | `preco` |
| `gatilho_usado` | string \| null | Técnica/gatilho aplicado | `prova_social` |
| `resultado_parcial` | enum | Efeito observado | `avancou` / `estagnou` / `recuou` / `converteu` / `perdeu` |
| `sentimento_lead` | enum | Leitura do tom da resposta | `positivo` / `neutro` / `resistente` |

## Marcadores especiais (para análise)
Ao encerrar a conversa, gravar um evento-resumo com:

| Campo | Descrição |
|---|---|
| `desfecho` | `venda` / `sem_venda` / `follow_up_agendado` |
| `etapa_de_perda` | Em qual etapa travou, se não vendeu |
| `mensagem_pivo` | A mensagem que virou (ou quebrou) a conversa |
| `tempo_ate_decisao` | Minutos entre 1ª mensagem e desfecho |

## Uso
Estes eventos são a matéria-prima de `schema-aprendizado.md`. Sem eles, não há
como o agente saber o que realmente funciona.
