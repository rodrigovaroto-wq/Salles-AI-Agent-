# Salles-AI-Agent-

Agente de IA focado na venda de infoprodutos via WhatsApp. Sua memória é
atualizada conforme avança em conversas com leads e cria seu próprio banco de
dados, se otimizando ao analisar chats onde a venda foi concluída (referência) e
chats onde a venda foi declinada (aprendizado).

---

## Estrutura do repositório

O projeto é organizado nas **quatro camadas de um agente de IA**:

```
00-nucleo/         → CONTEXTO DE EXECUÇÃO (system prompt, sempre ativo)
                      quem o agente é, missão, processo de venda, regras éticas
10-skills/         → BASE DE CONHECIMENTO (consultada sob demanda)
                      copy, gatilhos, ofertas, provas, aquisição, sequências
20-memoria/        → MEMÓRIA OPERACIONAL (cresce a cada conversa)
                      schema de lead, de conversa e de aprendizado
30-integracoes/    → FERRAMENTAS (tools) — o encanamento real
                      catálogo de produtos, integração BlackCat, workflow lead→cliente
```

| Camada | Analogia | Detalhes |
|---|---|---|
| [`00-nucleo/`](00-nucleo/) | A constituição do agente | [ver README](00-nucleo/README.md) |
| [`10-skills/`](10-skills/) | Os livros na estante | [ver README](10-skills/README.md) · [conformidade](10-skills/CONFORMIDADE.md) |
| [`20-memoria/`](20-memoria/) | O caderno de anotações | [ver README](20-memoria/README.md) |
| [`30-integracoes/`](30-integracoes/) | As mãos do agente | [catálogo](30-integracoes/catalogo-produtos.md) · [BlackCat](30-integracoes/blackcat/) · [workflow](30-integracoes/workflow-lead-a-cliente.md) · [ciclo de aprendizado (Hermes)](30-integracoes/hermes/) |

## Stack definida
WhatsApp Cloud API (oficial) · OpenAI · orquestrador n8n (tempo real) ·
Hermes Agent (análise assíncrona) · checkout BlackCat · memória em Supabase.

## Ciclo de aprendizado
O agente aprende com as próprias conversas: o Hermes analisa os dados
acumulados e gera sugestões de melhoria, mas **nenhuma sugestão vira
comportamento ativo sem passar por um filtro automático de conformidade e,
em seguida, por aprovação humana explícita**. Ver
[`30-integracoes/hermes/ciclo-aprendizado.md`](30-integracoes/hermes/ciclo-aprendizado.md).

## Governança
O bloco **CONTEXT8 (Regras Éticas)** em [`00-nucleo/objetivo.md`](00-nucleo/objetivo.md)
é a autoridade máxima do projeto. Sempre que uma skill conflitar com ele, o núcleo
vence. O mapa do que precisa ser corrigido está em
[`10-skills/CONFORMIDADE.md`](10-skills/CONFORMIDADE.md).
