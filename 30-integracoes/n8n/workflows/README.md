# Workflows do n8n — Esqueleto Pronto para Importar

## `workflow-completo.json` — a operação inteira num arquivo só

Os 5 gatilhos consolidados numa única importação: **5 triggers de entrada**
(2 webhooks de mensagem, 1 webhook de decisão, 2 crons) coexistindo no mesmo
workflow, cada um puxando sua própria cadeia de nós — 59 nós ao todo,
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
| `agente-vendas.json` | 1 | Recebe mensagem → busca lead/histórico/prompt ativo/**catálogo de produtos** (2 Merges) → chama OpenAI já informado dos produtos, preços e tags de **pivô por objeção/arquétipo** (saída em JSON estruturado: `resposta` + `intent` + `arquetipo`) → envia WhatsApp → grava evento → **detecta e grava o arquétipo do lead** (se houver sinal real) → se `intent=gerar_link`, monta carrinho com preço **real do Supabase** e desconto **efetivamente aplicado**, cria venda no BlackCat, e grava o desconto/link de volta no evento |
| `pagamento-blackcat.json` | 2 e 3 | Recebe webhook do BlackCat → roteia por `event` (cadeia de IFs) → `paid`: marca cliente e confirma → `created`: marca abandonado, **espera 2h** (node `Wait`, sobrevive a reinício do pod) e reabre se ainda abandonado → `failed`: libera para follow-up |
| `followup-24h.json` | 4 | A cada hora, busca leads sem compra há >24h, separa em itens e envia o template aprovado |
| `fila-notificar.json` | ciclo Hermes | Todo dia às 8h, busca sugestões pendentes (risco alto primeiro) e manda um resumo com links de aprovar/rejeitar para você no WhatsApp |
| `fila-decidir.json` | ciclo Hermes | Recebe o clique do link → registra a decisão → se aprovada, **aplica sozinho**: desativa a versão antiga em `prompt_ativo` e insere a nova (rollback fica preservado, nada é apagado) |

## O que ainda depende de confirmação (marcado `TODO` no código)

- **`agente-vendas.json` → "Criar venda BlackCat" e "Enviar link WhatsApp":**
  confirmar na documentação oficial do BlackCat o header de autenticação
  exato (usei `Authorization: Bearer`) e o nome exato dos campos de retorno
  do `create-sale` (usei `id` e `paymentUrl`, suposição razoável mas não
  100% confirmada) antes de ativar em produção.
- **`fila-decidir.json` → "Derivar chave do prompt":** heurística simples por
  nome de arquivo (`objetivo.md` → chave `objetivo`, `compliance-e-etica.md` →
  `compliance`, resto → `skill:<arquivo>`). Ajustar se o mapeamento crescer.

**Resolvido:** os preços reais do catálogo (Oração Sagrada R$22,90 + 3 order
bumps) já estão populados na tabela `produtos` do Supabase
(`../../supabase/schema.sql`) e no `../../catalogo-produtos.md`. O node
"Montar items do carrinho" lê de lá — nada mais hardcoded.

## Notas de arquitetura (por que ficou assim)

- **Sem `IF` de "lead existe?":** `agente-vendas` usa **upsert** no Supabase
  (`Prefer: resolution=merge-duplicates`) em vez de checar e ramificar — mais
  simples e sem duplicar lógica.
- **`Merge contexto` + `Merge contexto 2` são obrigatórios:** o Merge só
  combina 2 branches por vez, e agora são 3 buscas em paralelo (histórico +
  prompt ativo + produtos) — por isso são dois Merges encadeados, não um só.
  Sem essa barreira de sincronização, o node seguinte rodaria mais de uma vez
  e duplicaria a chamada à IA e o envio no WhatsApp.
- **Saída da OpenAI em JSON estruturado:** o agente responde sempre
  `{resposta, intent, produtos_aceitos}` — isso permite o n8n ramificar por
  `intent` sem tentar interpretar linguagem natural com regex. O prompt do
  sistema agora inclui o catálogo real (produto_id, nome, preço), então o
  modelo só pode citar produtos que de fato existem.
- **O desconto é aplicado no preço, não só calculado:** "Montar items do
  carrinho" multiplica o `unitPrice` de cada item pelo fator de desconto
  antes de montar o `items[]` do BlackCat — o valor cobrado já reflete o
  desconto anunciado (exigência do `compliance-e-etica.md`), em vez de só
  registrar um `descontoPct` que nunca era usado.
- **A tabela de economia mostrada ao lead é calculada em código, não pelo
  modelo:** "Montar mensagens OpenAI" monta um texto pronto (quanto cai o
  total e quanto se economiza a cada order bump) usando a **mesma fórmula
  exata** de "Montar items do carrinho", e instrui o modelo a usá-lo
  verbatim. Isso garante que o número que o lead vê bate com o que será
  cobrado — deixar a IA calcular/narrar isso livremente seria arriscar uma
  divergência entre o que é dito e o que é cobrado. Exemplo verificado em
  `../../catalogo-produtos.md`, seção 6.
- **Arrays do Supabase não são explodidos automaticamente:** o HTTP Request
  do n8n mantém um array de resposta como um único item por padrão. Em
  `followup-24h`, um node `Code` separa explicitamente em N itens antes de
  processar por lead.
- **Pivô por objeção e arquétipo são runtime, não só documentação:** as
  colunas `resolve_objecao` e `arquetipos` da tabela `produtos` (Supabase)
  são injetadas no system prompt, e o modelo é instruído a usá-las para
  oferecer a alternativa certa numa objeção forte e priorizar o order bump
  certo por perfil (ver `../../catalogo-produtos.md`, seções 3 e 4).
- **Arquétipo do lead nunca é sobrescrito com "nada detectado":** o IF
  "Arquetipo detectado?" só dispara a gravação em `leads.arquetipo` quando o
  modelo retorna um valor não vazio — evita apagar um arquétipo já
  identificado numa mensagem anterior só porque a mensagem atual não deu
  sinal novo.
