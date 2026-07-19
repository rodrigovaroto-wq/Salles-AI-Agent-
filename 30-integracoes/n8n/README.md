# n8n — Orquestrador (PikaPods)

Deploy e credenciais. Como você já domina o n8n, isto foca no que é específico
deste projeto: quais credenciais guardar e os endpoints de webhook que as
próximas etapas (WhatsApp, BlackCat) vão apontar para cá.

## Deploy

1. [pikapods.com](https://www.pikapods.com) → catálogo → **n8n** → Deploy.
2. Anote a URL do pod (ex.: `https://SEUPOD.pikapods.com`) — é a base de todos
   os webhooks abaixo.
3. Login inicial → criar seu usuário admin do n8n.

## Credenciais a cadastrar (Settings → Credentials)

| Credencial | De onde vem | Usada em |
|---|---|---|
| `supabase` | URL + `service_role key` (`../supabase/README.md`) | todos os gatilhos |
| `openai` | API key da OpenAI | Gatilho 1 (agente) e Hermes (se disparado via n8n) |
| `whatsapp_cloud_api` | Token permanente + phone-number-id (etapa 3) | Gatilhos 1 e 4 |
| `blackcat` | API key BlackCat (etapa 4) | geração de link + webhooks |

Guardar só como Credential do n8n — nunca em texto solto num node ou commitado
no repositório.

## Endpoints de webhook a criar (nomes de referência)

Cada um vira um node **Webhook** no n8n. Os nomes de path abaixo são os que as
próximas etapas vão usar para configurar o lado de fora (Meta, BlackCat):

| Path sugerido | Gatilho | Consome de |
|---|---|---|
| `/webhook/whatsapp-in` | Gatilho 1 — mensagem recebida | WhatsApp Cloud API |
| `/webhook/blackcat` | Gatilhos 2 e 3 — `transaction.*` | BlackCat `postbackUrl` |

URLs completas ficam `https://SEUPOD.pikapods.com/webhook/whatsapp-in` e
`.../webhook/blackcat` — guarde-as, são usadas nas etapas 3 e 4.

## Workflows a montar (mapeados no `workflow-lead-a-cliente.md`)

| Workflow no n8n | Gatilho | Tipo de trigger |
|---|---|---|
| `agente-vendas` | Gatilho 1 | Webhook (`/whatsapp-in`) |
| `pagamento-blackcat` | Gatilhos 2 e 3 | Webhook (`/blackcat`) |
| `recuperacao-2h` | dentro do Gatilho 3 | Wait node (2h) após checkout_abandonado |
| `followup-24h` | Gatilho 4 | Cron (ex.: a cada hora, filtra >24h) |
| `hermes-diario` | Gatilho 5 | Cron diário (dispara/lê o Hermes) |
| `fila-aprovacao` | ciclo Hermes | Manual/Form trigger — você aprova/rejeita |

Cada um é detalhado nas próximas etapas do setup (`../workflow-lead-a-cliente.md`
tem a lógica completa; aqui só o esqueleto de infraestrutura).

## Checklist desta etapa
- [ ] Pod do n8n no ar (PikaPods)
- [ ] Credenciais `supabase` e `openai` cadastradas (já dá para testar conexão)
- [ ] Os dois webhooks (`whatsapp-in`, `blackcat`) criados como nodes vazios,
      só para ter a URL pronta para as próximas etapas
