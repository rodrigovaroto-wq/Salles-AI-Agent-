# Checklist — O que falta antes do primeiro lead real

Estado em 2026-07-26. A ordem dos blocos é de risco, não de esforço: o Bloco 1
é o que **causa dano** se você ligar os anúncios sem resolver; o Bloco 2 é
trabalho mecânico que já está pronto para executar.

Resumo honesto: **o agente está tecnicamente pronto e comercialmente não.** O
que falta não é código — é informação de negócio e limpeza de passivo.

---

## 🔴 Bloco 1 — Bloqueia lead real

### 1.1 Passivo de compliance ✅ resolvido

Saneado em 2026-07-26. O que saiu:

| Arquivo | Removido |
|---|---|
| `provas/testemunhos.md` | 6 estatísticas e 4 testemunhos fabricados, e as fórmulas para produzir mais. Virou política de coleta + registro (vazio) |
| `gatilhos/gatilhos-espirituais.md` | Revelação divina afirmada, recado atribuído ao Padre Pio, "as vagas fecham hoje", medo de "brecha espiritual" |
| `gatilhos/gatilhos-idoso.md` | 5 frases: cura de origem espiritual, proteção garantida pela assinatura, urgência inexistente, número não verificado |
| `provas/prova-social-avancada.md` | Exemplos inventados; coleta ganhou consentimento e pergunta que não induz |

Ficou o que era legítimo: versículos, orientação de linguagem, o framework de
prova social. Confirmado que nenhum destes arquivos chega ao prompt ao vivo —
o agente carrega apenas `objetivo`, `compliance` e `objecoes`.

**Enquanto a tabela de testemunhos estiver vazia, o agente não cita nenhum
caso de cliente.** A alavanca disponível no lugar é a garantia de 7 dias, que
reduz risco percebido sem afirmar nada sobre terceiros.

### 1.2 Preencher o conteúdo de entrega 🔴

A entrega pelo WhatsApp **já está construída** e o upsell de 10 minutos foi
removido. O que falta é o conteúdo: os links e instruções reais de acesso.

O texto de cada produto mora em `produtos.entrega_texto` — no banco, não no
workflow, para o Padre Frei poder trocar um áudio ou o link do grupo sem
republicar nada.

- [ ] Rodar [`supabase/migracao-entrega.sql`](30-integracoes/supabase/migracao-entrega.sql)
- [ ] Preencher `entrega_texto` dos **4** produtos (bloco comentado no fim do arquivo)

```sql
select produto_id, nome,
       case when entrega_texto is null then '❌ FALTA' else '✅ ok' end as entrega
from produtos where ativo order by ordem;
```

**Enquanto estiver vazio, a venda não quebra** — a cliente recebe "seu acesso
chega em seguida por este WhatsApp" e você é alertado no seu número para
entregar na mão. Mas isso é rede de segurança, não operação: com anúncio
ligado, vira trabalho manual a cada venda.

### 1.3 Fatos operacionais — o que ainda falta (Grupo A)

**Resolvidos** ✅ — já aplicados no playbook e no SQL do prompt:
entrega (automática, e-mail + WhatsApp), garantia (**7 dias**, CDC art. 49),
formato da Comunidade, formato do Contato com o Padre (mensagens num canal,
**não** é atendimento individual).

Restam 5 pontos `[confirmar]`, agora de detalhe e não de essência:

- [ ] **Conteúdo de cada item** — quantas orações, quantos minutos de áudio,
      quantas páginas, em que plataforma se acessa
- [ ] **Canal da Comunidade** — WhatsApp ou Telegram?
- [ ] **Frequência** das mensagens do padre e dos conteúdos da comunidade

### 1.4 Identidade ✅ resolvida

O Padre Frei é sacerdote real: gravou as orações e os áudios, as mensagens do
canal são dele e é ele quem conduz a comunidade. O agente já nomeia o padre
como quem conduz o trabalho (seção J) — resposta forte num público com radar
de golpe ligado.

### 1.5 WhatsApp / Meta

- [ ] Verificação da empresa aprovada ⏳ *(o único ponto onde o relógio corre por terceiro — comece já)*
- [ ] App criado e vinculado à empresa
- [ ] WABA de produção + número registrado
- [ ] Token permanente (System User, escopos `messaging` + `management`, sem expiração)
- [ ] `phone_number_id` anotado
- [ ] Webhook verificado com campo `messages` marcado
- [ ] Template de follow-up aprovado — 1 variável, `pt_BR`, categoria Utilitário

### 1.6 OpenAI com saldo

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
- [ ] **A entrega chega logo após o pagamento**, com o conteúdo real de cada
      produto comprado, e fica registrada em `conversas`
- [ ] Com `entrega_texto` vazio de propósito: a cliente recebe o aviso de
      "acesso em seguida" **e** você recebe o alerta no seu número
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
verificação Meta (dias, fora do seu controle) ──> token + phone_number_id
                                                        │
conteúdo de entrega (você preenche) ────────────────────┼──> ativar ──> teste real
                                                        │
saldo na OpenAI ────────────────────────────────────────┘
```

**Só o primeiro depende de terceiro.** Dispare a verificação da empresa hoje;
enquanto ela corre, preencha o `entrega_texto` dos 4 produtos, confirme o
saldo da OpenAI e rode o ensaio do Bloco 3 inteiro — ele não precisa de
WhatsApp nenhum.

Compliance e identidade estão resolvidos. O que sobrou de bloqueante é
operacional, não de conteúdo.
