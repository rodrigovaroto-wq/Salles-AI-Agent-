# WhatsApp Business Cloud API — Passo a Passo Detalhado

Esta é a etapa mais burocrática do setup porque passa pela verificação da Meta.
Ela tem prazo (a verificação de empresa pode levar de horas a poucos dias), então
vale começar por aqui e seguir com as outras etapas em paralelo enquanto espera.

Nomenclatura da Meta muda com frequência — se algum menu tiver nome diferente do
descrito aqui, use a busca dentro do Business Suite pelo termo em **negrito**.

---

## 1. Meta Business Manager

1. Acesse [business.facebook.com](https://business.facebook.com).
2. Se ainda não tem uma **Empresa** (Business Account) para a operação, crie uma:
   `Configurações da Empresa` → `Criar conta comercial`. Preencha nome legal,
   e-mail e o site (a LP de pagamento serve).
3. **Verificação de empresa** (`Configurações da Empresa` → `Segurança` →
   `Verificação da empresa`): a Meta pede CNPJ e um documento comprobatório
   (contrato social, cartão CNPJ). Envie e aguarde — isso desbloqueia o envio
   de mensagens em volume maior depois.

---

## 2. Criar o App e adicionar o produto WhatsApp

1. [developers.facebook.com](https://developers.facebook.com) → `Meus Apps` →
   `Criar App` → tipo **Negócios** (Business).
2. Vincule o app à Empresa criada no passo 1.
3. No painel do app, `Adicionar Produto` → **WhatsApp** → `Configurar`.
4. Isso já cria uma **WABA de teste** automaticamente — não use ela para
   produção, é só para os primeiros testes com número de teste da Meta.

---

## 3. Criar a WABA de produção e registrar seu número

1. Ainda em `WhatsApp` → `Configuração da API`, troque da WABA de teste para
   **Criar nova conta do WhatsApp Business** (ou vincule uma existente, se já
   tiver).
2. Adicione o **número de telefone** que vai ser o do agente.
   - **Importante:** esse número **não pode estar ativo no app comum do
     WhatsApp** no momento do cadastro — ele será migrado para a Cloud API.
   - Verificação por SMS ou chamada de voz, código de 6 dígitos.
3. Preencha o **perfil comercial** (nome exibido, categoria do negócio, foto,
   descrição) — isso aparece para o lead na conversa.

---

## 4. Gerar o token de acesso permanente (System User)

O token que aparece na tela de teste **expira em 24h** — não serve para
produção. Gere um permanente:

1. `Configurações da Empresa` → `Usuários` → `Usuários do sistema` →
   `Adicionar` → crie um usuário do tipo **Admin**, nome ex. `agente-vendas-bot`.
2. `Atribuir ativos` → selecione o **App** criado no passo 2 e a **WABA** do
   passo 3 → dê permissão total.
3. `Gerar novo token` → selecione o App → marque os escopos:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`
4. Expiração: **Nunca**. Copie o token — ele só aparece uma vez.
5. Guarde esse token como a credencial `whatsapp_cloud_api` no n8n (ver
   `../n8n/README.md`).

## 5. Anotar os IDs que a API usa

Em `WhatsApp` → `Configuração da API`, anote:
- **Phone number ID** (não é o número em si, é um ID interno)
- **WABA ID**

Esses dois + o token do passo 4 são o que o n8n usa para enviar mensagem
(`POST https://graph.facebook.com/v20.0/{phone-number-id}/messages`).

---

## 6. Configurar o Webhook (conecta ao n8n)

Isto liga o WhatsApp ao node `/webhook/whatsapp-in` criado no n8n (`../n8n/README.md`).

1. No app, `WhatsApp` → `Configuração` → `Webhook` → `Editar`.
2. **Callback URL:** a URL pública do n8n, ex.
   `https://SEUPOD.pikapods.com/webhook/whatsapp-in`
3. **Verify Token:** invente uma string (ex. `salles-verify-2026`) e cadastre a
   **mesma string** no node de webhook do n8n (ele precisa responder ao
   *handshake* GET da Meta ecoando esse token).
4. Clique `Verificar e salvar`. Se o n8n não responder corretamente ao
   handshake, a Meta recusa — confira se o node do n8n já está publicado
   (ativo), não só salvo em modo de teste.
5. Em `Campos do Webhook`, marque **`messages`** (é o que traz as mensagens
   recebidas). Não precisa dos outros campos para este projeto.

---

## 7. Teste de envio (antes de plugar no n8n)

Confirme que token e phone-number-id funcionam com um teste manual:

```bash
curl -X POST "https://graph.facebook.com/v20.0/<PHONE_NUMBER_ID>/messages" \
  -H "Authorization: Bearer <TOKEN_PERMANENTE>" \
  -H "Content-Type: application/json" \
  -d '{
    "messaging_product": "whatsapp",
    "to": "<SEU_NUMERO_DE_TESTE>",
    "type": "text",
    "text": { "body": "Teste do agente de vendas" }
  }'
```

Se a mensagem chegar, o par token + phone-number-id está correto — pode
cadastrar no n8n com confiança.

---

## 8. Links `wa.me` com marcador de origem (para o Gatilho 1 saber de onde veio o lead)

O agente precisa diferenciar **LP (Meta, quente)** de **TikTok (frio/morno)**.
Como os dois caminhos terminam no mesmo WhatsApp, a forma prática é um texto
pré-preenchido diferente por canal:

```
LP (Meta):    https://wa.me/<numero>?text=Quero%20garantir%20a%20minha%20oracao%20%5Bref%3Alp%5D
TikTok:       https://wa.me/<numero>?text=Vi%20seu%20video%20e%20quero%20saber%20mais%20%5Bref%3Atiktok%5D
```

O texto decodificado termina em `[ref:lp]` ou `[ref:tiktok]`. No Gatilho 1, o
n8n lê a primeira mensagem recebida e verifica esse marcador para decidir o
branch (venda assistida vs. qualificação do zero).

**Limitação honesta:** o lead pode editar o texto antes de enviar e apagar o
marcador. Por isso o Gatilho 1 deve ter um **padrão seguro**: se o marcador não
for encontrado, tratar como **TikTok** (qualifica do zero) — é o caminho mais
conservador, nunca assume intenção de compra sem confirmação.

**Alternativa mais robusta (opcional, avaliar depois):** anúncios do tipo
*Click to WhatsApp* no Meta Ads Manager anexam automaticamente um objeto
`referral` no payload do webhook (com a origem do anúncio/criativo), sem
depender do texto. Vale considerar migrar o canal Meta para esse formato de
anúncio no futuro — é mais confiável que o marcador de texto.

---

## 9. Template de follow-up pós-24h (Gatilho 4)

Fora da janela de 24h, só dá para reabrir a conversa com um **template
aprovado** pela Meta.

1. `WhatsApp` → `Gerenciador de Modelos` → `Criar Modelo`.
2. Categoria: **Utilitário** (não Marketing — utilitário tem aprovação mais
   rápida e é o que se aplica a "retomar uma conversa em andamento sobre uma
   compra"). Se a Meta reclassificar como Marketing, ok, mas comece testando
   Utilitário.
3. Redija o texto seguindo `../../00-nucleo/compliance-e-etica.md` — sem
   urgência falsa, sem promessa. Ex.:
   > Olá {{1}}, ainda está por aqui? Fico à disposição para tirar qualquer
   > dúvida sobre a Oração de São Bento. 🙏
4. Envie para aprovação. Prazo típico: minutos a ~1 dia útil.
5. Uma vez aprovado, o n8n dispara esse template pelo endpoint de templates
   (`type: template`) no Gatilho 4.

---

## 10. Limites de envio (Tier) — atenção para não travar a operação

Contas novas começam no **Tier 1**: até 250 clientes únicos contatados por
mensagem ativa (fora da janela de 24h) em 24h. O limite sobe automaticamente
conforme volume e **qualidade** (taxa de bloqueio/denúncia baixa). Mensagens
com prova social fabricada, escassez falsa etc. derrubam a qualidade e travam
o Tier — mais um motivo pelo qual `compliance-e-etica.md` protege a operação
em produção, não só eticamente.

---

## Checklist desta etapa
- [ ] Empresa verificada no Meta Business Manager
- [ ] App criado, produto WhatsApp adicionado
- [ ] WABA de produção criada e número registrado (não ativo no WhatsApp comum)
- [ ] Token permanente gerado via System User, com os 2 escopos corretos
- [ ] Phone number ID e WABA ID anotados
- [ ] Webhook apontando para `/webhook/whatsapp-in` do n8n, verificado, campo `messages` marcado
- [ ] Teste de envio via `curl` funcionando
- [ ] Links `wa.me` com marcador `[ref:lp]` / `[ref:tiktok]` prontos para a LP e o criativo do TikTok
- [ ] Template de follow-up pós-24h submetido para aprovação
