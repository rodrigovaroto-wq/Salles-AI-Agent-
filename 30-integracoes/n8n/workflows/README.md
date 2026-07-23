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
ative só depois de configurar as credenciais (abaixo) e revisar a lógica.

## ⚠️ Mudança de arquitetura: o PikaPods não aceita env var customizada

A versão anterior deste guia assumia variáveis de ambiente livres (`$env.X`)
configuráveis no pod. **Isso não existe no PikaPods** — o painel só expõe uma
lista fixa de configurações do próprio n8n (timezone, log level, tamanho de
payload etc.), nenhuma delas serve para guardar segredo nosso. Além disso,
`N8N_BLOCK_ENV_ACCESS_IN_NODE` vem `true` por padrão, bloqueando `$env` dentro
de nodes mesmo que existisse a variável. Os workflows foram reescritos para
não depender disso.

### Segredos → Credenciais nativas do n8n

Segredos de verdade (chaves de API) agora usam o sistema de **Credentials**
do n8n (`Settings` → `Credentials` → `Add Credential`), criptografado pelo
próprio `N8N_ENCRYPTION_KEY` do pod — não aparecem no JSON exportado.

| Credencial a criar | Tipo | Nome exato (usado nos nodes) | Campos |
|---|---|---|---|
| Supabase | **Custom Auth** | `Supabase (apikey+auth)` | JSON: `{"header": {"apikey": "<service_role key>", "Authorization": "Bearer <service_role key>"}}` |
| OpenAI | **Header Auth** | `OpenAI` | Name: `Authorization` · Value: `Bearer <sua OPENAI_API_KEY>` |
| WhatsApp Cloud API | **Header Auth** | `WhatsApp Cloud API` | Name: `Authorization` · Value: `Bearer <token permanente>` |
| BlackCat | **Header Auth** | `BlackCat` | Name: `X-API-Key` · Value: `<BLACKCAT_API_KEY>` (sem `Bearer`, confirmado na doc oficial) |
| GitHub API | **Header Auth** | `GitHub API` | Name: `Authorization` · Value: `Bearer <PAT>` — Fine-grained Personal Access Token limitado a este repositório (`rodrigovaroto-wq/Salles-AI-Agent-`), permissão **Contents: Read and write**. Usado só em `fila-decidir.json` (nodes "Buscar SHA do arquivo no GitHub" / "Commitar mudanca no GitHub"), para espelhar sugestões aprovadas do Hermes de volta pro git (ver `../../hermes/configuracao.md`). |

**O nome da credencial precisa bater exatamente** com a coluna acima — é por
esse nome que cada node te pede pra selecionar a credencial certa depois do
import (o `id` não viaja entre instâncias de n8n, isso é esperado; só o nome
ajuda a achar a certa no dropdown).

Depois de criar as 5 credenciais, abra cada node que usa HTTP Request neste
workflow e confirme no campo **Authentication** se a credencial certa está
selecionada (o import geralmente já reconhece pelo nome, mas vale conferir).

### Config não-secreta → valores literais no texto

Valores que não são segredo (URL do projeto, ID de telefone, nome de
template) também não têm onde morar como env var no PikaPods. Por isso
entram como **texto literal** nos arquivos — não é sintaxe de expressão do
n8n, é o valor puro mesmo:

| Valor | Onde consta | Usado em |
|---|---|---|
| `https://rmvmqmcfcjmcjtonewgi.supabase.co` (URL do Supabase) | preenchido | todos os nodes que chamam Supabase |
| `https://salles-ai-agent.pikapod.net` (URL do pod n8n) | preenchido | `agente-vendas` (postbackUrl do BlackCat), `fila-notificar` (link de decisão) |
| `<<WHATSAPP_PHONE_NUMBER_ID>>` | `../../whatsapp/README.md` — só existe depois da verificação Meta | `agente-vendas`, `pagamento-blackcat`, `followup-24h`, `fila-notificar` |
| `<<WHATSAPP_TEMPLATE_NAME>>` | Nome do template aprovado pela Meta | `followup-24h` |
| `<<RODRIGO_WA_NUMBER>>` | Seu número, para receber o digest do Hermes | `fila-notificar` |

**Os 3 placeholders que restam** (`<<WHATSAPP_PHONE_NUMBER_ID>>`,
`<<WHATSAPP_TEMPLATE_NAME>>`, `<<RODRIGO_WA_NUMBER>>`) dependem do
WhatsApp/BlackCat, que estão pausados. Quando tiver os valores, me passe
aqui (não é segredo — URLs, IDs de telefone e nome de template podem vir no
chat sem problema; o que **não** deve vir aqui é a `service_role key` ou
qualquer chave/token) e eu troco em todos os arquivos de uma vez, mantendo a
validação de integridade.

## Os 5 gatilhos (arquivos individuais == ramos do `workflow-completo.json`)

| Arquivo | Gatilho | O que faz |
|---|---|---|
| `agente-vendas.json` | 1 | Recebe mensagem → busca lead/histórico/prompt ativo/**catálogo de produtos** (2 Merges) → chama OpenAI já informado dos produtos, preços e tags de **pivô por objeção/arquétipo** (saída em JSON estruturado: `resposta` + `intent` + `arquetipo`) → envia WhatsApp → grava evento → **detecta e grava o arquétipo do lead** (se houver sinal real) → se `intent=gerar_link`, monta carrinho com preço **real do Supabase** e desconto **efetivamente aplicado**, cria venda no BlackCat, e grava o desconto/link de volta no evento |
| `pagamento-blackcat.json` | 2 e 3 | Recebe webhook do BlackCat → roteia por `event` (cadeia de IFs) → `paid`: marca cliente e confirma → `created`: marca abandonado, **espera 2h** (node `Wait`, sobrevive a reinício do pod) e reabre se ainda abandonado → `failed`: libera para follow-up |
| `followup-24h.json` | 4 | A cada hora, busca leads sem compra há >24h, separa em itens e envia o template aprovado |
| `fila-notificar.json` | ciclo Hermes | Todo dia às 8h, busca sugestões pendentes (risco alto primeiro) e manda um resumo com links de aprovar/rejeitar para você no WhatsApp |
| `fila-decidir.json` | ciclo Hermes | Recebe o clique do link → registra a decisão → se aprovada, **aplica sozinho**: desativa a versão antiga em `prompt_ativo`, insere a nova (rollback fica preservado, nada é apagado) e **espelha a mudança no git** (commit direto no arquivo `.md` correspondente via API do GitHub) |

## O que ainda depende de confirmação (marcado `TODO` no código)

- **Credencial "Supabase (apikey+auth)" (Custom Auth):** o tipo de credencial
  e a existência do formato "múltiplos headers num JSON" foram confirmados
  via documentação/comunidade oficial do n8n (Custom Auth é feito exatamente
  para o caso apikey+Authorization do Supabase), mas **não testei contra uma
  instância real**. Se o campo JSON não aceitar o formato
  `{"header": {...}}` como descrito acima, abra a credencial no n8n e
  confira o rótulo exato dos campos — o mecanismo (JSON com headers) é
  documentado, só o nome interno da chave (`header` vs. `headers`) pode
  variar por versão.
- **`fila-decidir.json` → "Derivar chave do prompt":** heurística simples por
  nome de arquivo (`objetivo.md` → chave `objetivo`, `compliance-e-etica.md` →
  `compliance`, resto → `skill:<arquivo>`). Ajustar se o mapeamento crescer.
- **`agente-vendas.json` → "Criar venda BlackCat" (resolvido):** a API do
  BlackCat exige `customer` no corpo da requisição (`name`, `email`, `phone`,
  `document{number,type}`) — e o link só é gerado se isso já vier completo,
  não dá pra completar depois na página de checkout. Por isso o agente
  **pede e-mail e CPF na própria conversa do WhatsApp**, assim que o lead
  aceita o stack e antes de gerar o link (ver "Montar mensagens OpenAI"):
  o modelo só retorna `intent=gerar_link` quando já tiver os dois. Os dois
  também são gravados em `leads.email`/`leads.cpf` (node "Salvar dados de
  pagamento do lead") assim que confirmados, e o `cpf` vai sempre
  digits-only (mesmo formato exigido pelo BlackCat).

**Resolvido:** os preços reais do catálogo (Oração Sagrada R$22,90 + 3 order
bumps) já estão populados na tabela `produtos` do Supabase
(`../../supabase/schema.sql`) e no `../../catalogo-produtos.md`. O node
"Montar items do carrinho" lê de lá — nada mais hardcoded. Os campos do
BlackCat (endpoint, header de autenticação, nomes de retorno do
`create-sale` e do webhook) foram confirmados na documentação oficial
(docs.blackcatoficial.com) em 2026-07-21: endpoint correto é
`api.blackcatoficial.com` (não `blackcathub.com`), autenticação é
`X-API-Key` (não `Authorization: Bearer`), a resposta do `create-sale` vem
aninhada em `data.transactionId`/`data.invoiceUrl`, e o webhook de retorno
usa `externalReference` (não `externalRef`) e `transactionId` (não `id`).

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
- **Dois mecanismos de desconto, nunca misturados:** o desconto de *stack*
  (10%/20%/30%, cresce com o carrinho) e o desconto de *recuperação* do
  pivô por objeção (20% fixo, ver `../../catalogo-produtos.md` seção 3) são
  calculados por caminhos separados em "Montar items do carrinho",
  selecionados pelo flag `pivo_downsell` que o modelo retorna. O modelo
  nunca inventa o percentual em nenhum dos dois casos.
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

## Convenção de layout (para novos workflows)

Padrão usado em todos os arquivos deste diretório — seguir nos próximos:

- **Trilha principal em `y=0`**, avançando em `x` de **220px por node**
  (`[0,0]`, `[220,0]`, `[440,0]`, ...).
- **Ramos paralelos** (saídas de um `IF`/`Switch`, ou buscas que rodam ao
  mesmo tempo antes de um `Merge`) se afastam da trilha principal em
  incrementos de **±80px em `y`** por ramo (`-80`, `80`, `160`, `240`...),
  mantendo o mesmo `x` de quem os originou.
  quando um `Merge` só recombina 2 branches por vez e há 3+ entradas, o
  segundo `Merge` fica deslocado (`x` +60, `y` +80) do primeiro, não
  alinhado — deixa visível que é um estágio extra, não paralelo.
- **Nome dos nodes em português, descrevendo a ação** (verbo + objeto:
  "Buscar histórico", "Montar items do carrinho"), nunca o tipo técnico do
  node.
- **`notes` só quando não é óbvio pelo nome** — decisão de negócio, TODO
  pendente, ou pressuposto que pode quebrar (ex.: nome exato de campo de
  API externa ainda não confirmado).
