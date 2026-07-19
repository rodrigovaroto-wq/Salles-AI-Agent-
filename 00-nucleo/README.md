# 00 — Núcleo (Contexto de Execução)

Esta camada é a **constituição do agente**. Tudo aqui fica *sempre carregado* no
system prompt e vale para toda e qualquer conversa. Deve ser **enxuto e estável** —
mudanças aqui mudam o comportamento do agente inteiro.

## Arquivos

| Arquivo | Papel |
|---|---|
| [`objetivo.md`](objetivo.md) | Espinha dorsal: identidade, objetivos, métricas, processo de venda (7 etapas), regras éticas, aprendizado. **Documento mais importante do projeto.** |
| [`tom-de-voz.md`](tom-de-voz.md) | Como o agente fala (persona "Lilith") |
| [`jornada-do-lead.md`](jornada-do-lead.md) | As 5 fases do funil — onde o lead está |
| [`ciclos-emocionais.md`](ciclos-emocionais.md) | Lógica de roteamento: qual mensagem para qual estado emocional |
| [`ecossistema-de-confianca.md`](ecossistema-de-confianca.md) | Princípios de confiança que sustentam a conversão de longo prazo |

## Como o núcleo se relaciona com as outras camadas
- O núcleo **decide** e **conduz**. Quando precisa de conhecimento especializado
  (uma técnica de copy, um mapa de objeções, o roteiro da VSL), ele **consulta**
  a camada `../10-skills/` — não guarda tudo dentro de si.
- O núcleo **lê e grava** na camada `../20-memoria/` a cada conversa.

## Ponto de atenção (governança ética)
As restrições de conduta do agente vivem num arquivo único e são a autoridade
máxima do projeto: [`compliance-e-etica.md`](compliance-e-etica.md). **Qualquer
skill que conflite com ele deve ser corrigida, não seguida.** O mapa do que
precisa de ajuste está em `../10-skills/CONFORMIDADE.md`.
