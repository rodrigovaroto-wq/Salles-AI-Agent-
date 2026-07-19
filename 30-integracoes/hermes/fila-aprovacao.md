# Fila de Aprovação

O único ponto de entrada de qualquer mudança gerada pelo Hermes para o
comportamento ativo do agente. Vive no mesmo banco da camada de memória
(Supabase, ver `../../20-memoria/`) como uma tabela dedicada.

## Schema

| Campo | Tipo | Descrição | Exemplo |
|---|---|---|---|
| `sugestao_id` | string | Identificador único | `uuid` |
| `criado_em` | datetime | Quando o Hermes gerou | `2026-07-20T09:00:00Z` |
| `area` | enum | Onde a mudança se aplica | `abertura` / `descoberta` / `objecao` / `stack_oferta` / `follow_up` / `catalogo` |
| `arquivo_alvo` | string | Caminho do arquivo que seria editado | `00-nucleo/tom-de-voz.md` |
| `problema_observado` | text | Evidência dos dados que motivou a sugestão | "leads do TikTok abandonam 40% na 2ª pergunta de descoberta" |
| `hipotese_impacto` | text | O que se espera melhorar | "reduzir abandono em ~15% na descoberta" |
| `mudanca_proposta` | text | O texto/regra **literal** que entraria no arquivo | (diff ou trecho exato) |
| `teste_sugerido` | text | Como validar após aplicar | "A/B por 200 conversas" |
| `confianca` | enum | Baseado em volume de dados | `alta` / `media` / `baixa` |
| `passou_filtro` | bool | Se passou no filtro automático | `true` |
| `status` | enum | Estado atual | `pendente` / `aprovada` / `rejeitada` |
| `decidido_por` | string | Quem decidiu (sempre humano) | `rodrigo` |
| `decidido_em` | datetime \| null | Quando a decisão foi tomada | `2026-07-21T10:00:00Z` |
| `motivo_rejeicao` | text \| null | Se rejeitada, por quê (alimenta aprendizado negativo) | "risco de soar agressivo demais para o perfil idoso" |
| `aplicado_em` | datetime \| null | Quando a mudança entrou em produção, se aprovada | `2026-07-21T11:00:00Z` |

## Fluxo de status

```
pendente ──(você aprova)──► aprovada ──► (aplicada em 00-nucleo/ ou 10-skills/)
    │
    └──(você rejeita)──► rejeitada ──► (registrada como aprendizado negativo)
```

Não existe transição automática para `aprovada`. O campo `decidido_por` é
sempre um humano — nunca um processo.

## Aprendizado a partir de rejeições
Sugestões rejeitadas alimentam `../../20-memoria/schema-aprendizado.md`: se o
Hermes propõe repetidamente a mesma linha de hipótese já rejeitada, isso é um
sinal para ele parar de re-propor variações da mesma tática — não para
insistir com pequenas variações até passar.

## Interface de revisão
Para o fluxo ser rápido (ver `ciclo-aprendizado.md`), a fila deve ser
consultável de forma simples — uma view no Supabase, uma planilha sincronizada,
ou um painel simples no n8n. Formato de decisão sugerido: revisão em lote,
sugestões de `confianca: alta` e área de baixo risco (`abertura`,
`follow_up`) agrupadas para aprovação rápida; `stack_oferta` e `catalogo`
revisadas individualmente por afetarem preço/produto diretamente.
