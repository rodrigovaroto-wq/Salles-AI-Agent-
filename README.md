# Salles-AI-Agent-

Agente de IA focado na venda de infoprodutos via WhatsApp. Sua memória é
atualizada conforme avança em conversas com leads e cria seu próprio banco de
dados, se otimizando ao analisar chats onde a venda foi concluída (referência) e
chats onde a venda foi declinada (aprendizado).

---

## Estrutura do repositório

O projeto é organizado nas **três camadas de um agente de IA**:

```
00-nucleo/     → CONTEXTO DE EXECUÇÃO (system prompt, sempre ativo)
                 quem o agente é, missão, processo de venda, regras éticas
10-skills/     → BASE DE CONHECIMENTO (consultada sob demanda)
                 copy, gatilhos, ofertas, provas, aquisição, sequências
20-memoria/    → MEMÓRIA OPERACIONAL (cresce a cada conversa)
                 schema de lead, de conversa e de aprendizado
```

| Camada | Analogia | Detalhes |
|---|---|---|
| [`00-nucleo/`](00-nucleo/) | A constituição do agente | [ver README](00-nucleo/README.md) |
| [`10-skills/`](10-skills/) | Os livros na estante | [ver README](10-skills/README.md) · [conformidade](10-skills/CONFORMIDADE.md) |
| [`20-memoria/`](20-memoria/) | O caderno de anotações | [ver README](20-memoria/README.md) |

Falta ainda a 4ª camada — **Ferramentas (tools)**: integração com WhatsApp,
link de pagamento e o banco de dados de memória. Será definida na etapa de stack.

## Governança
O bloco **CONTEXT8 (Regras Éticas)** em [`00-nucleo/objetivo.md`](00-nucleo/objetivo.md)
é a autoridade máxima do projeto. Sempre que uma skill conflitar com ele, o núcleo
vence. O mapa do que precisa ser corrigido está em
[`10-skills/CONFORMIDADE.md`](10-skills/CONFORMIDADE.md).
