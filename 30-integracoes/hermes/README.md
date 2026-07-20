# Integração Hermes Agent — Camada de Inteligência

O Hermes ocupa um papel específico e deliberadamente limitado neste sistema:
**analista assíncrono, nunca vendedor**. Ele não conversa com leads, não gera
links de pagamento, não tem acesso de escrita direto ao `00-nucleo/` ou
`10-skills/`. Ele lê o histórico acumulado em `../../20-memoria/` e produz
sugestões — nunca aplica mudanças sozinho.

## Por que essa fronteira existe
Ver a discussão completa registrada nas decisões do projeto: um otimizador
que persegue apenas "taxa de conversão" e tem liberdade de reescrever o
próprio comportamento sem revisão converge, de forma previsível, para as
táticas mais eficazes disponíveis nos dados — e várias das táticas mapeadas em
`../../10-skills/CONFORMIDADE.md` (testemunho fabricado, promessa de cura,
escassez falsa) são categoricamente as mais "eficientes" nesse sentido. Sem um
freio antes da produção, o sistema as redescobre. O gate humano não é
burocracia — é o único ponto de controle que impede uma sugestão dessas de
virar mensagem real antes de alguém revisar.

## Os documentos desta pasta

| Arquivo | Papel |
|---|---|
| [`ciclo-aprendizado.md`](ciclo-aprendizado.md) | O fluxo completo: dados → hipótese → classificação de risco → fila → aprovação → aplicação |
| [`filtro-conformidade.md`](filtro-conformidade.md) | Classificador que rotula o risco de cada sugestão — não descarta nada, só orienta a triagem |
| [`fila-aprovacao.md`](fila-aprovacao.md) | Schema da fila de sugestões pendentes e o formato de decisão |
| [`configuracao.md`](configuracao.md) | Decisões operacionais: VPS, cadência diária, volume mínimo, LLM, e a aplicação automática pós-aprovação |
| [`deploy-vps.md`](deploy-vps.md) | Passo a passo de deploy: Docker, `.env`, volume de leitura do repositório, e a tarefa diária em linguagem natural (`hermes cron create`) |

## Regra de ouro
Nenhuma sugestão do Hermes se torna comportamento ativo do agente sem
aprovação humana explícita. Sem exceção — inclusive as de risco alto. Depois
do seu "aprovar", a aplicação é **automatizada pelo n8n** (você não edita
arquivo à mão), mas o toque de aprovação nunca é pulado. O classificador de
conformidade **não descarta** nada sozinho: toda a triagem é humana.
