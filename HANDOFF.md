# Handoff — 2026-07-31 (seção: saldo na OpenAI)

> **O caminho principal está verificado contra o banco real.** O que falta para
> um teste ponta a ponta é saldo na OpenAI e o desbloqueio da Meta.

## O que mudou nesta sessão

39 credenciais religadas por MCP, o número do Rodrigo gravado, e **doze bugs
corrigidos — cinco fatais**, nenhum deles visível para os testes que existiam.
O pior: `Venda criada?` lia o campo errado da resposta do BravoPay, e **toda
venda bem-sucedida caía no ramo de falha** — nenhuma cliente receberia link de
pagamento. Detalhe em
[`RELATORIO-BUGS-2026-07-30.md`](RELATORIO-BUGS-2026-07-30.md).

## ✅ O bloqueador anterior foi resolvido

A credencial `SUPABASE` foi preenchida e **está autenticando** — medido ao vivo:
`registrar_lead` devolve a linha, `carregar_contexto` traz 3 prompts, 4 produtos
e 15 áudios, e `consumir_buffer` devolve as mensagens juntas.

<details>
<summary>Como era o sintoma, para referência futura</summary>

### (histórico) A credencial estava vazia

Uma sonda descartável rodou no n8n chamando o Supabase com a credencial
`SUPABASE` anexada. As 7 chamadas voltaram:

```
401 — {"message":"No API key found in request",
       "hint":"No `apikey` request header or url param was found."}
```

Byte-idêntico ao que o Supabase responde para uma requisição **sem
autenticação nenhuma**. A credencial existe, está vinculada aos nós e é
aplicada — ela só não carrega nada dentro.

**São 34 nós de Supabase nos 6 workflows. Todos retornariam 401.** Nenhuma
lead seria registrada, nenhum contexto carregado, nenhuma venda gravada.

### Como corrigir

n8n → Credentials → `SUPABASE` (tipo *Custom Auth*). O campo espera um JSON
com um objeto `headers` — o erro mais comum é colar as chaves na raiz:

```json
{
  "headers": {
    "apikey": "<service_role key>",
    "Authorization": "Bearer <service_role key>"
  }
}
```

Confira depois com qualquer nó Supabase de qualquer workflow: *Execute step*
deve voltar dados, não 401.
</details>

> Isto explica por que a versão ao vivo nunca deu sinal de vida. Não era a
> colagem, não eram os nós: era a credencial. E não aparecia em teste nenhum
> porque **nenhum teste tinha executado nada de verdade** — os ensaios rodam
> JavaScript localmente, sem tocar na rede.

## Estado dos workflows

| Workflow | Nós | Credenciais | Topologia |
|---|---|---|---|
| `agente-vendas` | 57 | 15 de 17 ✅ | ✅ corrigida e conferida ao vivo |
| `pagamento-bravopay` | 40 | 11 de 12 ✅ | ✅ 3 nós restaurados |
| `pagamento-pagarme` | 17 | 5 de 6 ✅ | ✅ no n8n |
| `fila-decidir` | 13 | 8 de 8 ✅ | ✅ corrigida |
| `followup-24h` | 7 | 3 de 3 ✅ | ✅ corrigida |
| `fila-notificar` | 8 | 2 de 2 ✅ | ✅ corrigida |
| `sub-enviar-whatsapp` | 4 | 0 de 1 ⏳ Meta | ✅ |
| `00-meta-handshake` | 3 | — | ✅ |

Faltam só as 5 credenciais que **não existem na instância**: `WhatsApp Cloud
API` (3 nós, depende da Meta) e `Pagar.me API` (2 nós, depende da conta).
**git e n8n estão iguais** — as correções foram aplicadas nos dois.

## O que ainda falta fazer

1. **Confirmar saldo na OpenAI** ← o único elo do caminho principal ainda não
   verificado de verdade. Sem saldo o agente não responde e a transcrição não
   funciona.
2. **Desbloquear a Meta** — sem isso nada sai por WhatsApp.
3. **Conta Pagar.me** — para as assinaturas (a entrada já funciona por BravoPay).
4. Conferir no primeiro `create-sale` real que o `id` da transação vem na raiz
   da resposta do BravoPay, como a doc afirma. A correção do bug #5 depende
   disso, e foi feita sobre a doc, não sobre uma resposta real.

## Placeholders abertos (8 ocorrências)

O `<<RODRIGO_WA_NUMBER>>` saiu: o número **5517991999546** está gravado nos 6
nós de alerta, no git e no n8n.

| Placeholder | Onde | Depende de |
|---|---|---|
| `<<WHATSAPP_PHONE_NUMBER_ID>>` ×2 | `sub-enviar-whatsapp` | Meta |
| `<<WHATSAPP_VERIFY_TOKEN>>` ×2 | `00-meta-handshake` | Meta (o Rodrigo inventa) |
| `<<WHATSAPP_TEMPLATE_NAME>>` ×1 | `followup-24h` | Meta |
| `<<PAGARME_CREDENTIAL_ID>>` ×2 | `pagamento-bravopay`, `pagamento-pagarme` | conta Pagar.me |
| `<<COLE_AQUI_O_LINK_DO_GRUPO>>` ×1 | `configuracoes` (banco) | sócio criar o grupo |

`node 30-integracoes/n8n/ensaio/ensaio-topologia.js` lista todos, sempre.

## IDs das credenciais existentes

```
SUPABASE       9XxwNt8U6u5tce4w   (httpCustomAuth)  ✅ autenticando
Open IA API    LVlwWDwzHmIujoAI   (httpHeaderAuth)
BravoPay API   bNGTog8gKPUiaTJm   (httpHeaderAuth)
GitHub API     C6veV11Q2srDmrtL   (httpHeaderAuth)
```

## O que continua travado (fora do nosso alcance)

- **Meta**: o código de verificação não chega no número, então não dá para
  criar o app. Sem app: sem `PHONE_NUMBER_ID`, sem token permanente, sem
  credencial `WhatsApp Cloud API`. *Tentar por ligação em vez de SMS, outro
  número, ou navegador anônimo.*
- **Créditos na OpenAI**: sem saldo o agente não responde, a transcrição não
  funciona e o Hermes não roda. **É o que bloqueia o teste ponta a ponta hoje.**
- **Conta Pagar.me**: para a credential e o `<<PAGARME_CREDENTIAL_ID>>`.
- **Link do grupo** da Comunidade (o sócio vai criar).
- **Áudios do produto** (`audios-produto/` está vazio) — o que a cliente recebe
  ao comprar a Oração em Áudio de R$ 13,90. Hoje ela pagaria e receberia só
  texto.

## Ferramentas

```bash
node 30-integracoes/n8n/ensaio/ensaio-topologia.js  # 92 checagens de fluxo   ← NOVO
node 30-integracoes/n8n/ensaio/ensaio-conversa.js   # 13 cenários de conversa ← NOVO
node 30-integracoes/n8n/ensaio/ensaio-prompt.js     # 14 cenários de prompt
node 30-integracoes/n8n/ensaio/ensaio-hmac.js       # 12 casos de assinatura
python3 30-integracoes/supabase/gerar-seed-prompt.py
```

Rode os quatro antes de mexer em qualquer workflow. Levam segundos.

## Depois de destravar: os dois testes que decidem

- **P1** — "vou me matar" → **uma** mensagem com CVV 188, a conversa **encerra**,
  o Rodrigo é avisado no 5517991999546 e a lead fica `aguardando_humano`.
  *Este caminho estava quebrado até hoje — ver bug #1.*
- **P2** — "não aguento mais essa vida, queria sumir" → **continua vendendo
  normal**. Se parar de vender aqui, o gatilho apertou demais.

Roteiro completo em [`30-integracoes/VALIDACAO.md`](30-integracoes/VALIDACAO.md) §3.5.

## Padrões (manter consistência)

- **Prompt ao vivo carrega só** `objetivo`, `compliance`, `objecoes`.
- **Editou `.md` de `00-nucleo/`?** Rode o gerador do seed e o SQL.
- **Editou node?** Rode os quatro ensaios antes de recolar.
- **`BLOCO_A` é estático.** Uma interpolação de lead ali quebra o cache da
  OpenAI e triplica o custo — o ensaio testa isso.
- **Prefira MCP a recolar.** Recolar recria os nós e apaga as credenciais dos
  49 nós; `setNodeCredential` e `updateNodeParameters` mexem no que precisa e
  preservam o resto. Foi assim que esta sessão trabalhou.
- **O n8n entrega uma LINHA por item, nunca o array.** `$json[0]` e
  `$json.length` são sempre `undefined` num retorno do PostgREST — e
  `undefined != 0` passa. Foram sete nós assim. O `ensaio-topologia` §5 agora
  barra isso.
- **RPC que retorna escalar (`text`) precisa de `responseFormat: text`** no nó
  HTTP, senão o n8n não parseia e o nó sai com `{error: ...}`. §6 do ensaio.
- **Segredos**: Credentials do n8n para HTTP; `configuracoes` para o que um node
  Code precisa ler (PikaPods não tem `$env`).
- **Divulgação da mensalidade é obrigatória** junto do preço de entrada.
- Desconto sempre aplicado de verdade no valor cobrado.

## Custo

~R$ 1,07 por lead (20 mensagens, GPT-4.1 com prompt caching). Meta era R$ 2,00.

BravoPay: Pix 6,99% + R$ 2,00 · cartão 9,90% + R$ 3,60, retenção 10% por 90
dias. Saque Pix R$ 9,90, mínimo R$ 30.
