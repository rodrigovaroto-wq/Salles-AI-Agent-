# Configuração do Hermes

Decisões operacionais fechadas para a camada de inteligência (o Hermes como
analista assíncrono). Complementa `ciclo-aprendizado.md` (o fluxo) e
`fila-aprovacao.md` (o schema da fila).

## Decisões

| # | Item | Definição |
|---|---|---|
| 1 | **Onde roda** | VPS barata (ex.: PikaPods ou similar). Como a análise é diária em lote, o processo **não precisa ficar ligado 24/7** — é disparado 1x/dia, roda e encerra. |
| 2 | **Cadência** | Diária. |
| 3 | **Volume mínimo** | Só analisa se houver **≥ 25 conversas novas** com desfecho registrado desde o último ciclo. Abaixo disso, pula o dia (evita otimizar em cima de ruído). |
| 4 | **LLM (cérebro da análise)** | **OpenAI** (mesma conta do agente de vendas), modelo forte de raciocínio. Custo irrelevante por ser 1x/dia; ganha em simplicidade e qualidade. |
| 5 | **Acesso aos dados** | Leitura no Supabase (`../../20-memoria/`). O Hermes **só lê** os dados de conversa/aprendizado — não escreve neles. |
| 6 | **Entrega da fila** | Via n8n — a fila de sugestões (`fila-aprovacao.md`) é apresentada e decidida dentro do n8n. |
| 7 | **Aplicação** | Após a aprovação humana, a mudança é aplicada **pelo sistema** (n8n), sem edição manual. Ver seção "Aplicação automática pós-aprovação". |

## Correção de arquitetura (vs. versão anterior deste documento)
O Hermes tem **cron nativo embutido** (não precisa do n8n para ser disparado).
Ele se agenda sozinho na VPS, lê o Supabase direto (credencial própria,
somente leitura) e grava direto na tabela `fila_sugestoes`. O n8n **não
dispara o Hermes** — o papel do n8n fica só na ponta humana: notificar a fila
e aplicar o que for aprovado (ver `../n8n/workflows/`).

## Como o dia do Hermes funciona (passo a passo)

1. **Cron nativo do Hermes** (interno, na VPS) dispara a análise 1x/dia.
2. Hermes verifica: houve **≥ 25 conversas novas** desde o último ciclo?
   - Não → encerra, tenta de novo no dia seguinte.
   - Sim → segue.
3. Hermes lê (somente leitura) `schema-conversa.md` e `schema-aprendizado.md`
   no Supabase.
4. Chama a **OpenAI** para analisar padrões e gerar hipóteses `[SUGESTÃO N]`.
5. Cada sugestão passa pelo **classificador de conformidade**
   (`filtro-conformidade.md`) → recebe rótulo de risco, nada é descartado.
6. Todas as sugestões são gravadas na **fila** (tabela no Supabase).
7. Hermes encerra. O processo na VPS pode desligar até o próximo dia.

## Aplicação automática pós-aprovação (item 7)

O ponto-chave: você não edita arquivo na mão, mas nada é aplicado sem seu aval.

1. No n8n, você vê a fila do dia (risco alto no topo) e dá **aprovar** ou
   **rejeitar** em cada sugestão — um toque.
2. Ao **aprovar**, o n8n pega o campo `mudanca_proposta` (o texto/diff literal
   que o Hermes já preparou) e **aplica sozinho** na versão ativa do prompt/skill
   que o agente de vendas lê em tempo real.
3. A versão anterior é guardada (histórico), então dá para **reverter com um
   toque** se a mudança piorar o resultado.
4. O agente de vendas passa a usar a nova versão na próxima conversa.

### Onde vive o "prompt ativo"
Para o item 7 funcionar sem git no meio do caminho em produção, o
prompt/skills que o agente lê em tempo real ficam numa tabela versionada no
**Supabase** (ex.: `prompt_ativo`, com `versao`, `conteudo`, `aplicado_em`).
O repositório git continua sendo a **fonte de design e o backup versionado
legível** — as mudanças aprovadas podem ser espelhadas para cá para histórico,
mas o que o agente consome em tempo real é a tabela.

Decisão pendente: confirmar se você quer o espelhamento automático para o git
(rastreabilidade total) ou só o versionamento no Supabase (mais simples).

## O que continua travado (não muda)

- **Zero aplicação sem aprovação.** O item 7 automatiza só o passo *depois* do
  seu "aprovar". Nenhuma sugestão vira comportamento ativo sem esse toque.
- O **classificador de conformidade roda sempre** e o rótulo de risco aparece
  na hora da aprovação — você nunca aprova às cegas.
- O Hermes **não fala com o lead** e **não escreve** nos dados de conversa nem
  no núcleo direto; só na fila.
- Vale integralmente o `../../00-nucleo/compliance-e-etica.md`.

## Pendências desta camada
- [ ] Escolher a VPS específica (PikaPods não serve — não roda Docker
      customizado; ver `../setup-plataformas.md`) e subir o Hermes lá.
- [ ] Definir o modelo OpenAI exato para a análise.
- [x] Tabela `prompt_ativo` (versionada) criada no Supabase — ver
      `../supabase/schema.sql`.
- [x] Esqueleto do fluxo de aprovação no n8n montado — ver
      `../n8n/workflows/fila-notificar.json` e `fila-decidir.json`.
- [ ] Decidir sobre o espelhamento automático para o git.
