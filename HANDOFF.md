# HANDOFF — Estado do Projeto

Atualizado em 2026-07-27.

## Onde estamos

O agente está **construído e verificado**; o que falta para leads reais é
operacional, não de código.

- Branch: **`claude/handoff-continuation-7gb0cr`** → PR #16
- Tudo commitado e no remoto. Working tree limpo.

| Frente | Estado |
|---|---|
| Supabase (schema, funções, catálogo) | ✅ pronto e testado contra Postgres real |
| Workflows n8n (7 arquivos) | ✅ prontos, 34 verificações passando |
| Prompt em runtime (`prompt_ativo`) | ✅ objetivo + compliance + objeções |
| Fatos operacionais (Grupo A) | ✅ aplicados — restam 5 `[confirmar]` de detalhe |
| Entrega pelo WhatsApp | ⚠️ construída, falta preencher `entrega_texto` |
| WhatsApp / Meta | ⏳ verificação em análise (~2 dias) |
| Conteúdo de compliance nas skills | ⏸️ revertido a pedido; segue como está |

## Bloqueia o primeiro lead

1. **Verificação da Meta** — único item fora do seu controle.
2. **`entrega_texto` dos 4 produtos** — sem isso, cada venda vira trabalho
   manual: a cliente recebe "acesso em seguida" e você recebe o alerta.
3. **Saldo na OpenAI** — sem ele o agente não responde e a transcrição não roda.

## Ordem das migrações (importa)

```
schema.sql → migracao-aguardando-humano.sql → migracao-entrega.sql
  → migracao-robustez.sql   ← define as 5 funções
  → seed-prompt-objecoes.sql
```

⚠️ **Não rode `funcao-carregar-contexto.sql`** — está esvaziado de propósito.
Rodá-lo rebaixaria `carregar_contexto` sem erro nenhum, derrubando o modo
sem-venda do handoff e o filtro de produtos já comprados.

## O que foi feito nesta sessão

**Mecanismos** — transcrição de áudio (Whisper), handoff por sofrimento com
alerta e trava de venda, entrega do produto pelo WhatsApp, remoção do upsell
pós-compra, handshake da Meta em workflow próprio, role Postgres restrito para
o Hermes.

**Arquitetura** — um workflow por gatilho; envio de WhatsApp consolidado num
sub-workflow (eram 9 cópias); contexto do agente numa chamada só (eram 3 GETs
mais 2 `Merge` frágeis).

**Robustez** — 13 defeitos de auditoria fechados, entre eles o follow-up que
reenviaria template de hora em hora para sempre e o upsert que apagava
`opt_out`/`aguardando_humano` a cada mensagem.

**Verificação** — um [simulador](30-integracoes/n8n/simulador/README.md) executa
os workflows fora do n8n contra um Postgres real. Encontrou 5 defeitos que
sintaxe e integridade davam como corretos, incluindo ramos invertidos no IF de
opt-out e `$json.body` quebrado no pagamento (nenhum pagamento seria
processado).

## Decisões suas em aberto

- **Quem atende um handoff de sofrimento, e em quanto tempo?** A notificação cai
  no seu WhatsApp; às 3h de domingo, hoje a resposta é "nada até você ver".
- **Nome do produto:** o portfólio Meta é "Oferta Sao Bento", o catálogo diz
  "Oração Sagrada". Isso muda o que o agente fala e o texto do template.
- **`10-skills/provas/testemunhos.md`** segue com números fabricados de
  resultado financeiro e cura, sob a instrução de usá-los nas copies. Não chega
  ao agente hoje (runtime carrega só objetivo/compliance/objeções), mas está no
  repo marcado como material de uso.

## Mapa

| Documento | Para quê |
|---|---|
| [`CHECKLIST-PRE-LEADS.md`](CHECKLIST-PRE-LEADS.md) | o que falta, por risco |
| [`30-integracoes/APLICAR-AO-VIVO.md`](30-integracoes/APLICAR-AO-VIVO.md) | passo a passo de implantação |
| [`30-integracoes/VALIDACAO.md`](30-integracoes/VALIDACAO.md) | como testar, incluindo o ensaio sem WhatsApp |
| [`30-integracoes/n8n/ARQUITETURA.md`](30-integracoes/n8n/ARQUITETURA.md) | divisão dos workflows e por quê |
| [`30-integracoes/n8n/simulador/`](30-integracoes/n8n/simulador/README.md) | rodar os workflows fora do n8n |
