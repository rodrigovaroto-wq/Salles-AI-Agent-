# Integração BlackCat

Gateway de pagamento usado no Caminho A (venda assistida via WhatsApp) e em
qualquer link enviado pelo agente. Documentação oficial:
https://docs.blackcatoficial.com/

## Por que o BlackCat resolve o fluxo inteiro
- Aceita **múltiplos itens numa única transação** (`items[]`) → um só link já
  cobre principal + order bumps + desconto, sem precisar combinar entre
  plataformas diferentes.
- Aceita **`externalRef`** — é aqui que entra o `wa_id` do lead, o elo que
  conecta o pagamento de volta à conversa e à memória.
- Aceita **`metadata`** e campos **UTM** (`utm_source`, `utm_campaign`,
  `utm_content`...), que retornam no webhook e alimentam os campos
  `origem_*` de `../../20-memoria/schema-lead.md` de graça.
- Notifica eventos via **`postbackUrl`** (webhook).

## Arquivos desta pasta
| Arquivo | Conteúdo |
|---|---|
| [`eventos-webhook.md`](eventos-webhook.md) | Os 3 eventos e o que cada um dispara no workflow |
| [`criacao-transacao.md`](criacao-transacao.md) | Como montar o `items[]` a partir do catálogo, com o `externalRef` e desconto |

## Credenciais
A conta BlackCat já existe e as integrações são possíveis (confirmado pelo
dono do projeto). API Key e `postbackUrl` de produção **não devem ir para este
repositório** — ficam como variável de ambiente no orquestrador (n8n).
