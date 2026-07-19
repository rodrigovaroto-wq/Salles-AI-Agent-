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

## Campos de oferta (stack e pivô)
Gravados no momento em que o agente monta o carrinho, ver
[`../30-integracoes/catalogo-produtos.md`](../30-integracoes/catalogo-produtos.md).

| Campo | Tipo | Descrição | Exemplo |
|---|---|---|---|
| `produtos_ofertados` | array | `produto_id`s apresentados no stack | `["principal", "bump_1", "bump_2"]` |
| `produtos_aceitos` | array | `produto_id`s que o lead incluiu no carrinho | `["principal", "bump_1"]` |
| `desconto_aplicado_pct` | number | % de desconto no pedido (10% por item adicional) | `10` |
| `pivo_catalogo` | bool | Se houve pivô para produto alternativo por objeção/recusa | `true` |
| `produto_pivo_id` | string \| null | `produto_id` alternativo ofertado no pivô | `alternativo_1` |
| `link_blackcat_id` | string \| null | Referência da transação criada (`externalRef`/id BlackCat) | `txn_abc123` |

## Uso
Estes eventos são a matéria-prima de `schema-aprendizado.md`. Sem eles, não há
como o agente saber o que realmente funciona.
