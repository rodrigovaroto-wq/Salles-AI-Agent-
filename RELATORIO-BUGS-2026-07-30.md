# Relatório de bugs — 30/07/2026

Sessão de religar credenciais que virou caça a defeitos. **Quatro bugs, três
deles fatais**, todos invisíveis para os testes que existiam.

O fio condutor: os ensaios validavam *o que o agente pensa* (montagem do
prompt) e *o que ele aceita* (HMAC). Nenhum validava **por onde o fluxo passa**
nem **o que o banco devolve**. Os quatro bugs moram exatamente nesses dois
vãos.

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
