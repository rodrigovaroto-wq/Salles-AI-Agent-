# Aplicar ao Vivo — Roteiro de Execução (Grupo C)

Tudo aqui é **execução manual sua** — depende de acesso ao seu Supabase e ao
seu n8n, que eu não tenho. Os arquivos já estão prontos no repo; este roteiro
é só a ordem dos cliques e como conferir que cada passo pegou.

**Ordem importa.** O passo 1 (SQL) é o que o agente lê em runtime; os passos
2–4 (n8n) são o que executa. Aplicar o workflow novo sem o SQL novo faz o
agente rodar com o playbook antigo.

Tempo estimado: ~20 minutos.

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

## Passo 3 — Atualizar os workflows no n8n

Os arquivos mudaram (transcrição de áudio, handoff por sofrimento, upsell
pós-compra, espelhamento no GitHub). Precisam ser reimportados.

**Importar cria um workflow novo — não sobrescreve o que já existe.** Para
atualizar um workflow que já está lá, o caminho é substituir o conteúdo:

1. Abra o workflow no n8n.
2. Clique no canvas e dê `Ctrl+A` (selecionar tudo) → `Delete`.
3. Abra o `.json` correspondente no repo, copie **todo** o conteúdo.
4. Volte ao canvas do n8n e dê `Ctrl+V` — o n8n reconhece JSON de workflow
   colado e reconstrói os nós.
5. `Save`.

Faça isso para:

| Workflow | Arquivo | Por que mudou |
|---|---|---|
| `agente-vendas` | [`n8n/workflows/agente-vendas.json`](n8n/workflows/agente-vendas.json) | Transcrição de áudio, gate de mensagem ilegível, handoff por sofrimento, reuso de e-mail/CPF |
| `pagamento-blackcat` | [`n8n/workflows/pagamento-blackcat.json`](n8n/workflows/pagamento-blackcat.json) | Upsell pós-compra (com guarda de opt-out) |
| `fila-decidir` | [`n8n/workflows/fila-decidir.json`](n8n/workflows/fila-decidir.json) | Os 2 nós de espelhamento no GitHub |

> Se você importou o `workflow-completo.json` em vez dos individuais, substitua
> só ele — [`n8n/workflows/workflow-completo.json`](n8n/workflows/workflow-completo.json)
> já contém as mesmas mudanças (é gerado a partir dos individuais).

---

## Passo 4 — Reconectar as credenciais nos nós

O `id` de credencial não viaja entre instâncias de n8n — **isso é esperado**.
Depois de colar, os nós de HTTP Request podem aparecer sem credencial
selecionada.

Abra cada nó que faz HTTP Request e confirme o campo **Credential for Header
Auth / Custom Auth**. Os nós **novos**, que com certeza precisam de atenção:

**Em `agente-vendas`:**

| Nó | Credencial |
|---|---|
| `Buscar URL do audio` | `WhatsApp Cloud API` |
| `Baixar audio binario` | `WhatsApp Cloud API` |
| `Transcrever audio (Whisper)` | `OpenAI` |
| `Responder que nao consegui ler` | `WhatsApp Cloud API` |
| `Notificar Rodrigo (sofrimento)` | `WhatsApp Cloud API` |
| `Marcar sofrimento na conversa` | `Supabase (apikey+auth)` |

**Em `pagamento-blackcat`:**

| Nó | Credencial |
|---|---|
| `Buscar produtos (upsell)` | `Supabase (apikey+auth)` |
| `Buscar lead atualizado` | `Supabase (apikey+auth)` |
| `Enviar upsell WhatsApp` | `WhatsApp Cloud API` |
| `Gravar oferta de upsell` | `Supabase (apikey+auth)` |

**Em `fila-decidir`:**

| Nó | Credencial |
|---|---|
| `Buscar SHA do arquivo no GitHub` | `GitHub API` |
| `Commitar mudanca no GitHub` | `GitHub API` |

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
