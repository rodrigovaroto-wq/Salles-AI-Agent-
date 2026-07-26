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

A Meta verifica o webhook com uma requisição **GET** contendo `hub.mode`,
`hub.verify_token` e `hub.challenge`, e só aceita a inscrição se o servidor
devolver **o `hub.challenge` cru** (texto puro, sem JSON em volta).

Isso é atendido por três nós dedicados em `agente-vendas.json` —
`Handshake Meta (GET)` → `Validar verify token` → `Devolver challenge`. Eles
usam o **mesmo path** do `WhatsApp IN` (`whatsapp-in`) com método GET; o n8n
registra webhooks por par (path, método), então os dois convivem. Nenhuma
mensagem de lead passa por esse caminho — ele só existe para o handshake.

1. Escolha a string do verify token (ex. `salles-verify-2026`) e substitua
   `<<WHATSAPP_VERIFY_TOKEN>>` no nó `Validar verify token` pela string
   escolhida. **Salve e ative o workflow** — webhook em modo de teste só
   responde por alguns minutos, e a Meta recusa se não responder.
2. No app, `WhatsApp` → `Configuração` → `Webhook` → `Editar`.
3. **Callback URL:** `https://salles-ai-agent.pikapod.net/webhook/whatsapp-in`
4. **Verify Token:** a mesma string do passo 1 — precisa bater exatamente, o
   nó recusa o handshake se divergir (é o que impede um terceiro de apontar o
   próprio app da Meta para o seu webhook).
5. Clique `Verificar e salvar`.
6. Em `Campos do Webhook`, marque **`messages`** (é o que traz as mensagens
   recebidas). Não precisa dos outros campos para este projeto.

**Se a Meta recusar**, teste o handshake direto antes de mexer no painel dela:

```bash
curl "https://salles-ai-agent.pikapod.net/webhook/whatsapp-in?hub.mode=subscribe&hub.verify_token=<SUA_STRING>&hub.challenge=12345"
```

Tem que responder exatamente `12345`, sem aspas e sem chaves. Se vier vazio ou
404, o workflow não está ativo. Se vier erro de token, a string não bate.

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
3. Idioma: **Português (BR)** — o workflow envia `language.code = pt_BR`, e a
   Meta rejeita o envio se o template não existir nesse idioma exato.
4. **Estrutura obrigatória: exatamente uma variável `{{1}}`, no corpo, que é o
   nome do lead.** O `followup-24h.json` envia um único parâmetro de body
   (`text: $json.nome`) — um template com zero ou duas variáveis faz o envio
   falhar em runtime, mesmo aprovado.
5. Texto sugerido (dentro de `../../00-nucleo/compliance-e-etica.md`: sem
   urgência falsa, sem promessa, sem prova social):

   > Olá {{1}}, ainda está por aqui? Fico à disposição para tirar qualquer
   > dúvida sobre a Oração Sagrada. 🙏

   Se preferir outro texto, mantenha as três propriedades: **uma** variável,
   nenhum prazo/limite inventado, e nenhuma afirmação sobre o que o produto
   faz. Um texto que promete resultado derruba a qualidade da conta (seção 10)
   além de violar o compliance.
6. Envie para aprovação. Prazo típico: minutos a ~1 dia útil.
7. Aprovado, anote o **nome exato** do template — é ele que substitui
   `<<WHATSAPP_TEMPLATE_NAME>>` no `followup-24h.json`.

> ⚠️ O nome do produto no texto acima é **Oração Sagrada** (R$ 22,90), como no
> `../catalogo-produtos.md`. Uma versão anterior deste guia trazia "Oração de
> São Bento" no exemplo — produto que não existe no catálogo. Se você já
> submeteu um template com esse nome, corrija antes de usar: o follow-up
> mencionaria algo que a lead nunca comprou.

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
- [ ] `<<WHATSAPP_VERIFY_TOKEN>>` substituído no nó `Validar verify token` e o workflow **ativo**
- [ ] Handshake respondendo o challenge cru (teste via `curl` da seção 6)
- [ ] Webhook apontando para `/webhook/whatsapp-in` do n8n, verificado, campo `messages` marcado
- [ ] Teste de envio via `curl` funcionando
- [ ] Links `wa.me` com marcador `[ref:lp]` / `[ref:tiktok]` prontos para a LP e o criativo do TikTok
- [ ] Template de follow-up pós-24h submetido — 1 variável, pt_BR, categoria Utilitário

## Os 4 valores que você me passa quando tiver

Nenhum é segredo (pode vir no chat) — eu substituo em todos os arquivos de uma
vez e revalido a integridade dos workflows:

| Placeholder | Onde você acha |
|---|---|
| `<<WHATSAPP_PHONE_NUMBER_ID>>` | `WhatsApp` → `Configuração da API` (seção 5) |
| `<<WHATSAPP_TEMPLATE_NAME>>` | Nome do template aprovado (seção 9) |
| `<<RODRIGO_WA_NUMBER>>` | Seu número, formato `55DDDNUMERO` |
| `<<WHATSAPP_VERIFY_TOKEN>>` | A string que você inventou (seção 6) |

O que **não** deve vir no chat: o token permanente da Meta, a `service_role
key` do Supabase, a chave da OpenAI ou do BlackCat, o PAT do GitHub. Esses vão
direto para as Credentials do n8n.
