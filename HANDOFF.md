# Handoff — 2026-07-22

Nota de transição de sessão. Objetivo: a próxima sessão retomar sem
reconstruir o histórico.

## Estado atual

- Branch de trabalho: **`claude/handoff-continuation-7gb0cr`** → **PR #16**
  (aberto, ainda não mergeado). `main` está no PR #14 (`1c63865`).
- Todo o código desta sessão já está **commitado e no PR #16**. Working tree
  limpo. Últimos commits relevantes:
  - `31f2865` — playbook de objeções no prompt ao vivo.
  - `dedc8db` — coleta de email/CPF para o create-sale do BlackCat.

## O que foi feito nesta sessão (em ordem)

### 1. Coleta de email/CPF na conversa (BlackCat) — commit `dedc8db`
A API do BlackCat exige `customer{name,email,phone,document{number,type}}`
completo no `create-sale`; o link só é gerado com isso preenchido (não dá pra
completar depois no checkout). Reverteu a decisão antiga (email/CPF só no
checkout). Agora:
- O agente pede email + CPF na conversa quando o lead aceita o stack, antes de
  gerar o link. Só retorna `intent=gerar_link` com os dois presentes.
- `Criar venda BlackCat` monta o `customer` (`document.type='cpf'`,
  digits-only).
- Novo node **"Salvar dados de pagamento do lead"** grava email/cpf em `leads`.
- `schema.sql`: colunas `leads.email` / `leads.cpf` (alter table idempotente).

### 2. Playbook de objeções no prompt ao vivo — commit `31f2865`
Diagnóstico de 27 objeções reais mostrou que o agente improvisava em ~20
delas: o prompt ao vivo só carregava `objetivo` + `compliance`, sem guia de
objeções. Maior alavanca honesta de conversão/ticket, e reduz risco de
compliance.
- `00-nucleo/objecoes.md`: playbook (27 objeções em clusters), todo dentro do
  compliance. Onde falta fato operacional real (formato do contato com o
  padre, atividade da comunidade, identidade da operação) instrui **descoberta
  honesta**, não afirmação inventada.
- Wired: nova chave `objecoes` em `prompt_ativo`, carregada junto de
  objetivo/compliance (nodes "Buscar prompt ativo" + "Montar mensagens
  OpenAI", nos dois JSONs git).
- `compliance-e-etica.md` seção 4: novo disclaimer "não substitui a
  igreja/comunidade/padre".
- `30-integracoes/supabase/seed-prompt-objecoes.sql`: upsert versionado de
  `compliance` + `objecoes` em `prompt_ativo`.

### 3. Correção de bug no workflow ao vivo (via n8n MCP)
Os nodes **"Merge contexto"** e **"Merge contexto 2"** estavam com o parâmetro
antigo `combinationMode`; a versão do Merge do pod (3.2) usa `combineBy`. Sem
isso o node travava com "You need to define at least one pair of fields in
Fields to Match" — **quebraria o fluxo inteiro em produção**. Corrigido ao
vivo para `combineBy: combineByPosition`. Os JSONs git já estão nesse formato
correto. **Cuidado:** reimportar um JSON antigo por cima traz o bug de volta.

### 4. Testes rodados (via n8n MCP, com dados simulados)
- Fluxo aceita-produto + email/CPF → gera link: passou (customer montado,
  desconto certo, "Salvar dados" e "Criar venda" em paralelo).
- Fluxo sem email/CPF → `intent=aceitou_stack`, NÃO gera link: confirmado
  (foi pro branch "Fim (sem link ainda)", BlackCat não rodou).
- Verificação local (Node.js) do node "Montar mensagens OpenAI": injeta
  `objecoes` na ordem certa (compliance → objecoes → resto) e é
  retrocompatível se a chave não existir.

## O que o Rodrigo já fez do lado dele
- **Rodou o `seed-prompt-objecoes.sql` no Supabase.** Logo: a chave `objecoes`
  e a versão nova de `compliance` já existem em `prompt_ativo`.
- Efeito imediato: o disclaimer "não substitui a igreja" **já está valendo ao
  vivo** (o node já busca `compliance`). O playbook de objeções ainda **não**,
  porque depende das 2 edições de node abaixo.

## PENDENTE — 2 edições no n8n ao vivo (bloqueado: MCP do n8n instável)
Durante a sessão o conector n8n (self-hosted, PikaPods) oscilou muito e no
fim ficou indisponível para os dois lados. As 2 edições precisam ser
aplicadas quando o n8n estiver acessível (via MCP na próxima sessão, ou manual
no editor). Valores exatos:

1. Node **"Buscar prompt ativo"** → campo URL:
   `https://rmvmqmcfcjmcjtonewgi.supabase.co/rest/v1/prompt_ativo?chave=in.(objetivo,compliance,objecoes)&ativo=eq.true`
   (única diferença: `(objetivo,compliance)` → `(objetivo,compliance,objecoes)`)
2. Node **"Montar mensagens OpenAI"** → campo JavaScript: substituir pelo
   jsCode atual do node em `30-integracoes/n8n/workflows/agente-vendas.json`
   (mesmo conteúdo em `workflow-completo.json`).

Sem essas 2 edições, o workflow ao vivo funciona normal, só não injeta o
playbook de objeções (retrocompatível).

## Passivo de compliance a resolver (NÃO implementado de propósito)
Dois arquivos no repo contêm material que **viola o próprio
`compliance-e-etica.md`** e a lei (CDC/Estatuto do Idoso), marcados "para uso
nos workflows". NÃO foram wirados no prompt ao vivo e NÃO devem ser:
- `10-skills/gatilhos/gatilhos-espirituais.md`: urgência falsa ("vagas fecham
  hoje"), recado de Padre Pio/santo inventado.
- `10-skills/provas/testemunhos.md`: prova social fabricada ("97 mil saíram
  das dívidas em 24h", "o exame voltou limpo"), claims de cura/renda.
Recomendação: remover ou marcar explicitamente como proibidos, para ninguém
wirar por engano.

## Próximos passos sugeridos
1. Aplicar as 2 edições de node no n8n (acima) e rodar um teste confirmando
   que o prompt montado inclui o playbook.
2. Testar de verdade a autenticação real das credenciais (Supabase/BlackCat/
   OpenAI) — o teste via MCP simula as respostas HTTP; só execução real
   (webhook de teste ou workflow ativo) confirma auth.
3. Testar o create-sale real do BlackCat ponta a ponta (customer completo →
   invoiceUrl volta).
4. Confirmar o webhook `/webhook/blackcat` com evento de teste real.
5. WhatsApp (pausado, depende de acesso à conta Meta do sócio): passos 1–10
   em `30-integracoes/whatsapp/README.md`. Placeholders a preencher:
   `<<WHATSAPP_PHONE_NUMBER_ID>>`, `<<WHATSAPP_TEMPLATE_NAME>>`,
   `<<RODRIGO_WA_NUMBER>>`.
6. Fazer merge do PR #16 quando estiver satisfeito.

## Padrões relevantes (manter consistência)
- **Camadas**: `00-nucleo/` (prompt sempre ativo) → `10-skills/` (sob demanda,
  NÃO carregado no prompt ao vivo) → `20-memoria/` (schemas) →
  `30-integracoes/` (n8n, Supabase, BlackCat, WhatsApp, Hermes).
- **Prompt ao vivo carrega SÓ** as chaves `objetivo`, `compliance`, `objecoes`
  de `prompt_ativo` (Supabase) — nada de `10-skills/` entra automaticamente.
- **`compliance-e-etica.md` é autoridade máxima e fonte única** de conduta;
  vence qualquer skill/sugestão. Persuasão honesta é permitida e desejada;
  engano não.
- **Dados de pagamento (email/CPF) coletados na conversa**, não no checkout
  (exigência da API BlackCat).
- **Segredos só como Credentials nativas do n8n** (PikaPods não tem `$env`).
- **Desconto sempre aplicado de verdade no valor cobrado.**
- **Sincronizar Supabase ao editar os .md-fonte**: os `.md` de
  `objetivo/compliance/objecoes` são a fonte git; o que roda ao vivo é a cópia
  em `prompt_ativo`. Editou o .md → regenere e rode o
  `seed-prompt-objecoes.sql` (ou o INSERT versionado equivalente).

## Ferramentas desta sessão
- **n8n MCP** (conector self-hosted): workflow ao vivo é
  `id=JggVoiBXncdkTfQz` ("salles-ai-agent — operacao completa"). Credenciais
  já criadas: `SUPABASE`, `Open IA API`, `BlackCat API`. Instável na sessão —
  se cair, desconectar/reconectar no claude.ai força novo handshake.
