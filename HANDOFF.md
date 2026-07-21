# Handoff — 2026-07-21

Nota de transição de sessão (contexto ficou muito longo). Objetivo: a próxima
sessão retomar sem precisar reconstruir o histórico.

## Estado atual

- **`main`** está atualizado até o PR #13 (merge `9169b86`), que trouxe:
  catálogo real de produtos populado, correção do bug de desconto anunciado
  vs. desconto realmente cobrado, migração de `$env.*` para Credentials
  nativas do n8n (o PikaPods não aceita env var customizada), e as URLs do
  Supabase/pod n8n preenchidas nos workflows (antes eram placeholders
  `<<SUPABASE_URL>>` / `<<N8N_BASE_URL>>`).
- O ciclo de aprendizado do Hermes (filtro de conformidade) **já** foi migrado
  de "descarta sozinho" para "classifica risco e encaminha tudo pra fila
  humana" — isso está mergeado em `main` desde o PR #2 (commit `10fc4f5`).
  Não há trabalho pendente nessa frente.
- **Branch `claude/catalogo-produtos-reais`** tem 1 commit ainda não
  mergeado (`Corrige integração BlackCat com base na doc oficial + registra
  convenção de layout`), rebaseado sobre o `main` atual. Ainda sem PR aberto.
  Esse commit:
  - Corrige `agente-vendas.json` / `pagamento-blackcat.json` /
    `workflow-completo.json`: o endpoint do BlackCat estava com domínio
    errado (`api.blackcathub.com` em vez de `api.blackcatoficial.com`),
    autenticação errada (`Authorization: Bearer` em vez de header
    `X-API-Key`), e nomes de campo incorretos na resposta do `create-sale`
    e no webhook de retorno (`id`/`paymentUrl`/`externalRef` em vez de
    `data.transactionId`/`data.invoiceUrl`/`externalReference`). Tudo
    confirmado em docs.blackcatoficial.com (fetch feito nesta sessão).
  - Adiciona `amount` (total em centavos) e `paymentMethod: 'pix'` ao corpo
    da requisição — a API exige os dois e antes só os `items` eram enviados.
  - Atualiza o README de `30-integracoes/n8n/workflows/` com a credencial
    do BlackCat corrigida e uma nova seção de **convenção de layout** dos
    nodes (ver "Padrões relevantes" abaixo).
  - Todos os 6 JSON (5 individuais + completo) validados: sintaxe ok, sem nó
    órfão, sem ID/nome duplicado.

## Decisões tomadas nesta sessão

1. **Placeholders preenchidos**: `<<SUPABASE_URL>>` →
   `https://rmvmqmcfcjmcjtonewgi.supabase.co`, `<<N8N_BASE_URL>>` →
   `https://salles-ai-agent.pikapod.net`. Já em `main`.
2. **BlackCat — dados de autenticação/endpoint/resposta**: confirmados via
   documentação oficial (não eram mais suposição). Rodrigo já tem acesso à
   conta e à API key do BlackCat.
3. **Fluxo de coleta de dados do comprador (decisão do Rodrigo, ainda não
   implementada em código)**:
   - **Antes do checkout** (na conversa via WhatsApp): o agente coleta
     **só nome + telefone (wa_id)** — é exatamente o que o funil já faz
     hoje, nada muda aqui.
   - **email + CPF + endereço**: são coletados **depois**, na própria
     página de checkout hospedada pelo BlackCat (`invoiceUrl`) — **não**
     pelo agente na conversa.
   - **Risco técnico em aberto**: a documentação do BlackCat lista
     `customer.email` e `customer.document` (CPF) como obrigatórios no
     corpo do `create-sale`, sem mencionar um modo de "dados mínimos +
     completar no checkout". O node `Criar venda BlackCat` **ainda não
     envia** o objeto `customer` (ver TODO bloqueante no próprio node e no
     README). Precisa validar na prática antes de ativar em produção —
     ver Próximos passos, item 1.
4. **Convenção de layout dos nodes n8n** documentada no README (trilha
   principal em `y=0` avançando 220px em `x`; ramos paralelos se afastam em
   ±80px de `y` a partir de onde nascem; nomes de node em português
   descrevendo a ação, não o tipo técnico).

## Próximos passos (ordem sugerida)

1. **Validar o fluxo de customer.email/document com o BlackCat de verdade**:
   criar uma venda de teste via API **sem** `customer.email`/`document` e
   ver se a API aceita (deixando o checkout hospedado completar) ou rejeita.
   Se rejeitar, decidir entre (a) enviar algum dado mínimo aceito pela API e
   deixar o checkout corrigir/completar, ou (b) outra abordagem — e então
   atualizar o node `Criar venda BlackCat` (`agente-vendas.json` +
   `workflow-completo.json`) de acordo.
2. **Criar a credencial `BlackCat`** no n8n: Header Auth, Name `X-API-Key`,
   Value = chave real (sem prefixo `Bearer`).
3. **Reimportar os 6 workflows atualizados** no n8n (PikaPods) e criar as 4
   credenciais nativas (nomes exatos na tabela do
   `30-integracoes/n8n/workflows/README.md`).
4. **Testar os nodes Supabase isoladamente** antes do fluxo completo: Pin
   Data no trigger + "Test step" node a node (evita disparar OpenAI/WhatsApp/
   BlackCat sem querer).
5. **Confirmar o handshake do webhook BlackCat** (`/webhook/blackcat`) com
   um evento de teste real (`transaction.created`/`paid`/`failed`).
6. **Placeholders que ainda faltam** (dependem do WhatsApp/Meta, pausado):
   `<<WHATSAPP_PHONE_NUMBER_ID>>`, `<<WHATSAPP_TEMPLATE_NAME>>`,
   `<<RODRIGO_WA_NUMBER>>`.
7. **Abrir PR** para o commit de correção do BlackCat (branch
   `claude/catalogo-produtos-reais`) depois de resolver o item 1 — ou antes,
   se o Rodrigo preferir revisar o texto/código já e só testar depois.

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
- **Sobre branches**: o PR original desta linha de trabalho apontava para
  `claude/estruturar-agente-ia-29la6r`, mas o trabalho real acabou seguindo
  em `claude/catalogo-produtos-reais` (branch do PR #13, já mergeada em
  `main`). Ao retomar, sempre `git fetch origin main` + checar se a branch
  de trabalho já foi mergeada antes de continuar commitando nela — se foi,
  rebasear os commits não mergeados sobre `origin/main` (feito nesta sessão
  para o commit de correção do BlackCat).

## Arquivos tocados nesta sessão

- `30-integracoes/n8n/workflows/README.md`
- `30-integracoes/n8n/workflows/agente-vendas.json`
- `30-integracoes/n8n/workflows/pagamento-blackcat.json`
- `30-integracoes/n8n/workflows/workflow-completo.json`
- `30-integracoes/n8n/workflows/fila-notificar.json` (só placeholder)
- `30-integracoes/n8n/workflows/fila-decidir.json` (só placeholder)
- `30-integracoes/n8n/workflows/followup-24h.json` (só placeholder)
