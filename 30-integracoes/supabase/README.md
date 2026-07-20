# Supabase — Memória do Agente

Banco (Postgres gerenciado) que guarda leads, conversas, a fila de sugestões do
Hermes e o prompt ativo versionado. É a camada `../../20-memoria/` materializada.

## Passo a passo (rápido)

1. Crie um projeto no Supabase (região mais perto do Brasil, ex.: São Paulo).
2. SQL Editor → cole e rode [`schema.sql`](schema.sql). Cria as 7 tabelas com
   índices, checks, RLS ligado, e já popula `produtos` com o catálogo real
   (ver `../catalogo-produtos.md`).
3. Em **Project Settings → API**, copie:
   - `Project URL`
   - `service_role key` (a secreta) — usada pelo n8n e pelo Hermes.
4. Guarde essas duas como **variáveis de ambiente** no n8n e na VPS do Hermes.
   Nunca use a `anon key` no backend e nunca commite as chaves.

## Tabelas

| Tabela | Papel | Origem |
|---|---|---|
| `leads` | Ficha permanente (1 por pessoa) | `../../20-memoria/schema-lead.md` |
| `conversas` | Eventos de cada conversa (N por lead) | `../../20-memoria/schema-conversa.md` |
| `metricas_periodo` | Snapshots de performance p/ análise | `../../20-memoria/schema-aprendizado.md` |
| `fila_sugestoes` | Sugestões do Hermes aguardando aprovação | `../hermes/fila-aprovacao.md` |
| `prompt_ativo` | Versão vigente do prompt/skills (com rollback) | `../hermes/configuracao.md` |
| `produtos` | Catálogo real (nome, tipo, preço) — o agente e o carrinho leem daqui, não de valor fixo no código | `../catalogo-produtos.md` |

## Notas

- **RLS ligado sem policies**: `anon`/`authenticated` não acessam nada; só a
  `service_role` (backend). Protege o PII dos leads (LGPD).
- **`prompt_ativo`**: índice único parcial garante uma versão ativa por `chave`.
  Para aplicar uma sugestão aprovada: marque a versão antiga `ativo=false` e
  insira a nova com `ativo=true` (a anterior fica para reverter).
- **`consentimento_contato`** e `status='opt_out'` em `leads` são o que sustenta
  o opt-in exigido para mensagens fora da janela de 24h.
