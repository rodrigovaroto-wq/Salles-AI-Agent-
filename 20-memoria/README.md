# 20 — Memória Operacional

Esta é a camada que **não existia** antes e é o coração do "agente que aprende"
descrito no README do projeto e nos blocos CONTEXT6 / CONTEXT7 do
[`../00-nucleo/objetivo.md`](../00-nucleo/objetivo.md).

## O que é
Um conjunto de estruturas de dados que o agente **grava e lê a cada conversa**.
É o que transforma o agente de um "respondedor" em um sistema que:

- lembra de cada lead (perfil, dores, objeções, origem);
- registra o que funcionou e o que travou a venda;
- alimenta a análise periódica de performance;
- gera hipóteses de melhoria com base em dados reais, não intuição.

## Como funciona na prática
Cada conversa passa por dois momentos de memória:

1. **Leitura (início da conversa):** o agente busca se o número/lead já existe.
   Se existir, carrega o histórico e o perfil antes de responder.
2. **Escrita (durante e ao fim):** o agente atualiza o registro do lead e grava
   os eventos da conversa (etapa do funil, objeções, resultado).

Tecnicamente isso vive num banco de dados (ex.: Postgres, Supabase, Airtable ou
Google Sheets no começo). Os arquivos abaixo definem **o formato** desses dados —
são o contrato entre o agente e o banco.

## Arquivos desta camada
| Arquivo | Papel |
|---|---|
| [`schema-lead.md`](schema-lead.md) | Ficha permanente de cada lead (1 registro por pessoa) |
| [`schema-conversa.md`](schema-conversa.md) | Eventos de cada conversa (N registros por lead) |
| [`schema-aprendizado.md`](schema-aprendizado.md) | Agregados para análise de performance e melhoria do modelo |

## Regra de ouro
A memória só tem valor se for **preenchida com dados reais**. Nunca registrar
resultados ou perfis inventados — isso contamina o aprendizado e leva o agente a
otimizar na direção errada. Ver regras éticas em CONTEXT8 do núcleo.
