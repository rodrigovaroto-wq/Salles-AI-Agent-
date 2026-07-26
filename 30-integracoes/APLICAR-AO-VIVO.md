# Aplicar ao Vivo — Roteiro de Execução (Grupo C)

Tudo aqui é **execução manual sua** — depende de acesso ao seu Supabase e ao
seu n8n, que eu não tenho. Os arquivos já estão prontos no repo; este roteiro
é só a ordem dos cliques e como conferir que cada passo pegou.

**Ordem importa.** O passo 1 (SQL) é o que o agente lê em runtime; os passos
2–4 (n8n) são o que executa. Aplicar o workflow novo sem o SQL novo faz o
agente rodar com o playbook antigo.

Tempo estimado: ~20 minutos.

---

## Passo 0 — Migração obrigatória do schema (Supabase)

**Faça isto antes de ativar o workflow novo.** O handoff por sofrimento grava
`status = 'aguardando_humano'` na tabela `leads`, mas o `CHECK` original só
aceitava `('ativo','abandonou','cliente','opt_out')` — o Postgres rejeitaria a
gravação, e o mecanismo de segurança falharia **exatamente na situação em que
ele existe para agir**.

1. No [SQL Editor](https://supabase.com/dashboard/project/rmvmqmcfcjmcjtonewgi/sql/new),
   cole e rode [`supabase/migracao-aguardando-humano.sql`](supabase/migracao-aguardando-humano.sql).

**Como conferir:**

```sql
select pg_get_constraintdef(oid)
from pg_constraint
where conname = 'leads_status_check';
```

Precisa listar os **cinco** valores, incluindo `aguardando_humano`.

---

## Passo 1 — Atualizar o prompt em runtime (Supabase)

O agente não lê os arquivos `.md` do repositório em tempo real: ele lê a
tabela `prompt_ativo` no Supabase. Editar o `.md` **não muda o comportamento
ao vivo** até este passo rodar.

1. Abra o [SQL Editor do Supabase](https://supabase.com/dashboard/project/rmvmqmcfcjmcjtonewgi/sql/new).
2. Copie **todo** o conteúdo de [`supabase/seed-prompt-objecoes.sql`](supabase/seed-prompt-objecoes.sql) e cole no editor.
3. `Run`.

**Como conferir que pegou:**

```sql
select chave, versao, ativo, length(conteudo) as tamanho
from prompt_ativo
where ativo
order by chave;
```

Você deve ver `compliance` e `objecoes` com `ativo = true` e a `versao` **um
número maior** que antes. Nada é apagado — as versões anteriores continuam na
tabela com `ativo = false`, então dá pra reverter reativando a linha antiga.

> Rodar de novo é seguro: cria mais uma versão de ambas as chaves, mesmo que
> só uma tenha mudado. O único efeito colateral é um número de versão a mais.

---

## Passo 2 — Criar a credencial do GitHub no n8n

Isso destrava o espelhamento: quando você aprova uma sugestão do Hermes, além
de aplicar no Supabase, o n8n **commita a mudança no arquivo `.md`** do repo,
para você ter histórico legível fora do banco.

### 2a. Gerar o token no GitHub

1. Vá em [Fine-grained personal access tokens](https://github.com/settings/personal-access-tokens/new).
2. Preencha:
   - **Token name:** `n8n-salles-ai-agent`
   - **Expiration:** o que preferir (anote a data — quando vencer, o
     espelhamento para silenciosamente).
   - **Repository access:** `Only select repositories` → selecione
     **apenas** `rodrigovaroto-wq/Salles-AI-Agent-`
   - **Permissions** → `Repository permissions` → **Contents: Read and write**
     (só essa; deixe todo o resto em `No access`)
3. `Generate token` e **copie o valor** — o GitHub só mostra uma vez.

> Escopo mínimo de propósito: esse token só consegue escrever conteúdo neste
> repositório. Não acessa outros repos, não mexe em settings, não abre PR.

### 2b. Cadastrar no n8n

1. No n8n: `Settings` → `Credentials` → `Add Credential`.
2. Tipo: **Header Auth**.
3. Preencha exatamente:
   - **Credential Name:** `GitHub API`  ← o nome precisa ser esse, é por ele
     que os nós encontram a credencial depois do import
   - **Name:** `Authorization`
   - **Value:** `Bearer <cole o token aqui>`  ← com a palavra `Bearer` e um
     espaço antes do token
4. `Save`.

---

## Passo 2.5 — Criar a função de contexto (Supabase)

O `agente-vendas` deixou de fazer três buscas separadas e passou a chamar uma
função no banco. **Sem ela, o agente não responde nada** — a chamada retorna
404 e o fluxo morre ali.

Rode [`supabase/funcao-carregar-contexto.sql`](supabase/funcao-carregar-contexto.sql)
no SQL Editor. Confira com:

```sql
select carregar_contexto('lead_inexistente');
```

Tem que devolver as três chaves (`historico`, `prompts`, `produtos`).
`historico` vazio é o esperado para um lead que não existe; **`prompts` ou
`produtos` vazios** significam que o seed não rodou — o agente responderia sem
playbook e sem catálogo.

---

## Passo 3 — Recriar os workflows no n8n

A estrutura mudou: agora são **7 workflows** em vez de 5, com um sub-workflow
compartilhado. O desenho e o porquê estão em
[`n8n/ARQUITETURA.md`](n8n/ARQUITETURA.md).

> **A ordem importa.** O `sub-enviar-whatsapp` precisa existir **antes** dos
> demais, porque eles o referenciam por ID. Se você importar na ordem errada,
> os nós `Execute Workflow` ficam apontando para o vazio.

### 3a. Primeiro o sub-workflow

1. `Workflows` → `Import from File` → [`n8n/workflows/sub-enviar-whatsapp.json`](n8n/workflows/sub-enviar-whatsapp.json)
2. Abra o nó `Enviar (Graph API)` e selecione a credencial `WhatsApp Cloud API`.
3. Substitua `<<WHATSAPP_PHONE_NUMBER_ID>>` na URL desse nó.
   **É o único lugar do projeto com esse valor** — antes eram nove.
4. `Save`. **Não ative** — sub-workflow não se ativa; ele roda quando chamado.

### 3b. Depois os 6 workflows de entrada

Para cada um: se já existe no n8n, abra, `Ctrl+A` → `Delete`, cole o conteúdo
do `.json` (o n8n reconstrói a partir de JSON colado) e `Save`. Se não existe,
`Import from File`.

| Workflow | Arquivo | O que mudou |
|---|---|---|
| `00-meta-handshake` | [`00-meta-handshake.json`](n8n/workflows/00-meta-handshake.json) | **novo** — saiu de dentro do agente-vendas |
| `agente-vendas` | [`agente-vendas.json`](n8n/workflows/agente-vendas.json) | contexto numa chamada só; áudio; handoff; envios via sub-workflow |
| `pagamento-blackcat` | [`pagamento-blackcat.json`](n8n/workflows/pagamento-blackcat.json) | upsell pós-compra; envios via sub-workflow |
| `followup-24h` | [`followup-24h.json`](n8n/workflows/followup-24h.json) | template via sub-workflow |
| `fila-notificar` | [`fila-notificar.json`](n8n/workflows/fila-notificar.json) | digest via sub-workflow |
| `fila-decidir` | [`fila-decidir.json`](n8n/workflows/fila-decidir.json) | espelhamento no GitHub |

> ⚠️ Se você tinha importado o `workflow-completo.json`, **apague ou desative
> esse workflow agora**. Ele registra os mesmos paths de webhook
> (`whatsapp-in`, `blackcat`) e vai disputar com os individuais — as mensagens
> chegam num ou noutro, de forma imprevisível.

---

## Passo 4 — Religar as referências

Duas coisas não viajam entre instâncias de n8n — **isso é esperado**, não é
erro de import: o `id` das credenciais e o `id` dos sub-workflows.

### 4a. Apontar os nós `Execute Workflow` para o sub-workflow

Abra cada nó abaixo e, no campo **Workflow**, selecione
`sub-enviar-whatsapp (sub-workflow)` no dropdown:

| Workflow | Nós a religar |
|---|---|
| `agente-vendas` | `Enviar resposta ao lead`, `Enviar link de pagamento`, `Enviar alerta de sofrimento`, `Enviar pedido de texto` |
| `pagamento-blackcat` | `Enviar confirmacao de pagamento`, `Enviar recuperacao de carrinho`, `Enviar oferta de upsell` |
| `followup-24h` | `Enviar template de follow-up` |
| `fila-notificar` | `Enviar digest da fila` |

**Como saber que faltou algum:** um `Execute Workflow` sem destino falha na
execução com "workflow não encontrado". Não falha ao salvar — só quando roda.

### 4b. Conferir as credenciais dos nós HTTP

| Workflow | Nó | Credencial |
|---|---|---|
| `sub-enviar-whatsapp` | `Enviar (Graph API)` | `WhatsApp Cloud API` |
| `agente-vendas` | `Carregar contexto` | `Supabase (apikey+auth)` |
| `agente-vendas` | `Buscar URL do audio`, `Baixar audio binario` | `WhatsApp Cloud API` |
| `agente-vendas` | `Transcrever audio (Whisper)` | `OpenAI` |
| `agente-vendas` | `Marcar sofrimento na conversa` | `Supabase (apikey+auth)` |
| `pagamento-blackcat` | `Buscar produtos (upsell)`, `Buscar lead atualizado`, `Gravar oferta de upsell` | `Supabase (apikey+auth)` |
| `fila-decidir` | `Buscar SHA do arquivo no GitHub`, `Commitar mudanca no GitHub` | `GitHub API` |

Os demais nós de Supabase/OpenAI/BlackCat já existiam — vale passar o olho,
mas o import costuma reconhecê-los pelo nome da credencial.

### 4c. Substituir o verify token

No `00-meta-handshake`, nó `Validar verify token`: troque
`<<WHATSAPP_VERIFY_TOKEN>>` pela string que você vai cadastrar na Meta
(ver [`whatsapp/README.md`](whatsapp/README.md), seção 6).

---

## Passo 4.5 — Ativar, na ordem certa

1. **`00-meta-handshake`** primeiro — a Meta só aceita a inscrição do webhook
   se ele já estiver respondendo.
2. Depois os outros cinco.
3. **Nunca** o `sub-enviar-whatsapp` nem o `workflow-completo`.

Confira que o handshake responde antes de mexer no painel da Meta:

```bash
curl "https://salles-ai-agent.pikapod.net/webhook/whatsapp-in?hub.mode=subscribe&hub.verify_token=<SUA_STRING>&hub.challenge=12345"
```

Tem que responder exatamente `12345`, sem aspas.

---

## Passo 5 — Conferir o espelhamento no GitHub (teste isolado)

Dá pra testar o passo 2 sozinho, sem esperar o Hermes gerar sugestão:

1. Abra o workflow `fila-decidir` no n8n.
2. Abra o nó `Buscar SHA do arquivo no GitHub`.
3. Em `Execute step`, ele vai falhar por não ter o contexto de uma sugestão —
   o que interessa é o **tipo** de erro:
   - `401 Bad credentials` → o token está errado ou faltou o `Bearer `.
   - `404 Not Found` → o token não tem acesso a este repositório (revise o
     `Repository access` no passo 2a).
   - qualquer erro sobre a **expressão/campo vazio** → a credencial está OK,
     só falta o dado da sugestão. É esse que você quer ver.

---

## O que continua bloqueado depois disto

Estes passos **não** destravam o que depende de conta externa:

- Os placeholders `<<WHATSAPP_PHONE_NUMBER_ID>>`, `<<WHATSAPP_TEMPLATE_NAME>>`
  e `<<RODRIGO_WA_NUMBER>>` continuam literais até a verificação da empresa
  no Meta sair. Todo nó que envia WhatsApp falha até lá — incluindo o alerta
  de handoff por sofrimento.
- O Hermes continua parado por falta de créditos na OpenAI. Como a transcrição
  de áudio usa a mesma conta, **ela também só funciona quando houver crédito**.

Enquanto isso, o que **já** funciona sem WhatsApp: o registro em banco. Um lead
sinalizado por sofrimento fica com `status = aguardando_humano` na tabela
`leads` mesmo que a notificação não saia — dá pra conferir manualmente:

```sql
select lead_id, nome, status, ultima_interacao
from leads
where status = 'aguardando_humano'
order by ultima_interacao desc;
```

---

## Relacionado
- [`n8n/workflows/README.md`](n8n/workflows/README.md) — o que cada workflow faz e por que ficou assim
- [`whatsapp/README.md`](whatsapp/README.md) — o que falta na verificação Meta
- [`hermes/configuracao.md`](hermes/configuracao.md) — o ciclo que o espelhamento no GitHub fecha
