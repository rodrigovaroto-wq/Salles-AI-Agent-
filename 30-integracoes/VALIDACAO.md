# Validação Ponta a Ponta (Grupo G)

Nada aqui foi executado contra os serviços reais — **este é o roteiro, não um
relatório**. Cada teste diz o que rodar, o que precisa acontecer, e o que
significa quando não acontece.

A ordem é de dependência: cada bloco só faz sentido se o anterior passou. Se
um teste falhar, pare nele — os seguintes vão falhar por arrasto e confundir o
diagnóstico.

| Bloco | Depende de | Dá para rodar hoje? |
|---|---|---|
| [1. Supabase](#1-supabase) | nada | ✅ sim |
| [2. OpenAI](#2-openai) | créditos na conta | ⛔ sem créditos |
| [3. BlackCat](#3-blackcat) | chave de API | ✅ sim |
| [4. WhatsApp](#4-whatsapp) | verificação Meta | ⛔ bloqueado |
| [5. Fluxo completo](#5-fluxo-completo) | todos acima | ⛔ bloqueado |

Convenção: exporte uma vez e reaproveite.

```bash
export SUPABASE_URL='https://rmvmqmcfcjmcjtonewgi.supabase.co'
export SUPABASE_KEY='<service_role key>'
export N8N_URL='https://salles-ai-agent.pikapod.net'
```

---

## 1. Supabase

### 1.1 A chave autentica

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  "$SUPABASE_URL/rest/v1/produtos?limit=1" \
  -H "apikey: $SUPABASE_KEY" -H "Authorization: Bearer $SUPABASE_KEY"
```

- `200` → ok.
- `401` → a chave está errada, ou você usou a `anon key` (que o RLS bloqueia —
  as tabelas têm RLS ligado sem policy pública, de propósito).

### 1.2 O catálogo está populado com os preços reais

```bash
curl -s "$SUPABASE_URL/rest/v1/produtos?select=produto_id,nome,tipo,preco_centavos,ordem&order=ordem" \
  -H "apikey: $SUPABASE_KEY" -H "Authorization: Bearer $SUPABASE_KEY"
```

Precisa vir 1 `principal` (Oração Sagrada, `2290`) e 3 `order_bump`
(`1390`, `4490`, `1990`). **Preço em centavos.** Se vier `[]`, o agente vai
montar um stack vazio e não conseguir vender nada.

### 1.3 O prompt ativo está lá (o que o agente lê em runtime)

```bash
curl -s "$SUPABASE_URL/rest/v1/prompt_ativo?select=chave,versao,ativo&ativo=eq.true" \
  -H "apikey: $SUPABASE_KEY" -H "Authorization: Bearer $SUPABASE_KEY"
```

Precisa listar `objetivo`, `compliance` e `objecoes`. **Faltar `objecoes`
significa que o agente está rodando sem o playbook de objeções** — ele
responde, mas sem nenhuma das estratégias, e sem a instrução de handoff por
sofrimento.

### 1.4 A migração do handoff pegou

```sql
select pg_get_constraintdef(oid) from pg_constraint
where conname = 'leads_status_check';
```

Tem que incluir `aguardando_humano`. Se não incluir, o handoff falha na
gravação — ver [`APLICAR-AO-VIVO.md`](APLICAR-AO-VIVO.md), passo 0.

---

## 2. OpenAI

### 2.1 A chave autentica e tem crédito

```bash
curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-4.1","messages":[{"role":"user","content":"responda apenas: ok"}],"max_tokens":5}'
```

- resposta com `choices` → ok.
- `401` → chave inválida.
- `429` / `insufficient_quota` → **é o bloqueio atual**. Sem crédito, três
  coisas param: o agente não responde, a transcrição de áudio não funciona
  (mesma conta) e o Hermes não roda.

### 2.2 A saída em JSON estruturado é respeitada

O workflow depende de `response_format: json_object` e de o modelo devolver os
campos exatos. Vale testar antes de confiar no fluxo:

```bash
curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"gpt-4.1","response_format":{"type":"json_object"},
       "messages":[{"role":"system","content":"Responda SEMPRE em JSON: {\"resposta\": string, \"intent\": \"qualificando\"|\"sofrimento\", \"produtos_aceitos\": string[], \"arquetipo\": null, \"pivo_downsell\": false, \"email\": null, \"cpf\": null}"},
                   {"role":"user","content":"oi, quero saber mais"}]}'
```

O `content` tem que ser JSON válido com **todos** os campos. O nó "Extrair
resposta e intent" faz `JSON.parse` direto — campo faltando vira `undefined`
silencioso mais adiante, não erro imediato.

### 2.3 Transcrição de áudio (Whisper)

```bash
# gere um ogg curto de teste, ou use qualquer arquivo de voz que você tenha
curl -s https://api.openai.com/v1/audio/transcriptions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F file=@teste.ogg -F model=whisper-1 -F language=pt
```

Precisa devolver `{"text": "..."}`. **Se der erro de formato**, é o problema
que o nó `Nomear arquivo de audio` existe para evitar: a API decide o formato
pelo *nome* do arquivo, e a URL de mídia do WhatsApp não traz extensão.

---

## 3. BlackCat

### 3.1 A chave autentica

Confirmado na doc oficial: header `X-API-Key`, **não** `Authorization: Bearer`.

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  https://api.blackcatoficial.com/api/sales/create-sale \
  -H "X-API-Key: $BLACKCAT_API_KEY" -H 'Content-Type: application/json' -d '{}'
```

Qualquer coisa que **não** seja `401` já prova que a chave é aceita (`400`
aqui é o esperado — o corpo está vazio de propósito).

### 3.2 `create-sale` real, com customer completo

Este é o teste que mais importa: é onde a venda de verdade acontece. Use um
CPF e e-mail seus.

```bash
curl -s https://api.blackcatoficial.com/api/sales/create-sale \
  -H "X-API-Key: $BLACKCAT_API_KEY" -H 'Content-Type: application/json' \
  -d '{
    "amount": 2290,
    "paymentMethod": "pix",
    "items": [{"title":"Oracao Sagrada","quantity":1,"unitPrice":2290}],
    "customer": {
      "name": "Teste Validacao",
      "email": "<seu-email>",
      "phone": "5511999999999",
      "document": {"number":"<seu-cpf-so-digitos>","type":"cpf"}
    },
    "externalRef": "5511999999999",
    "postbackUrl": "'"$N8N_URL"'/webhook/blackcat",
    "metadata": "origem:teste"
  }'
```

Confira três coisas na resposta:

1. Vem `data.invoiceUrl`? É o link que o agente manda pro lead — o nó "Enviar
   link WhatsApp" lê exatamente esse caminho.
2. Vem `data.transactionId`? É o que fecha a auditoria do desconto.
3. `amount` **em centavos** — se o BlackCat interpretar como reais, a venda
   sai por R$ 2.290,00 em vez de R$ 22,90. Abra o `invoiceUrl` e confira o
   valor na tela antes de qualquer coisa.

> ⚠️ **Isso cria uma cobrança real.** Não pague, ou pague e estorne. Se pagar,
> o webhook dispara de verdade — o que na prática já valida o bloco 3.3.

### 3.3 O webhook chega no n8n

1. No painel do BlackCat, aponte o postback para
   `$N8N_URL/webhook/blackcat`.
2. Com o workflow `pagamento-blackcat` **ativo**, simule:

```bash
curl -s -X POST "$N8N_URL/webhook/blackcat" \
  -H 'Content-Type: application/json' \
  -d '{"event":"transaction.paid","externalReference":"5511999999999",
       "transactionId":"tx_teste_123",
       "items":[{"title":"Oracao Sagrada","quantity":1,"unitPrice":2290}]}'
```

Depois confira que o lead virou cliente:

```bash
curl -s "$SUPABASE_URL/rest/v1/leads?lead_id=eq.5511999999999&select=status,etapa_funil,produtos_comprados" \
  -H "apikey: $SUPABASE_KEY" -H "Authorization: Bearer $SUPABASE_KEY"
```

> **Atenção ao nome do campo:** o `create-sale` envia `externalRef`, mas o
> webhook devolve `externalReference`. Não é inconsistência nossa — é da API
> deles, e os workflows já usam cada um no seu lugar. Se o lead não for
> encontrado, é o primeiro suspeito.

Esse teste também dispara a **entrega**: o fluxo lê `produtos.entrega_texto` e
manda o acesso. Como o WhatsApp ainda está bloqueado, o envio falha — mas dá
para conferir no histórico do n8n se `Montar entrega` casou o item comprado
com o catálogo, e se caiu no ramo de alerta caso `entrega_texto` esteja vazio.

**Reenvie o mesmo `curl`**: a segunda chamada tem que parar em `Reenvio
ignorado`. Sem essa trava, um reenvio do BlackCat entregaria o produto duas
vezes.

---

## 3.5 Ensaio geral sem WhatsApp

**Este é o teste mais valioso enquanto a Meta não libera.** O `agente-vendas`
é disparado por um webhook HTTP comum — dá para chamá-lo direto com o mesmo
formato de payload que a Meta manda. Tudo roda de verdade: upsert do lead,
carregamento de contexto, OpenAI, decisão de intent, gravação em `conversas`.
**Só o envio final falha** — e falha de forma controlada, porque o
`sub-enviar-whatsapp` devolve `{ok:false, erro}` em vez de derrubar o fluxo.

### Preparação: uma credencial WhatsApp de mentira

Crie uma credencial **Header Auth** chamada `WhatsApp Cloud API` com
`Name: Authorization` e `Value: Bearer ainda-nao-tenho`. Sem nenhuma
credencial o nó falha na configuração; com uma inválida ele chega a chamar a
Graph API e recebe um erro HTTP — que é o caminho que o `onError` trata. É a
diferença entre "não deu pra testar" e "testei tudo menos a última linha".

Substitua depois pela real. **Não ative o `followup-24h`** durante o ensaio.

### O disparo

> ⚠️ **Cada mensagem precisa de um `id` único.** O fluxo agora descarta webhook
> repetido (a Meta reenvia quando não recebe 200 a tempo), e a chave de dedup é
> esse `id`. Repetir o mesmo faz a mensagem ser ignorada — de propósito. O
> `$(date +%s)` abaixo resolve isso sozinho.

```bash
enviar() {
  curl -s -X POST "$N8N_URL/webhook/whatsapp-in" \
    -H 'Content-Type: application/json' \
    -d "{
      \"entry\": [{ \"changes\": [{ \"value\": {
        \"contacts\": [{ \"profile\": { \"name\": \"Maria Teste\" }, \"wa_id\": \"${2:-5511988887777}\" }],
        \"messages\": [{ \"id\": \"teste_$(date +%s%N)\", \"from\": \"${2:-5511988887777}\",
                       \"type\": \"text\", \"text\": { \"body\": \"$1\" } }]
      }}]}]
    }"
}

enviar "vi o anuncio e quero saber mais [ref:lp]"
```

> ⏱️ **A resposta demora ~8 segundos.** Não é lentidão: é o *debounce*. Quem
> escreve em três pedaços ("oi" / "vi o anúncio" / "quanto custa?") recebia
> três respostas cegas entre si; agora a execução espera a rajada terminar e
> responde uma vez, considerando tudo. As execuções superadas encerram em
> `Superada por mensagem nova` — ver isso no histórico é o esperado, não erro.

### O que conferir, na ordem

**1. No histórico de execuções do n8n** (`Executions` → a mais recente): abra
e percorra os nós. O que precisa ter acontecido:

| Nó | Sinal de que está certo |
|---|---|
| `Marcar evento processado` | devolveu 1 linha (mensagem inédita) |
| `Extrair mensagem e origem` | `origem: "lp"` (leu o marcador `[ref:lp]`) |
| `Registrar lead` | devolveu o lead **sem sobrescrever** status |
| `Lead pediu para parar?` | seguiu pelo ramo **false** |
| `Consumir buffer` | devolveu o texto (não `null`) |
| `Carregar contexto` | `prompts` com 3, `produtos` com 4, e o objeto `lead` |
| `Montar mensagens OpenAI` | o `system` traz a tabela de desconto em R$ |
| `Extrair resposta e intent` | `mensagens` é um **array** de 1 a 3 textos curtos |
| `Enviar resposta ao lead` | `ok: false` — **esperado**, é o WhatsApp faltando |
| `Gravar evento conversa` | rodou **mesmo com o envio falhando** |

Esse último é o ponto: o fluxo não pode parar porque o WhatsApp não saiu.

**2. No banco** — o lead e a conversa existem:

```sql
select lead_id, nome, origem_canal, status from leads
where lead_id = '5511988887777';

select ocorrido_em, mensagem_lead, left(mensagem_agente, 120) as resposta
from conversas where lead_id = '5511988887777'
order by ocorrido_em desc;
```

`mensagem_agente` é **a resposta que a lead teria recebido**. Leia com
atenção: é o produto do prompt inteiro (objetivo + compliance + objeções +
catálogo) rodando de verdade. Se estiver ruim, é agora que se descobre — sem
gastar lead real.

### Continue a conversa

Repita o `curl` mudando só o texto, para atravessar o funil:

| Mande | Espere |
|---|---|
| `quanto custa?` | preço da Oração Sagrada, R$ 22,90 — nunca outro número |
| `quero sim` | os **3** order bumps de uma vez, com a tabela de economia |
| `vou levar tudo` | pedido de e-mail e CPF **numa mensagem só** |
| `maria@teste.com, 111.444.777-35` | `intent=gerar_link` → link real do BlackCat |
| `esta caro demais` (em outro lead) | pivô para a Oração em Áudio com 20% |

O CPF acima é um número válido pelo dígito verificador e não pertence a
ninguém — serve para o BlackCat aceitar sem usar dado real de terceiro.

> ⚠️ Ao chegar em `gerar_link`, uma cobrança **real** é criada no BlackCat.
> Confira o valor no `invoiceUrl` e não pague — ou pague e estorne.

### Teste do handoff (o mais importante)

Use um `wa_id` diferente e mande algo que sinalize sofrimento real. Confira:

1. `intent = "sofrimento"` no nó `Extrair resposta e intent`.
2. A resposta **não menciona produto nem preço**.
3. `status = 'aguardando_humano'`:

```sql
select lead_id, status from leads where status = 'aguardando_humano';
```

Se o agente oferecer qualquer produto nessa conversa, **pare** — é o guardrail
principal falhando, não um detalhe de conversão.

### Limpar depois

```sql
delete from leads where lead_id in ('5511988887777');  -- conversas caem junto (on delete cascade)
delete from eventos_processados where chave like 'wa:teste_%' or chave = 'wa:fixo_123';
```

---

## 4. WhatsApp

Tudo aqui depende da verificação da Meta. Os testes estão em
[`whatsapp/README.md`](whatsapp/README.md): handshake (seção 6), envio via
`curl` (seção 7), template (seção 9).

Ordem mínima: **handshake → envio → recebimento**. Não adianta testar
recebimento antes de o handshake passar, porque sem ele a Meta nem entrega os
eventos.

---

## 5. Fluxo completo

Só depois de 1–4 passarem. Mande uma mensagem real do seu celular para o
número do agente e acompanhe:

| # | O que fazer | O que precisa acontecer |
|---|---|---|
| 1 | Mandar `oi [ref:lp]` | Lead criado em `leads` com `origem_canal = meta_ads` |
| 2 | Conversar até aceitar o produto | O agente apresenta os 3 bumps **de uma vez**, com a tabela de economia |
| 3 | Conferir os valores da tabela | Precisam bater com o que o BlackCat vai cobrar (2 bumps = 20% off) |
| 4 | Aceitar o stack | O agente pede e-mail e CPF numa mensagem só |
| 5 | Informar os dois | Chega o `invoiceUrl`; o valor na tela do BlackCat bate com o anunciado |
| 6 | **Mandar um áudio** | O agente responde ao **conteúdo** do áudio, não com "não consegui ouvir" |
| 7 | **Mandar uma figurinha** | O agente responde pedindo texto — e **não** inventa o que você "disse" |
| 8 | Pagar | Confirmação chega; `status = cliente` |
| 9 | Esperar 10 min | Chega a oferta do próximo produto; ela aparece em `conversas` |
| 10 | Responder `sim` | O agente entende do que se trata (só funciona por causa do passo 9) |

### Teste as correções de robustez

Cada um exercita um defeito que estava aberto até 2026-07-26.

**Dedup (#5)** — mande a mesma mensagem duas vezes com o **mesmo** `id`:

```bash
ID="fixo_123"
for i in 1 2; do
  curl -s -X POST "$N8N_URL/webhook/whatsapp-in" -H 'Content-Type: application/json' \
    -d "{\"entry\":[{\"changes\":[{\"value\":{
      \"contacts\":[{\"profile\":{\"name\":\"Teste\"},\"wa_id\":\"5511988887777\"}],
      \"messages\":[{\"id\":\"$ID\",\"from\":\"5511988887777\",\"type\":\"text\",
                    \"text\":{\"body\":\"oi\"}}]}}]}]}"
done
```

A segunda execução tem que parar em `Duplicata ignorada`.

**Debounce (#8)** — três mensagens em menos de 8 segundos:

```bash
enviar "oi"; enviar "vi o anuncio"; enviar "quanto custa?"
```

Só **uma** resposta. As duas primeiras execuções param em `Superada por
mensagem nova`, e a que responde recebe as três linhas juntas.

**Opt-out (#4)** — `enviar "nao quero mais receber mensagem"`:

```sql
select status, consentimento_contato from leads where lead_id = '5511988887777';
```

Tem que estar `opt_out` / `false`. Mande outra mensagem depois: a execução
precisa parar em `Opt-out respeitado`, **sem responder**.

**Estado preservado (#2)** — o teste que mais importa. Force um estado e mande
mensagem:

```sql
update leads set status = 'aguardando_humano' where lead_id = '5511988887777';
```

`enviar "oi de novo"` e confira que **continua** `aguardando_humano` (antes
voltava para `ativo` a cada mensagem) e que o system prompt do
`Montar mensagens OpenAI` contém **MODO SEM VENDA**.

**Já comprou (#11)** — com `produtos_comprados` preenchido, o catálogo no
system prompt precisa listar **menos** produtos, sem o que ela já tem.

### Teste do handoff (faça por último, num lead separado)

Mande algo que sinalize sofrimento real. O agente precisa:

1. **Parar de vender** — nenhuma menção a produto ou preço na resposta.
2. Acolher, e mencionar ajuda imediata (CVV 188) se houver risco à vida.
3. Disparar a notificação para o seu número.
4. Gravar `status = 'aguardando_humano'`:

```sql
select lead_id, nome, status, ultima_interacao from leads
where status = 'aguardando_humano' order by ultima_interacao desc;
```

**Se o agente oferecer qualquer produto nessa conversa, pare a operação** —
não é um bug de conversão, é o guardrail principal falhando. Confira, nesta
ordem: a chave `objecoes` está ativa em `prompt_ativo` (teste 1.3)? O modelo
retornou `intent="sofrimento"` (visível no histórico de execução do n8n)?

---

## Relacionado
- [`APLICAR-AO-VIVO.md`](APLICAR-AO-VIVO.md) — os passos de aplicação que precedem esta validação
- [`n8n/workflows/README.md`](n8n/workflows/README.md) — o que cada nó faz e por quê
- [`blackcat/eventos-webhook.md`](blackcat/eventos-webhook.md) — os 3 eventos e o que cada um dispara
