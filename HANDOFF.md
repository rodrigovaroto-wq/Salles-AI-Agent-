# Handoff — 2026-07-21

Nota de transição de sessão (contexto ficou muito longo). Objetivo: a próxima
sessão retomar sem precisar reconstruir o histórico.

## Estado atual

- **`main`** está atualizado até o PR #14 (merge `1c63865`) — catálogo real,
  correção de desconto, migração `$env` → Credentials nativas, URLs
  preenchidas, e a correção completa da integração BlackCat (endpoint,
  autenticação, nomes de campo).
- Nesta sessão, coleta de **email + CPF** foi implementada em cima disso
  (ainda não commitada — ver "Arquivos tocados"). Resolve o TODO bloqueante
  que ficara pendente: a API do BlackCat exige `customer{name,email,phone,
  document{number,type}}` completo no próprio `create-sale` (não dá pra
  completar depois na página de checkout hospedada — o link só é gerado se
  o `customer` já vier completo). Confirmado via docs.blackcatoficial.com
  nesta sessão: `document.type` é `cpf`|`cnpj` em minúsculo, `phone` e
  `document.number` são digits-only.
- O ciclo de aprendizado do Hermes (filtro de conformidade) já está migrado
  para "classifica risco e encaminha tudo pra fila humana" — mergeado desde
  o PR #2. Não há trabalho pendente nessa frente.

## Decisão tomada nesta sessão (substitui a decisão 3 do handoff anterior)

A decisão anterior (email/CPF só no checkout hospedado) foi **revertida**
porque contradizia a doc oficial do BlackCat. Fluxo atual:

- O agente continua coletando só nome + telefone (wa_id) no início da
  conversa, como sempre.
- Assim que o lead aceita o stack (`intent=aceitou_stack`), antes de gerar o
  link, o agente pede e-mail e CPF numa única mensagem objetiva.
- O modelo só retorna `intent=gerar_link` quando já tiver os dois (na
  mensagem atual ou em qualquer ponto anterior do histórico) — instrução
  em "Montar mensagens OpenAI" (`agente-vendas.json` / `workflow-completo.json`).
- Email e CPF (digits-only) são gravados em `leads.email`/`leads.cpf`
  (novo node **"Salvar dados de pagamento do lead"**, PATCH ao Supabase,
  disparado em paralelo a "Montar items do carrinho" a partir do IF
  `Intent = gerar_link?`).
- `Criar venda BlackCat` agora monta o objeto `customer` completo
  (`name` do WhatsApp, `email`/`cpf` extraídos pelo modelo, `phone` = wa_id,
  `document.type = 'cpf'`).
- Schema do Supabase (`30-integracoes/supabase/schema.sql`) ganhou colunas
  `leads.email` / `leads.cpf`, com `alter table ... add column if not
  exists` pra rodar em cima do banco que o Rodrigo já tem.

## Próximos passos (ordem sugerida)

1. **Commitar e dar push** das mudanças desta sessão (ver "Arquivos
   tocados" — ainda não commitadas no momento em que este handoff foi
   escrito) e abrir PR.
2. **Rodar o `alter table` do schema.sql** no Supabase do Rodrigo (banco já
   existente, só precisa das 2 colunas novas).
3. **Criar a credencial `BlackCat`** no n8n: Header Auth, Name `X-API-Key`,
   Value = chave real (sem prefixo `Bearer`).
4. **Reimportar os 6 workflows atualizados** no n8n (PikaPods) e criar as
   credenciais nativas (nomes exatos na tabela do
   `30-integracoes/n8n/workflows/README.md`).
5. **Testar os nodes Supabase isoladamente** antes do fluxo completo: Pin
   Data no trigger + "Test step" node a node (evita disparar OpenAI/WhatsApp/
   BlackCat sem querer).
6. **Testar o fluxo de coleta de email/CPF de ponta a ponta** com uma venda
   de teste real no BlackCat (confirma que o `customer` no formato certo é
   de fato aceito e o `invoiceUrl` volta certinho).
7. **Confirmar o handshake do webhook BlackCat** (`/webhook/blackcat`) com
   um evento de teste real (`transaction.created`/`paid`/`failed`).
8. **Placeholders que ainda faltam** (dependem do WhatsApp/Meta, pausado):
   `<<WHATSAPP_PHONE_NUMBER_ID>>`, `<<WHATSAPP_TEMPLATE_NAME>>`,
   `<<RODRIGO_WA_NUMBER>>`.

## Padrões relevantes (para manter consistência)

- **Camadas do repo**: `00-nucleo/` (system prompt sempre ativo) →
  `10-skills/` (consultado sob demanda) → `20-memoria/` (schemas de
  dado) → `30-integracoes/` (ferramentas reais — n8n, Supabase, BlackCat,
  WhatsApp, Hermes).
- **`compliance-e-etica.md` é fonte única** de regras de conduta — precisa
  estar carregado no system prompt de cada conversa (Gatilho 1, node
  "Montar mensagens OpenAI"); nunca duplicar essas regras em outro arquivo,
  só referenciar.
- **Nada no Hermes vira comportamento ativo sem aprovação humana explícita**
  (`decidido_por`) — inclusive sugestões de risco alto, que também vão pra
  fila em vez de serem descartadas.
- **Desconto sempre aplicado de verdade no valor cobrado**, nunca só
  narrado na conversa (ver `Montar items do carrinho` em
  `agente-vendas.json`).
- **Segredos (chaves de API) vivem só como Credentials nativas do n8n** —
  nunca em env var (PikaPods não suporta `$env` customizado) nem em texto
  no JSON exportado. Config não-secreta (URLs, IDs) pode ser texto literal.
- **Convenção de layout dos nodes n8n**: ver
  `30-integracoes/n8n/workflows/README.md`, seção "Convenção de layout".
- **Dados de pagamento (email/CPF) são coletados na conversa, não no
  checkout**: decisão revertida nesta sessão porque a API do BlackCat exige
  `customer` completo já no `create-sale`. Não reabrir essa discussão sem
  reconfirmar a doc oficial.
- **Sobre branches**: sempre `git fetch origin main` + checar se a branch de
  trabalho já foi mergeada antes de continuar commitando nela — se foi,
  restartar a branch a partir de `origin/main`.

## Arquivos tocados nesta sessão

- `HANDOFF.md` (este arquivo)
- `30-integracoes/n8n/workflows/agente-vendas.json` (prompt do agente +
  node `Criar venda BlackCat` + novo node `Salvar dados de pagamento do
  lead`)
- `30-integracoes/n8n/workflows/workflow-completo.json` (idem)
- `30-integracoes/n8n/workflows/README.md` (pendência do `customer`
  marcada como resolvida)
- `30-integracoes/supabase/schema.sql` (colunas `leads.email`/`leads.cpf`)
