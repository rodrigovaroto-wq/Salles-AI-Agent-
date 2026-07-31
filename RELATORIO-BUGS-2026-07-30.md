# Relatório de bugs — 30–31/07/2026

Sessão de religar credenciais que virou caça a defeitos. **Doze bugs, cinco
deles fatais**, todos invisíveis para os testes que existiam.

Duas rodadas. Na primeira, com o Supabase ainda fora do ar, a auditoria estática
achou 5 defeitos. Na segunda, com a credencial preenchida, dava para **executar
de verdade** — e apareceram mais 7, entre eles o pior de todos: nenhum link de
pagamento chegaria à cliente.

O fio condutor: os ensaios validavam *o que o agente pensa* (montagem do
prompt) e *o que ele aceita* (HMAC). Nenhum validava **por onde o fluxo passa**,
**o que o banco devolve** nem **em que formato**. Os doze bugs moram nesses três
vãos.

> A lição que se repetiu: os defeitos não davam erro. Davam sempre a mesma
> resposta — e quase sempre a errada.

---

## 🔴 #0 — A credencial `SUPABASE` está vazia

**Gravidade: bloqueia tudo.** É a causa raiz de o sistema nunca ter dado sinal
de vida.

Uma sonda no n8n chamou o Supabase com a credencial anexada. As 7 chamadas
voltaram `401 — No API key found in request`, byte-idêntico ao que o Supabase
responde para uma chamada **sem autenticação alguma**.

O que isso prova, com precisão:

- a credencial **está vinculada** aos nós e **é aplicada** — se não estivesse,
  o n8n travaria com "Credentials not set" antes de sair da máquina;
- ela simplesmente **não carrega nenhum header**.

Os 34 nós de Supabase dos 6 workflows retornariam 401. Nenhuma lead registrada,
nenhum contexto carregado, nenhuma venda gravada.

**Correção (Rodrigo, 2 min):** n8n → Credentials → `SUPABASE`. O tipo *Custom
Auth* espera um objeto `headers`; colar as chaves na raiz é o erro comum e
falha em silêncio:

```json
{"headers": {"apikey": "<service_role key>",
             "Authorization": "Bearer <service_role key>"}}
```

**Por que passou:** nenhum teste jamais executou nada contra a rede.

---

## 🔴 #1 — O handoff de P1 (risco à vida) não acontecia

**Gravidade: fatal, e o pior tipo — falha exatamente no caso que mais importa.**

A saída `true` do nó `Intent = sofrimento?` estava **vazia**. Quando o agente
detectava risco à vida:

- ❌ a lead **não** era marcada `aguardando_humano`
- ❌ o Rodrigo **não** era avisado
- ❌ o nó `Marcar sofrimento na conversa` ficava **órfão** no canvas
- ❌ na mensagem seguinte, o portão `Conversa encerrada?` não barrava nada e
  **o agente voltava a vender para quem acabou de falar em se matar**

A única coisa que funcionava era a mensagem com o CVV 188 — que sai pelo ramo
normal de resposta. Ou seja: o teste P1 do checklist **passaria na leitura da
resposta** e o sistema estaria quebrado embaixo.

**Origem, por bisect no git:** a cadeia existia até `a361424` e foi perdida em
**`844f46f` — "Corrige inversao critica no portao de opt-out e aperta o gatilho
P1"**. O commit que dizia apertar o gatilho foi o que o cortou. Junto foram-se
`Preparar alerta de sofrimento` e `Enviar alerta de sofrimento`.

**Correção:** cadeia reconstruída em git e no n8n —
`Intent = sofrimento? [true] → Preparar alerta de sofrimento → Enviar alerta de
sofrimento → Marcar sofrimento na conversa`.

Há uma ironia útil aqui: o comentário dentro de `Montar mensagens OpenAI` já
dizia *"leads em P1 são barradas no node Conversa encerrada?. Se uma chegar
aqui, é bug de topologia."* O código descrevia o comportamento correto; a
topologia não o entregava.

---

## 🔴 #2 — O debounce apagava a mensagem da lead em vez de juntá-la

**Gravidade: fatal. Toda mensagem de toda lead chegava em branco no agente.**

`consumir_buffer()` fazia:

```sql
update leads set buffer_mensagens = '{}'
 where lead_id = p_lead_id and ultima_msg_id = p_msg_id
returning array_to_string(buffer_mensagens, E'\n') into v_texto;
```

`RETURNING` num `UPDATE` enxerga a linha **já modificada**. Quando o
`array_to_string` rodava, o array já era `'{}'`. O buffer voltava sempre `''`.

**Reproduzido em PostgreSQL 16:**

```
buffer no banco : {"primeira mensagem","segunda mensagem"}
consumir_buffer : ''          <- deveria trazer as duas
```

O caso de exceção ("superada por mensagem nova" → `NULL`) funcionava
perfeitamente. Era justamente isso que escondia o defeito: **o caminho raro
estava certo e o caminho de todo dia estava errado.**

**Correção:** [`migracao-correcao-buffer.sql`](30-integracoes/supabase/migracao-correcao-buffer.sql)
— lê o buffer antes de zerar, com `for update` segurando a linha até o commit
para que duas execuções concorrentes não leiam o mesmo buffer. Validado nos
dois cenários.

⚠️ **Precisa ser rodado no Supabase.** É `create or replace`, não destrói dados.

---

## 🟠 #3 — O retorno escalar do buffer era tratado como texto cru

**Gravidade: alta. Desarmava o debounce e mandava um objeto para a OpenAI.**

`consumir_buffer` devolve um **escalar** (`text` ou `null`). O nó HTTP do n8n
não entrega escalar como `$json` cru — envelopa em `{ data: <valor> }`. Duas
consequências:

1. `Ainda sou a ultima?` testava `{{ $json }}` com *string notEmpty*. Um objeto
   nunca é vazio → **o portão aprovava sempre** e o debounce, que existe para
   impedir três respostas desencontradas quando a lead manda três mensagens
   seguidas, nunca barrava nada.
2. `Montar mensagens OpenAI` fazia `const textoFinal = $node["Consumir
   buffer"].json` e empurrava esse **objeto** como `content` da mensagem do
   usuário — além de virar `"[object Object]"` na detecção de objeções.

**Correção:** novo nó `Normalizar buffer` resolve a forma **uma vez** e devolve
`{ texto, superada, vazio }`. O IF passa a testar o booleano explícito
`superada`; `Montar mensagens OpenAI` lê `.texto`. Robusto às duas formas
possíveis de envelopamento.

---

## 🟠 #4 — Faltavam 3 nós no `pagamento-bravopay` ao vivo

**Gravidade: alta para quem compra a Comunidade.**

O n8n tinha 37 dos 40 nós do git. Faltava a ponta que fecha a assinatura:
`Criar link de assinatura (Pagar.me)`, `Preparar convite de assinatura`,
`Enviar convite de assinatura`.

Efeito: quem comprasse um produto com mensalidade teria a assinatura registrada
no banco e **nunca receberia o link para cadastrar o cartão**. `Registrar
assinatura` era ponta solta. A cliente pagava a entrada, recebia o produto, e a
recorrência simplesmente não existia.

**Correção:** os 3 nós e as 3 conexões foram recriados por MCP. O nó do Pagar.me
fica sem credencial até a conta existir — como no git.

---

## O que foi feito

| | |
|---|---|
| Credenciais religadas | **39** nós, 5 workflows (as 5 restantes dependem de Meta/Pagar.me) |
| Bugs corrigidos | 4 (3 fatais) |
| Nós adicionados | 3 no `agente-vendas`, 3 no `pagamento-bravopay` |
| Migração SQL nova | `migracao-correcao-buffer.sql` |
| Ensaios novos | `ensaio-topologia.js` (83 checagens), `ensaio-conversa.js` (13 cenários) |

Os quatro ensaios passam: **83 + 13 + 14 + 12**.

### Verificação de que o novo ensaio serve para algo

Reintroduzi o bug #1 numa cópia e rodei o `ensaio-topologia`. Ele acusou por
**três ângulos independentes** — nó órfão, saída de IF vazia, e caminho
obrigatório inalcançável — e saiu com código de erro. Um teste que nunca falha
não é um teste.

---

## O que melhorar a seguir

### 1. Um teste que toca a rede (o vão que restou)

Os quatro ensaios rodam offline. O bug #0 só apareceu porque **executei algo de
verdade**. Vale um workflow permanente de *smoke test* no n8n — uma chamada a
cada dependência externa (Supabase, OpenAI, BravoPay), com resultado legível —
para rodar antes de ligar anúncio e depois de qualquer troca de credencial.
Custa centavos e teria economizado esta sessão inteira.

### 2. Nunca presumir que o n8n reflete o git

Foi falso **duas vezes só hoje** (37≠40 nós no bravopay; credencial vazia). E
já tinha sido falso três vezes na sessão anterior. O
`ensaio-topologia` compara git com git — falta um comando que compare **git com
o que está ao vivo**. É construível pelo MCP.

### 3. Preferir MCP a recolar

Recolar recria os nós e apaga as credenciais dos 49 — foi o que gerou a tarefa
desta sessão. `setNodeCredential` / `updateNodeParameters` mexem só no que
precisa. Esta sessão inteira foi feita assim, sem perder nada.

### 4. Pontos menores observados

- **`Registrar opt-out` e `Marcar sofrimento` não têm `onError`.** Se o
  Supabase estiver instável no momento exato, a execução morre e o estado não é
  gravado — justo nos dois nós em que o estado é obrigação legal/ética. Vale
  `retryOnFail`.
- **`Intent = opt_out?` não tem nó terminal na saída falsa**, enquanto
  `Intent = sofrimento?` tem (`Sem sofrimento detectado`). Funciona igual, mas a
  assimetria faz um ramo morto legítimo parecer bug — foi preciso registrar a
  exceção no ensaio. Um `noOp` deixaria a leitura uniforme.
- **`buffer_mensagens` não tem poda.** Se uma execução morrer entre o
  `bufferizar` e o `consumir`, o texto fica lá e entra na próxima mensagem da
  lead, fora de contexto. Um `where ultima_interacao > now() - interval '1 hour'`
  na leitura resolveria.
- **A coluna `link_blackcat_id` guarda id do BravoPay.** Já está anotado no nó;
  renomear exige migração dos dados. Fica o registro.
- **`agente-vendas` ao vivo × git:** funcionalmente idênticos (57 nós, 57
  conexões, mesmos nomes). Restam duas diferenças cosméticas num comentário e
  na forma de escrever a regex de acentos (`̀` virou o caractere literal
  equivalente na transcrição via MCP). Mesmo comportamento; vale reescrever a
  regex em ASCII puro numa próxima passada para a linha sobreviver a
  round-trips.

---

## O que **não** foi testado, e por quê

Sejamos exatos sobre o alcance desta sessão:

- **Nada foi executado de ponta a ponta.** A credencial `SUPABASE` vazia
  impede qualquer execução real. As correções de topologia estão verificadas
  por simulação de grafo, não por execução.
- **A OpenAI não foi chamada.** Sem saldo confirmado na conta.
- **Nenhuma mensagem de WhatsApp foi enviada.** A credencial não existe.
- **O bug #2 foi provado e corrigido em PostgreSQL 16 local**, não no Supabase
  — a função corrigida ainda precisa ser aplicada lá.

Ou seja: os quatro bugs estão corrigidos no código e no n8n, e **a validação
real começa quando a credencial do Supabase for preenchida.**

---

# Segunda rodada — 31/07, com o Supabase ligado

Com a credencial preenchida deu para **executar de verdade**. Apareceram
**mais sete defeitos**, um deles comercialmente fatal. Todos os sete vêm da
mesma raiz e nenhum era visível offline.

## A raiz: o n8n entrega uma LINHA por item, não o array

O PostgREST devolve `[{...}, {...}]`. O nó HTTP do n8n **quebra esse array em
itens** — cada linha vira um item, e `$json` é a **linha**, nunca a lista.

Quem escreveu os workflows assumiu o contrário. O resultado é traiçoeiro:

- `$json[0]` → `undefined`
- `$json.length` → `undefined`, e `undefined != 0` é **verdadeiro**, então toda
  comparação numérica com `typeValidation: loose` **passa**

Ou seja: os portões não davam erro. Eles respondiam sempre a mesma coisa.

## 🔴 #5 — Nenhum link de pagamento seria entregue. Nunca.

**Gravidade: fatal comercialmente. É o pior bug da sessão.**

`Venda criada?` testava `{{ $json.data }}` *notEmpty*. Mas a resposta de
`POST /transactions` do BravoPay é **plana** — está no
[`bravopay/README.md`](30-integracoes/bravopay/README.md):

```json
{ "id": "tx_...", "status": "PENDING", "amount_cents": 7112,
  "pix": { "copy_paste": "00020126..." } }
```

O envelope `data` só existe no **webhook**, não na criação. Então `$json.data`
era sempre vazio e **toda venda bem-sucedida caía no ramo de falha**.

A lead que acabou de aceitar a oferta e entregar e-mail e CPF receberia:

> *"Não consegui gerar seu link agora, foi um problema técnico aqui."*

E o Rodrigo receberia um alerta de falha do gateway — para uma cobrança que
foi criada com sucesso. **Conversão zero, com o sistema parecendo saudável.**

Curiosamente os outros três nós que leem a mesma resposta (`Preparar link de
pagamento`, `Guardar link gerado`, `Atualizar evento com carrinho`) já liam os
campos na raiz, corretamente. Era uma contradição interna: os quatro não podiam
estar certos ao mesmo tempo. A doc desempatou.

**Correção:** testa `{{ $json.id }}` notEmpty — o id da transação é o que a doc
garante vir na criação.

## 🔴 #6 — O n8n não conseguia sequer ler o buffer

A correção SQL da primeira rodada funcionou: medido ao vivo, o banco devolve
`"primeira mensagem\nsegunda mensagem"`. Mas o nó saía com:

```json
{"error": "Response body is not valid JSON. Change \"Response Format\" to \"Text\""}
```

`consumir_buffer` retorna `text`, e o PostgREST devolve **texto cru** — que não
é JSON válido quando contém quebra de linha. O `Normalizar buffer` então
calculava `String({error:...})` = `"[object Object]"`, que era o que iria para
a OpenAI como mensagem da lead.

**Correção:** `responseFormat: text` no nó. Medido depois da correção:

| caso | retorno do nó | resultado |
|---|---|---|
| última mensagem | `{"data":"primeira mensagem\nsegunda mensagem"}` | ✅ texto certo |
| superada | `{"data":null}` | ✅ `superada = true` |

## 🟠 #7 — A recuperação de carrinho de 2h nunca disparava

`Status = abandonou?` lia `{{ $json[0].status }}` → `undefined`. Quem começava
a compra e não concluía **nunca recebia** a mensagem de recuperação.

## 🟠 #8 — O digest do Hermes nunca era enviado

`Tem pendentes?` lia `{{ $json.length }}` de um objeto → `undefined > 0` é
**falso**. Com a fila cheia de sugestões, o digest ia sempre para "Nada
pendente". E `Montar digest` iterava sobre a primeira linha em vez da lista, o
que quebraria o nó se ele chegasse a executar.

## 🟠 #9 — O follow-up de 24h quebraria na primeira lead

`Separar leads (1 item cada)` fazia `$input.first().json.map(...)` sobre um
**objeto**. `.map` não existe ali: o nó lançaria exceção na primeira vez que
houvesse alguém para notificar. Nunca falhou porque nunca rodou com dados.

## 🟠 #10 — O `fila-decidir` inteiro, e a primeira versão de prompt

Quatro nós liam `json[0]`: `Derivar chave do prompt` (quebrava), e as duas
chamadas ao GitHub (montavam a URL com `undefined`).

E um problema separado: `Buscar versao atual` devolve array vazio quando a
chave ainda não tem versão ativa → **0 itens** → toda a cadeia seguinte é
pulada. A **primeira** versão de qualquer prompt nunca conseguiria ser
inserida. Resolvido com `alwaysOutputData`.

## 🟠 #11 — A auditoria do desconto se perdia em silêncio

`Atualizar evento com carrinho` montava
`?evento_id=eq.{{ ...json[0].evento_id }}` → `eq.undefined`. O PATCH não casava
com nada, retornava 200 e não gravava nada. Sem erro, sem rastro.

## 🟡 As travas de idempotência funcionavam por acidente

`Mensagem inedita?` e os dois `Webhook inedito?` liam `$json.length != 0` —
sempre verdadeiro. Não viraram reprocessamento por um detalhe: numa duplicata o
PostgREST devolve `[]`, o n8n produz **0 itens** e o fluxo simplesmente parava.

Medido, isolando a variável:

| caso | itens entregues | o ramo de descarte executou? |
|---|---|---|
| chave inédita | 1 | — segue o fluxo ✅ |
| duplicata | **0** | **não** — nada roda depois |
| duplicata **com `alwaysOutputData`** | 1, `{}` | condição antiga **passava** ⚠️ |

Ou seja: a proteção existia, mas não era a que estava escrita, `Duplicata
ignorada` era código morto, e bastava alguém ligar `alwaysOutputData` — algo
natural ao depurar "por que nada roda depois?" — para a trava **abrir**. Num
reenvio de `transaction.paid` isso é o produto entregue duas vezes.

**Correção:** `alwaysOutputData` + condição `{{ $json.chave }}` notEmpty. Agora
a trava é explícita, o ramo de descarte executa de verdade e aparece no log.

## O que foi confirmado funcionando ao vivo

| | |
|---|---|
| Credencial `SUPABASE` | ✅ autentica |
| `registrar_lead` | ✅ devolve a linha; `Conversa encerrada?` lê `.status` corretamente |
| `consumir_buffer` (SQL corrigido) | ✅ devolve as duas mensagens juntas |
| `consumir_buffer` (caso superada) | ✅ devolve `null` |
| `carregar_contexto` | ✅ 3 prompts, 4 produtos, 15 áudios, histórico |
| Preços no banco | ✅ 2290 / 1390 / 4490 / 1990 centavos |
| Trava de duplicata | ✅ agora explícita |

## Ensaios

`ensaio-topologia` ganhou duas seções que pegam esta classe inteira:

- **§5** — qualquer `$json[0]`, `$json.length` ou `.json[0]` em parâmetros
- **§6** — RPC de retorno escalar exige `responseFormat: text`

**92 checagens** passam, mais 13 + 14 + 12 dos outros três.

## Limpeza

As quatro sondas foram arquivadas e os registros de teste removidos do banco
(`probe_bug_hunt_001/002`, `probe_003`, `probe:004:idem` — conferido: a consulta
final volta vazia).

## O que ainda não foi testado

- **A OpenAI não foi chamada** — falta confirmar saldo. É o único elo do
  caminho principal que continua sem verificação real.
- **Nenhuma mensagem de WhatsApp saiu** — depende da Meta.
- **BravoPay e Pagar.me não foram chamados** — a correção do #5 está baseada na
  doc oficial do BravoPay, não numa resposta real. Vale conferir no primeiro
  `create-sale` de verdade que o `id` vem na raiz.
