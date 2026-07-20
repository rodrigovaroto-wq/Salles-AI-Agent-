# Workflows do n8n — Esqueleto Pronto para Importar

## `workflow-completo.json` — a operação inteira num arquivo só

Os 5 gatilhos consolidados numa única importação: **5 triggers de entrada**
(2 webhooks de mensagem, 1 webhook de decisão, 2 crons) coexistindo no mesmo
workflow, cada um puxando sua própria cadeia de nós — 53 nós ao todo,
validado (sem nó órfão, sem ID/nome duplicado).

**Por que os 5 "ramos" não têm conexão entre si dentro do arquivo:** eles não
se conectam por *nó do n8n* porque, no sistema real, eles não deveriam — quem
liga um gatilho ao outro é uma chamada HTTP **externa** que já existe no
desenho:
- `agente-vendas` → `pagamento-blackcat`: liga via `postbackUrl` do BlackCat
  (uma chamada de fora pra dentro do n8n, não uma aresta interna).
- `fila-notificar` → `fila-decidir`: liga via o link que você clica no
  WhatsApp (mesma lógica — é o BlackCat/WhatsApp quem "conecta", não o n8n).

Ou seja: já estão conectados onde deveriam estar — a ausência de aresta
interna entre os ramos é o desenho correto, não uma lacuna.

Os 5 arquivos individuais (abaixo) continuam existindo — úteis para importar/
testar um gatilho isolado sem carregar o resto. O `workflow-completo.json` é
a soma exata deles (mesmos nós, mesmas conexões, só com IDs prefixados para
não colidir e posições deslocadas para não sobrepor no canvas).

## Como importar
No n8n: `Workflows` → `Import from File` → selecione o `.json` (o completo, ou
um dos 5 individuais). Chegam **inativos** (`active: false`) de propósito —
ative só depois de configurar as env vars e revisar a lógica.

## Variáveis de ambiente necessárias

| Variável | De onde vem | Usada em |
|---|---|---|
| `SUPABASE_URL` | `../../supabase/README.md` | todos |
| `SUPABASE_SERVICE_KEY` | `../../supabase/README.md` | todos |
| `OPENAI_API_KEY` | conta OpenAI | agente-vendas |
| `WHATSAPP_TOKEN` | `../../whatsapp/README.md` (token permanente) | agente-vendas, pagamento-blackcat, followup-24h, fila-notificar |
| `WHATSAPP_PHONE_NUMBER_ID` | `../../whatsapp/README.md` | idem |
| `WHATSAPP_TEMPLATE_NAME` | nome do template aprovado pela Meta | followup-24h |
| `BLACKCAT_API_KEY` | painel BlackCat | agente-vendas |
| `N8N_BASE_URL` | URL pública do pod (ex. `https://SEUPOD.pikapods.com`) | agente-vendas (postbackUrl), fila-notificar (link de decisão) |
| `RODRIGO_WA_NUMBER` | seu próprio número, para receber o digest | fila-notificar |

No PikaPods: `Pod` → `Environment` → adicionar cada uma. Reinicie o pod após
adicionar.

## Os 5 gatilhos (arquivos individuais == ramos do `workflow-completo.json`)

| Arquivo | Gatilho | O que faz |
|---|---|---|
| `agente-vendas.json` | 1 | Recebe mensagem → busca lead/histórico/prompt ativo (Merge) → chama OpenAI (saída em JSON estruturado: `resposta` + `intent`) → envia WhatsApp → grava evento → se `intent=gerar_link`, monta carrinho e cria venda no BlackCat |
| `pagamento-blackcat.json` | 2 e 3 | Recebe webhook do BlackCat → roteia por `event` (cadeia de IFs) → `paid`: marca cliente e confirma → `created`: marca abandonado, **espera 2h** (node `Wait`, sobrevive a reinício do pod) e reabre se ainda abandonado → `failed`: libera para follow-up |
| `followup-24h.json` | 4 | A cada hora, busca leads sem compra há >24h, separa em itens e envia o template aprovado |
| `fila-notificar.json` | ciclo Hermes | Todo dia às 8h, busca sugestões pendentes (risco alto primeiro) e manda um resumo com links de aprovar/rejeitar para você no WhatsApp |
| `fila-decidir.json` | ciclo Hermes | Recebe o clique do link → registra a decisão → se aprovada, **aplica sozinho**: desativa a versão antiga em `prompt_ativo` e insere a nova (rollback fica preservado, nada é apagado) |

## O que ainda depende de dado real (marcado `TODO` no código)

- **`agente-vendas.json` → "Montar items do carrinho":** o mapeamento
  `produto_id → preço/nome` está vazio — depende dos preços reais do
  `../../catalogo-produtos.md` (pendente com os sócios). A fórmula de
  desconto (10% por item adicional) já está pronta.
- **`agente-vendas.json` → "Criar venda BlackCat":** confirmar o header de
  autenticação exato na documentação oficial do BlackCat antes de ativar em
  produção (usei `Authorization: Bearer`, mais comum, mas não 100% confirmado
  pela doc consultada).
- **`fila-decidir.json` → "Derivar chave do prompt":** heurística simples por
  nome de arquivo (`objetivo.md` → chave `objetivo`, `compliance-e-etica.md` →
  `compliance`, resto → `skill:<arquivo>`). Ajustar se o mapeamento crescer.

## Notas de arquitetura (por que ficou assim)

- **Sem `IF` de "lead existe?":** `agente-vendas` usa **upsert** no Supabase
  (`Prefer: resolution=merge-duplicates`) em vez de checar e ramificar — mais
  simples e sem duplicar lógica.
- **`Merge contexto` é obrigatório:** junta os dois branches (histórico +
  prompt ativo) antes de montar a mensagem para a OpenAI. Sem essa barreira de
  sincronização, o node seguinte rodaria 2x e duplicaria a chamada à IA e o
  envio no WhatsApp.
- **Saída da OpenAI em JSON estruturado:** o agente responde sempre
  `{resposta, intent, produtos_aceitos}` — isso permite o n8n ramificar por
  `intent` sem tentar interpretar linguagem natural com regex.
- **Arrays do Supabase não são explodidos automaticamente:** o HTTP Request
  do n8n mantém um array de resposta como um único item por padrão. Em
  `followup-24h`, um node `Code` separa explicitamente em N itens antes de
  processar por lead.
