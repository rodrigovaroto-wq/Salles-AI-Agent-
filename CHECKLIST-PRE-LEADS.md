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

### 1.2 Fatos operacionais — os `[confirmar]` (Grupo A)

Hoje o agente sabe **nome e preço** de cada produto e mais nada. Existem **10
pontos** no playbook onde ele precisa responder "deixa eu confirmar isso pra
você" em vez de vender.

| O que a lead pergunta | Hoje o agente responde | Custo |
|---|---|---|
| "O que vem na Oração Sagrada?" | evasiva | **quem não entende o que recebe, não compra** |
| "Como recebo depois de pagar?" | evasiva | maior medo do público: pagar e não receber |
| "Tem garantia?" | evasiva | garantia real é alavanca forte de conversão |
| "O padre responde mesmo?" | evasiva | expectativa errada → reclamação/chargeback |
| "A comunidade é ativa?" | evasiva | idem |
| "Quem está por trás disso?" | evasiva | público com radar de golpe ligado |

- [ ] **Oração Sagrada** (R$22,90) — o que é, o que a pessoa recebe, formato
- [ ] **Oração em Áudio** (R$13,90) — duração, quantas, voz de quem
- [ ] **Comunidade** (R$44,90) — canal, único ou recorrente, o que acontece lá
- [ ] **Contato com o Padre** (R$19,90) — pessoa real ou conteúdo gravado, frequência
- [ ] **Entrega** — como e em quanto tempo chega após o PIX confirmado
- [ ] **Garantia** — existe? prazo? condição?
- [ ] **Identidade** — quem responde publicamente pela operação

Me passe em texto corrido; eu transformo cada `[confirmar]` em resposta de
venda real e regenero o SQL do prompt.

> ⚠️ Se algum produto **não tem** entrega definida ainda, isso não é um vazio
> de documentação — é um produto que não deveria estar à venda.

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
