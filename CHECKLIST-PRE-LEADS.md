# Checklist — O que falta antes do primeiro lead real

Estado em 2026-07-26. A ordem dos blocos é de risco, não de esforço: o Bloco 1
é o que **causa dano** se você ligar os anúncios sem resolver; o Bloco 2 é
trabalho mecânico que já está pronto para executar.

Resumo honesto: **o agente está tecnicamente pronto e comercialmente não.** O
que falta não é código — é informação de negócio e limpeza de passivo.

---

## 🔴 Bloco 1 — Bloqueia lead real

### 1.1 Passivo de compliance (o mais urgente)

`10-skills/provas/testemunhos.md` contém, textualmente, sob o título "Números
oficiais de prova social" e a instrução "use exatamente esses números nas
copies":

> - 97 mil pessoas saíram das dívidas em 24 horas
> - 64 mil brasileiros zeraram dívidas em 48 horas
> - 69 mil pessoas saíram da pobreza em menos de 3 dias

Isso viola **quatro** proibições absolutas do próprio `compliance-e-etica.md`
(seção 2): prova social inventada, promessa de resultado financeiro,
estatística sem fonte, e exploração de vulnerabilidade. Aplicado ao público
declarado — mulheres 45–60+, muitas endividadas — soma CDC art. 37, agravante
do Estatuto do Idoso, e banimento de conta na Meta/TikTok.

O arquivo diz "para uso nos workflows do n8n". Hoje ele **não** está no prompt
ao vivo — mas está no repositório, marcado como material a usar. Basta alguém
(ou um Hermes futuro) seguir a instrução.

- [ ] Neutralizar `10-skills/provas/testemunhos.md`
- [ ] Neutralizar `10-skills/gatilhos/gatilhos-espirituais.md`
- [ ] Revisar `10-skills/gatilhos/gatilhos-idoso.md` e `provas/prova-social-avancada.md`
- [ ] Confirmar que nenhum deles é carregado em `prompt_ativo`

> Eu posso fazer isso agora — não depende de nada externo. Você pediu para
> pular o Grupo D antes; enquanto não for feito, é o maior risco aberto.

### 1.2 A entrega não existe no sistema 🔴

A operação informou que **"o cliente recebe automaticamente as instruções de
acesso pelo e-mail e/ou WhatsApp"**. O agente agora promete isso à lead.

**Mas nenhum workflow entrega nada.** Depois de `transaction.paid`, a sequência
real é:

```
Marcar cliente → "Pagamento confirmado! Em instantes você recebe
                  os detalhes de acesso." → esperar 10 min → OFERTA DE UPSELL
```

A cliente paga, ouve "em instantes você recebe", e dez minutos depois recebe
**uma nova oferta de venda em vez do produto**. Para um público cujo maior
medo é "paguei e não recebi", isso é gerador de chargeback — e agora o agente
está prometendo a entrega explicitamente, o que agrava.

- [ ] **Definir quem entrega:** o BlackCat dispara e-mail de entrega
      automaticamente, ou isso precisa ser construído no n8n?
- [ ] Se for o BlackCat: confirmar que está configurado e testar de verdade
- [ ] Se não for: construir o passo de entrega **antes** do upsell
- [ ] Rever a ordem — oferecer upsell antes de entregar o que foi comprado é
      errado mesmo que a entrega funcione

> Este é o item que eu resolveria primeiro depois do compliance. Não é
> hipótese: está verificado no workflow.

### 1.3 Fatos operacionais — o que ainda falta (Grupo A)

**Resolvidos** ✅ — já aplicados no playbook e no SQL do prompt:
entrega (automática, e-mail + WhatsApp), garantia (**7 dias**, CDC art. 49),
formato da Comunidade, formato do Contato com o Padre (mensagens num canal,
**não** é atendimento individual).

Restam 7 pontos `[confirmar]`, agora de detalhe e não de essência:

- [ ] **Conteúdo de cada item** — quantas orações, quantos minutos de áudio,
      quantas páginas, em que plataforma se acessa
- [ ] **Canal da Comunidade** — WhatsApp ou Telegram?
- [ ] **Frequência** das mensagens do padre e dos conteúdos da comunidade
- [ ] **Identidade pública** — ver 1.4 abaixo

### 1.4 "Padre Frei" — pergunta em aberto 🔴

A operação informou que *"a identidade pública apresentada no funil é a do
Padre Frei"*, e que o Contato com o Padre são *"mensagens e orientações dentro
do canal"*.

**Falta um fato:** existe um padre real por trás dessa identidade?

- **Se sim** — nome e vínculo, e o agente pode citá-lo com naturalidade. A
  seção J deixa de ser evasiva, o que ajuda muito num público com radar de
  golpe ligado.
- **Se não** — se "Padre Frei" é uma persona de marketing e as mensagens são
  geradas pelo agente, então o produto **Contato Direto com o Padre**
  (R$ 19,90) vende acesso a um sacerdote que não existe, para mulheres
  religiosas em fragilidade. Isso não é escolha de posicionamento: é o produto
  não corresponder ao que é vendido, com o agravante do público.

- [ ] Confirmar se há sacerdote real
- [ ] Se não houver: rever o produto antes de vendê-lo, não só o texto

Enquanto isso não for respondido, a seção J segue `[confirmar]` e o agente
**não** afirma quem conduz a operação.

### 1.3 WhatsApp / Meta

- [ ] Verificação da empresa aprovada ⏳ *(o único ponto onde o relógio corre por terceiro — comece já)*
- [ ] App criado e vinculado à empresa
- [ ] WABA de produção + número registrado
- [ ] Token permanente (System User, escopos `messaging` + `management`, sem expiração)
- [ ] `phone_number_id` anotado
- [ ] Webhook verificado com campo `messages` marcado
- [ ] Template de follow-up aprovado — 1 variável, `pt_BR`, categoria Utilitário

### 1.4 OpenAI com saldo

- [ ] Confirmar crédito na conta (`VALIDACAO.md`, teste 2.1)

Sem saldo, três coisas param juntas: o agente não responde, a transcrição de
áudio não funciona e o Hermes não roda. Credencial configurada ≠ conta com
saldo.

---

## 🟡 Bloco 2 — Configuração (pronto, falta executar)

- [ ] Recolar os 7 workflows *(os IDs de credencial e do sub-workflow já estão
      gravados nos JSONs — recolar religa 29 credenciais e 9 nós sozinho)*
- [ ] Criar credencial `WhatsApp Cloud API` → destrava os 3 nós restantes
- [ ] Substituir os 4 placeholders: `<<WHATSAPP_PHONE_NUMBER_ID>>` (2),
      `<<RODRIGO_WA_NUMBER>>` (2), `<<WHATSAPP_VERIFY_TOKEN>>` (2),
      `<<WHATSAPP_TEMPLATE_NAME>>` (1)
- [ ] Apagar/desativar o `workflow-completo` se estiver na instância *(disputa
      os mesmos paths de webhook)*
- [ ] Ativar na ordem: `00-meta-handshake` primeiro, depois os outros 5
- [ ] **Nunca** ativar `sub-enviar-whatsapp` nem `workflow-completo`

Detalhe em [`30-integracoes/APLICAR-AO-VIVO.md`](30-integracoes/APLICAR-AO-VIVO.md).

---

## 🟢 Bloco 3 — Validação antes de ligar o anúncio

- [ ] **Ensaio sem WhatsApp** ([`VALIDACAO.md`](30-integracoes/VALIDACAO.md) §3.5)
      — roda o funil inteiro por `curl`. **Faça antes de tudo:** é onde você lê
      a resposta que a lead receberia, sem gastar lead
- [ ] Conferir que a tabela de desconto bate com o valor cobrado no BlackCat
- [ ] `create-sale` real → `invoiceUrl` com o valor certo *(R$ 22,90 e não R$ 2.290)*
- [ ] Webhook do BlackCat marcando `status = cliente`
- [ ] Mensagem de áudio → o agente responde ao **conteúdo**
- [ ] Figurinha/imagem → pede texto, **não inventa** o que você disse
- [ ] Upsell chega 10 min após a compra e aparece em `conversas`
- [ ] **Teste do handoff** — o agente para de vender, acolhe, e grava
      `status = 'aguardando_humano'`

> Critério de parada: se no teste de handoff o agente oferecer qualquer
> produto, **não ligue os anúncios**. É o guardrail principal falhando.

### E uma decisão que não é técnica

- [ ] **Quem atende um handoff de sofrimento, e em quanto tempo?**

A notificação chega no seu WhatsApp. Se ela chegar às 3h da manhã de um
domingo, o que acontece? Hoje a resposta é "nada até você ver". Antes de leads
reais em volume, isso precisa de um combinado — nem que seja "só rodo anúncio
em horário que consigo responder".

---

## ⚪ Bloco 4 — Depois dos primeiros leads

Nada aqui bloqueia o teste com lead real.

- [ ] Hermes: créditos, cron diário, teste manual *(só faz sentido com ≥25 conversas)*
- [ ] Trocar a `service_role key` do Hermes pelo role restrito
      ([`role-hermes.sql`](30-integracoes/supabase/role-hermes.sql))
- [ ] Rotacionar a `service_role key` *(ficou no histórico de chat do Hermes)*
- [ ] Merge do PR #16
- [ ] Links `wa.me` com `[ref:lp]` / `[ref:tiktok]` na LP e no criativo

---

## Caminho crítico

```
verificação Meta (dias, fora do seu controle)
        └─> token + phone_number_id ─> placeholders ─> ativar ─> teste real
fatos operacionais (Grupo A)  ─────────────────────────┘
passivo de compliance (Grupo D) ───────────────────────┘
```

**Só o primeiro item não depende de você.** Dispare a verificação da empresa
hoje; enquanto ela corre, o Grupo A e o Grupo D podem ser resolvidos e o
ensaio do Bloco 3 pode ser rodado inteiro.

O erro caro seria a verificação sair, você ligar o anúncio, e descobrir aí que
o agente não sabe dizer o que a pessoa recebe.
