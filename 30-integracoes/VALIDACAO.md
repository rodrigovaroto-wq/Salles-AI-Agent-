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

Esse teste também arma o upsell: 10 minutos depois, o fluxo deve tentar
oferecer o próximo produto. Como o WhatsApp ainda está bloqueado, o envio
falha — mas dá para ver a execução no histórico do n8n e conferir se
`Selecionar proximo produto` escolheu o item certo.

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
