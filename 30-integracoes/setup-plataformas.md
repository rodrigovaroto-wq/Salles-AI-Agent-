# Setup das Plataformas — Configuração e Integração

Guia de montagem do sistema completo. Ordem pensada para cada peça já encontrar
a anterior pronta. Supabase e n8n vão em ritmo rápido (você domina); o detalhe
fica no que conecta tudo.

---

## 0. O que precisa de hospedagem (e o que não precisa)

| Peça | Hospedagem |
|---|---|
| **n8n** (orquestrador) | Precisa hospedar → **PikaPods** |
| **Hermes** (análise) | Precisa hospedar → **VPS própria** (PikaPods não roda) |
| Supabase | SaaS — sem VPS |
| WhatsApp Cloud API | Hospedado pela Meta — sem VPS |
| BlackCat | SaaS — sem VPS |
| OpenAI | SaaS — sem VPS |

Ou seja: só **n8n** e **Hermes** precisam de servidor.

---

## 1. Decisão de hospedagem

O PikaPods roda apenas apps do catálogo dele (tem n8n; **não** aceita Docker
customizado, então **não roda o Hermes**).

**Recomendação:**
- **n8n → PikaPods** (catálogo, 1 clique, SSL/backup gerenciados) — seu terreno conhecido.
- **Hermes → 1 VPS pequena com Docker** — a "caixa do que o PikaPods não roda".
  Como o Hermes só faz análise diária, uma VPS de entrada sobra.

Sugestões de VPS (qualquer uma serve; ~4 GB RAM basta):
| VPS | Perfil |
|---|---|
| **Hetzner CX22** (~€4/mês) | Melhor custo/desempenho global |
| **Hostinger VPS KVM** (~US$5/mês) | Painel fácil, suporte PT-BR, cobrança BR |
| **Contabo** | Barato, bastante RAM, suporte mais lento |

**Alternativa (uma caixa só):** se preferir tudo num lugar, uma VPS Hetzner/
Hostinger com Docker roda **n8n + Hermes juntos** — abre mão do PikaPods, mas
centraliza numa conta. Recomendo manter o n8n no PikaPods e o Hermes numa VPS
à parte: o n8n é o caminho do dinheiro (tempo real), e no PikaPods ele vem com
backup/SSL sem você cuidar.

---

## 2. Contas e credenciais a preparar (checklist)

- [ ] **Meta Business** verificado + **WhatsApp Business Account (WABA)** + número
- [ ] **OpenAI** — API key (a mesma serve para o agente e para o Hermes)
- [ ] **BlackCat** — API key + definir a `postbackUrl`
- [ ] **Supabase** — projeto criado
- [ ] **PikaPods** — conta (para o n8n)
- [ ] **VPS** — conta (para o Hermes)

Regra de segurança: todas as chaves entram como **variáveis de ambiente /
credenciais** no n8n e na VPS. **Nunca** commitar segredo no repositório.

---

## 3. Passo a passo (ordem de montagem)

### 3.1 Supabase (rápido)
Crie o projeto e as tabelas a partir dos schemas já definidos:
- `leads` → `../20-memoria/schema-lead.md`
- `conversas` → `../20-memoria/schema-conversa.md`
- `aprendizado` (métricas) → `../20-memoria/schema-aprendizado.md`
- `fila_sugestoes` → `hermes/fila-aprovacao.md`
- `prompt_ativo` (versionada) → `hermes/configuracao.md` (campos: `versao`,
  `conteudo`, `aplicado_em`)

Guarde a `URL` do projeto e a `service_role key` (para o n8n e o Hermes lerem/
escreverem).

### 3.2 n8n no PikaPods (rápido)
1. PikaPods → catálogo → **n8n** → Deploy. Anote a URL.
2. Em Environment, configure as credenciais como env vars: OpenAI, BlackCat,
   Supabase, WhatsApp token.
3. Deixe o n8n pronto para receber webhooks (URL pública já vem com SSL).

### 3.3 WhatsApp Cloud API
1. Meta Business → adicionar produto **WhatsApp** → criar a **WABA** e registrar
   o número (não pode estar ativo no WhatsApp comum).
2. Gere um **token permanente** (System User token) — não use o token temporário.
3. **Webhook de entrada:** aponte o webhook da WABA para a URL de webhook do n8n
   (Gatilho 1). Assine o campo `messages`.
4. **Envio:** o n8n envia via `POST /{phone-number-id}/messages` com o token.
5. **Template de follow-up (>24h):** crie e submeta à aprovação da Meta um
   template "limpo" (ver restrições em `../00-nucleo/compliance-e-etica.md`).
6. **Links `wa.me`:** a LP (Meta) e o criativo do TikTok usam
   `https://wa.me/<numero>?text=...` com um marcador de origem (`lp` / `tiktok`)
   no texto, para o Gatilho 1 identificar o caminho.

### 3.4 BlackCat
1. Painel BlackCat → gere a **API key**.
2. Configure a **`postbackUrl`** apontando para o webhook de pagamento do n8n
   (Gatilhos 2 e 3).
3. Na criação de venda (`create-sale`), o n8n envia `externalRef = wa_id`,
   `items[]`, `metadata` e UTMs (ver `blackcat/criacao-transacao.md`).
4. Assine os eventos `transaction.created`, `transaction.paid`,
   `transaction.failed`.

### 3.5 OpenAI
API key como credencial no n8n (nó da OpenAI) e também no Hermes (seção 3.6).

### 3.6 Hermes na VPS
1. Suba a VPS (Docker instalado).
2. Instale o Hermes (`github.com/NousResearch/hermes-agent`) via Docker.
3. Configure:
   - **LLM:** OpenAI (endpoint compatível), mesma API key.
   - **Leitura Supabase:** credenciais para ler `conversas`/`aprendizado`.
   - **Escrita:** só na tabela `fila_sugestoes`.
4. **Disparo diário:** um cron (no n8n ou no próprio Hermes) roda a análise 1x/dia,
   com o gate de **≥ 25 conversas novas** (ver `hermes/configuracao.md`).

### 3.7 Loop de aprovação no n8n
1. Um workflow no n8n lista a `fila_sugestoes` com `status = pendente`
   (risco alto no topo).
2. Você aprova/rejeita (botão / mensagem).
3. Ao **aprovar**, o n8n grava a `mudanca_proposta` como **nova versão** em
   `prompt_ativo` e marca a sugestão como `aprovada` — a versão anterior fica
   guardada para reverter.
4. O agente de vendas (Gatilho 1) sempre lê a versão vigente de `prompt_ativo`
   + `../00-nucleo/compliance-e-etica.md` (sempre carregado).

---

## 4. Ordem de teste ponta a ponta

Teste cada salto isolado antes de ligar tudo:
1. Manda mensagem no WhatsApp → chega webhook no n8n? (Gatilho 1)
2. n8n → OpenAI → resposta volta no WhatsApp?
3. n8n grava/lê lead no Supabase?
4. `create-sale` BlackCat gera link com `externalRef`?
5. Pagamento de teste → `transaction.paid` chega no n8n e marca cliente?
6. Abandono → timer 2h → recuperação dispara?
7. Hermes roda, gera sugestão na `fila_sugestoes`?
8. Aprovar no n8n → `prompt_ativo` ganha nova versão?

---

## Relacionado
- [`workflow-lead-a-cliente.md`](workflow-lead-a-cliente.md) — os gatilhos que este setup materializa
- [`blackcat/`](blackcat/) — detalhes da integração de pagamento
- [`hermes/configuracao.md`](hermes/configuracao.md) — a camada de análise
- [`../00-nucleo/compliance-e-etica.md`](../00-nucleo/compliance-e-etica.md) — sempre carregado no agente
