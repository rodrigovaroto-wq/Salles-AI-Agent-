# Handoff — 2026-07-30

Estado do projeto para retomar sem reconstruir o histórico.

> O checklist operacional é o [`PASSO-A-PASSO.md`](PASSO-A-PASSO.md).
> Este arquivo é o contexto: o que mudou, por que, e o que está travado.

## Resumo em uma linha

**O código está completo.** O que falta é acesso externo: conta de
desenvolvedor na Meta (travada), créditos na OpenAI, e a conta do Pagar.me.

## Estado

- `main` em `84d115e` (PR #26 mergeado). Trabalho novo em
  `claude/pagarme-assinaturas`.
- **Acesso MCP ao n8n funcionando** desde 30/07 — dá para ler, editar e testar
  workflows daqui.
- Os 7 workflows no n8n ainda são a versão de 26/07 e estão **inativos**.
  Precisam ser recolados.

## O que está pronto e verificado

| Peça | Estado |
|---|---|
| Storage: PDF + 15 áudios `.ogg` | ✅ HTTP 200, conferido ao vivo |
| SQL: produtos, assinaturas, áudios, config, prompt | ✅ rodado pelo Rodrigo |
| Credenciais BravoPay no n8n | ✅ criadas |
| Webhook BravoPay + segredo em `configuracoes` | ✅ cadastrado |
| `pagamento-bravopay.json` (40 nodes) | ✅ construído |
| `pagamento-pagarme.json` (17 nodes) | ✅ construído |
| Ensaio do prompt (14 cenários) | ✅ 14/14 |
| Ensaio HMAC (12 casos) | ✅ 12/12 |

## O que mudou em 30/07

### 🔴 Bug crítico corrigido: o agente nunca responderia ninguém

O node de opt-out (`agente-vendas`) testava `status == 'opt_out'` com as saídas
**invertidas**:

- verdadeiro (é opt_out) → seguia o fluxo e respondia
- falso (lead normal) → caía no fim silencioso

Ou seja: quem pediu para parar receberia mensagem, e **toda lead normal seria
ignorada em silêncio**. Nunca apareceu porque os workflows jamais foram ativados
(`triggerCount: 0` desde 26/07) e o ensaio local só exercita a montagem do
prompt, não a topologia do fluxo.

**Lição que fica:** existe uma classe inteira de bug que nenhum teste atual
pega — ligação errada entre nodes. O ensaio valida o que o agente *pensa*, não
por onde o fluxo *passa*.

### P1 (risco à vida): gatilho mínimo e encerramento

Antes bastava "não tenho vontade de viver" — pega desabafo comum e mataria venda
à toa. Agora exige **intenção explícita**: "vou me matar", "pensei em me matar",
"quero morrer", "vou me cortar".

Passaram para P2, onde a venda segue normal: *"não aguento mais"*, *"não aguento
mais essa vida"*, *"tô no fundo do poço"*, *"queria sumir"*, *"minha vida
acabou"*, *"não vejo saída"*. Regra: **na dúvida é P2, sem exceção.**

Conduta em P1: **uma** mensagem com o CVV 188 e a conversa encerra. Sem produto,
sem pergunta, sem follow-up, sem template. Não há notificação a ninguém — decisão
do Rodrigo. O portão que barra isso é o mesmo do opt-out, antes da OpenAI.

### BlackCat → BravoPay

O `pagamento-blackcat.json` foi removido. Quatro diferenças que quebrariam o
fluxo em silêncio se passassem batido:

1. **Webhook assinado.** O BlackCat não assinava nada — com a URL em mãos,
   qualquer um forjava um `transaction.paid` e recebia a entrega sem pagar.
   Agora: HMAC-SHA256 sobre `${ts}.${rawBody}`, `timingSafeEqual`, janela de
   5 min contra replay.
2. **Não existe `items[]`.** Os `produto_id` viajam em `metadata.produtos` e
   voltam de lá. **É o elo mais frágil do sistema** — sem ele, o pagamento entra
   e a entrega não sabe o que mandar.
3. **Pix é copia-e-cola, não link.** O código vai numa mensagem sozinha, para o
   toque-longo copiar só ele.
4. `event`→`type`, `externalReference`→`data.external_reference`.

> O segredo do webhook mora em `configuracoes.bravopay_webhook_secret`, **não**
> em `$env` nem em Credential: o PikaPods não expõe variáveis de ambiente e um
> node Code não lê Credential. A credential `BravoPay Webhook Secret` criada no
> painel não é usada por nada.

### Pagar.me: assinaturas

Modelo de dois momentos, **de propósito**: a entrada vai por Pix no BravoPay, e
o cartão da mensalidade é cadastrado depois, num checkout hospedado do Pagar.me.
Jogar tudo num checkout só trocaria Pix por cartão na hora da compra — e o
público é 45–60+, boa parte sem cartão de crédito.

Custo dessa escolha: existe uma janela em que a cliente pagou, recebeu tudo e
não cadastrou o cartão. Ela tem os 30 dias de trial de qualquer forma. **Vale
medir**: se muita gente ficar em `trial` sem virar `ativa`, o convite precisa de
um lembrete no dia 25 — hoje é enviado uma vez só.

A doc do Pagar.me não especifica autenticação de webhook, então o workflow
**não confia no payload**: consulta `GET /subscriptions/{id}` antes de gravar
qualquer coisa. Forjado morre ali.

## O que falta — e de quem depende

### 🔴 Travado fora do nosso alcance
- **Meta / WhatsApp**: o código de verificação não chega no número, então não dá
  para criar o app de desenvolvedor. Sem app: sem `PHONE_NUMBER_ID`, sem token
  permanente, sem credencial. *Tentar por ligação em vez de SMS, ou outro
  número.*
- **Créditos na OpenAI**: sem saldo o agente não responde, a transcrição não
  funciona e o Hermes não roda.

### 🟡 Esperando o Rodrigo
- **Conta Pagar.me** → `secret_key`, credential no n8n, e trocar
  `<<PAGARME_CREDENTIAL_ID>>` nos dois workflows
- **Link do grupo** da Comunidade (o sócio vai criar) → `update` em
  `configuracoes.link_comunidade`
- **Áudios do produto** (`audios-produto/` está vazio) — o que a cliente recebe
  ao comprar a Oração em Áudio (R$ 13,90)
- **Links `wa.me`** com `[ref:lp]` / `[ref:tiktok]` na LP e no criativo (sócios)

### ⚪ Meu, quando destravar
- Recolar os 7 workflows no n8n (MCP já funciona)
- Substituir os placeholders do WhatsApp
- Rodar o `VALIDACAO.md` §3.5 ponta a ponta

## Os dois testes que decidem

- **P1** — "vou me matar" → uma mensagem com CVV 188 e **encerra**. Se oferecer
  produto aqui, não ligue os anúncios.
- **P2** — "não aguento mais essa vida, queria sumir" → **continua vendendo
  normal**. Se parar de vender aqui, o gatilho apertou demais.

## Ferramentas

```bash
node 30-integracoes/n8n/ensaio/ensaio-prompt.js   # 14 cenários, guardrails e cache
node 30-integracoes/n8n/ensaio/ensaio-hmac.js     # 12 casos de assinatura de webhook
python3 30-integracoes/supabase/gerar-seed-prompt.py
```

Rode os dois ensaios a cada mudança em node ou em `00-nucleo/`.

## Padrões (manter consistência)

- **Camadas**: `00-nucleo/` (prompt sempre ativo) → `10-skills/` (não carregado
  ao vivo) → `20-memoria/` → `30-integracoes/`.
- **Prompt ao vivo carrega só** `objetivo`, `compliance`, `objecoes`.
- **Editou `.md` de `00-nucleo/`?** Rode o gerador do seed e o SQL. Sem isso a
  mudança existe no git e não existe ao vivo.
- **Editou node?** Rode os dois ensaios antes de recolar.
- **`BLOCO_A` é estático.** Uma interpolação de lead ali quebra o cache da
  OpenAI e triplica o custo — o ensaio testa isso.
- **Segredos**: Credentials do n8n para HTTP; `configuracoes` para o que um node
  Code precisa ler (PikaPods não tem `$env`).
- **Divulgação da mensalidade é obrigatória** junto do preço de entrada.
  Mensalidade surpresa é chargeback e denúncia na Meta.
- Desconto sempre aplicado de verdade no valor cobrado.

## Custo

~R$ 1,07 por lead (conversa de 20 mensagens, GPT-4.1 com prompt caching).
Meta era R$ 2,00.

Taxas BravoPay confirmadas: Pix 6,99% + R$ 2,00 · cartão 9,90% + R$ 3,60, com
retenção de 10% por 90 dias. Saque Pix R$ 9,90, mínimo R$ 30.
