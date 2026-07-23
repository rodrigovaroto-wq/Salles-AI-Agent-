# Deploy do Hermes na VPS

Passo a passo para subir o Hermes Agent (NousResearch, open-source, MIT) numa
VPS própria — o PikaPods não roda, porque só aceita apps do catálogo dele
(sem Docker customizado), ver `../setup-plataformas.md`.

**Peça-chave da arquitetura do Hermes:** as *tarefas* não vivem num YAML — são
descritas em **linguagem natural** e rodam em **sessões isoladas**: ele só faz
o que estiver escrito explicitamente no prompt da tarefa, não improvisa
passos. O *modelo/LLM*, por outro lado, é configurado num YAML de verdade
(`~/.hermes/config.yaml`, controlado por `HERMES_HOME`). Este guia foi
validado direto no código-fonte do `NousResearch/hermes-agent` (não só na
documentação), incluindo a sintaxe exata do `hermes cron create`.

---

## 1. Provisionar a VPS

Recomendação já registrada em `../setup-plataformas.md`: **Hetzner CX22**
(~€4/mês) ou **Hostinger VPS KVM** (~US$5/mês), ~4 GB RAM, Ubuntu 22/24 LTS.
Como o Hermes só roda 1x/dia em lote, essa capacidade sobra.

## 2. Instalar Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# reconecte a sessao SSH para o grupo docker valer
```

## 3. Clonar o Hermes e este repositório

```bash
git clone https://github.com/NousResearch/hermes-agent.git
cd hermes-agent

# clone tambem o repo do projeto para servir de fonte de verdade
# (compliance, schemas) que o Hermes vai LER, nao editar
git clone https://github.com/rodrigovaroto-wq/Salles-AI-Agent- ../salles-ai-agent
```

## 4. Configurar o `.env`

```bash
cp .env.example .env
```

**Provedor LLM — atenção, não é óbvio:** o `.env.example` do Hermes **não tem
um provedor nomeado "openai"** para o modelo principal (só usa OpenAI direto
para transcrição de voz, que não usamos aqui). Os provedores nativos são
Fireworks, OpenRouter, Anthropic, Gemini, GLM, Kimi, Novita, Ollama Cloud,
entre outros.

Para usar a **OpenAI de verdade, mesma conta do agente de vendas** (decisão
registrada em `configuracao.md`, item 4), o caminho confirmado no
código-fonte (`agent/auxiliary_client.py`) é o provedor `"custom"`, que
aceita qualquer endpoint compatível com a API da OpenAI — incluindo a própria
OpenAI:

```
# no .env do Hermes
OPENAI_API_KEY=<sua chave da OpenAI>
OPENAI_BASE_URL=https://api.openai.com/v1
```

E em `~/.hermes/config.yaml` (dentro do container, criado no passo 7):

```yaml
model:
  default: "gpt-4.1"   # decidido (configuracao.md, item 4) -- mesmo modelo do agente de vendas
  provider: "custom"
  base_url: "https://api.openai.com/v1"
```

Isso chama a API da OpenAI diretamente — mesma chave, mesma cobrança, sem
markup de intermediário (ex.: OpenRouter).

Também no `.env`:
- **Não** configure tokens de Telegram/Discord/WhatsApp — o Hermes não fala
  com ninguém neste projeto (ver `README.md` desta pasta, "por que essa
  fronteira existe").
- Adicione (usadas na tarefa da seção 8):
  ```
  SUPABASE_URL=https://SEUPROJETO.supabase.co
  SUPABASE_SERVICE_KEY=<service_role key>
  ```

## 5. Montar o repositório do projeto como volume somente-leitura

Edite (ou crie) `docker-compose.override.yml` ao lado do `docker-compose.yml`
do Hermes:

```yaml
services:
  hermes:
    volumes:
      - ../salles-ai-agent:/data/salles-ai-agent:ro
```

Isso garante que o Hermes sempre lê a **versão atual** de
`compliance-e-etica.md` e dos schemas — se você atualizar esses arquivos no
git, o próximo ciclo do Hermes já usa a versão nova, sem precisar editar o
texto da tarefa.

## 6. Subir o container

```bash
docker-compose up -d
```

## 7. Configuração interativa inicial

```bash
docker exec -it hermes-agent-hermes-1 hermes setup --portal
```

(o nome exato do container pode variar — confirme com `docker ps`)

Depois do setup, confirme/edite `~/.hermes/config.yaml` dentro do container
com o bloco `model` mostrado no passo 4 (`provider: "custom"`, `base_url`
apontando para a OpenAI). O `hermes setup` pode sobrescrever esse bloco se
você escolher outro provedor na tela interativa — revise o arquivo depois.

## 8. Criar a tarefa diária (o "cron" do Hermes)

Sintaxe confirmada em `hermes_cli/subcommands/cron.py` (código-fonte, não só
doc). Usamos a flag `--workdir` apontando para o repositório montado no passo
5 — isso injeta automaticamente o `/AGENTS.md` da raiz do repositório como
contexto persistente (papel do Hermes, fronteiras de escrita, onde ler o
compliance) em toda execução, então a tarefa abaixo só precisa da lógica
específica do dia, não repete as regras:

```bash
docker exec -it hermes-agent-hermes-1 hermes cron create "0 8 * * *" \
"Rode o ciclo diario de analise descrito no AGENTS.md deste diretorio.

1. Descubra desde quando analisar (NAO uma janela fixa de 24h -- desde o ultimo ciclo que realmente rodou, para nao perder dias em que o cron nao disparou):
   a. GET (headers apikey e Authorization Bearer com o valor da env SUPABASE_SERVICE_KEY):
      {SUPABASE_URL}/rest/v1/fila_sugestoes?select=criado_em&order=criado_em.desc&limit=1
   b. Se essa consulta retornar 1 linha, use o valor de criado_em dela como <desde>.
      Se retornar vazio (primeira vez que este ciclo roda), use <desde> = 30 dias atras em ISO.

2. Consulte (mesmos headers do passo 1):
   {SUPABASE_URL}/rest/v1/conversas?ocorrido_em=gte.<desde>
   Se o total de linhas retornadas for menor que 25, PARE aqui e nao faca mais nada -- nao escreva em fila_sugestoes. Como o cursor do passo 1 so avanca quando este ciclo efetivamente grava uma sugestao, nenhuma conversa fica de fora: no proximo dia a mesma janela <desde> e reconsultada, agora com mais conversas acumuladas.

3. Se houver 25 ou mais, analise os dados: quais gatilhos mais converteram, quais objecoes mais aparecem, onde o funil perde mais gente, mensagens-pivo. Gere de 1 a 5 hipoteses de melhoria, cada uma no formato: area, arquivo_alvo, problema_observado, hipotese_impacto, mudanca_proposta (texto literal), teste_sugerido, confianca (alta/media/baixa).

4. Para CADA hipotese, classifique risco_conformidade e padrao_disparado seguindo exatamente o procedimento da secao 'Classificacao de risco' do AGENTS.md.

5. Envie CADA hipotese via HTTP POST para {SUPABASE_URL}/rest/v1/fila_sugestoes (mesmos headers do passo 1, mais Content-Type: application/json), com status=pendente. E esse POST (nao um registro separado) que avanca o cursor do passo 1 para o proximo ciclo." \
--workdir /data/salles-ai-agent \
--deliver local --name hermes-diario
```

**Por que não é mais uma janela fixa de 24h:** a versão anterior deste comando
usava `ocorrido_em=gte.<24h atras>` — se o cron não disparasse num dia (app
fechado, VPS fora do ar, etc.), as conversas daquele dia saíam da janela na
execução seguinte e **nunca eram analisadas** (o dado continuava intacto em
`conversas`, só não entrava na análise do Hermes). Usar o `criado_em` mais
recente de `fila_sugestoes` como cursor resolve isso: o cursor só avança
quando o ciclo **de fato escreve** uma sugestão, então dias pulados (por
volume insuficiente ou por não ter rodado) simplesmente se acumulam na
janela seguinte, sem perder nada. Isso não fere a fronteira "Hermes só
escreve em `fila_sugestoes`" (ver `AGENTS.md`) — a leitura de
`fila_sugestoes` no passo 1a é só consulta.

Note que a entrega (`--deliver local`) é só um registro local da execução — a
notificação para você já é feita pelo `fila-notificar.json` no n8n, lendo a
tabela `fila_sugestoes` diretamente. Evita notificação duplicada.

## 9. Testar antes de confiar no cron

Antes de deixar rodando sozinho por 1 dia inteiro, converse diretamente com o
Hermes pedindo para executar a tarefa **uma vez agora**, e confira:
- Ele carregou o `AGENTS.md` (pergunte diretamente: "qual é o seu papel
  neste projeto?" — a resposta deve refletir as fronteiras do arquivo)?
- As sugestões de risco alto batem com as proibições reais da seção 2 do
  `compliance-e-etica.md`, com `padrao_disparado` preenchido corretamente?
- As sugestões chegaram na tabela `fila_sugestoes` no Supabase com os campos
  certos?
- Nenhuma chamada foi feita a WhatsApp/Telegram/etc.?

## 10. Ponto de segurança a endurecer depois (não bloqueia o MVP)

Usar a `service_role key` do Supabase no Hermes dá acesso total ao banco, não
só a leitura de `conversas`/`aprendizado` e escrita em `fila_sugestoes`. Para
produção, o ideal é criar um **role Postgres dedicado** no Supabase com
`GRANT SELECT` só nas tabelas de leitura e `GRANT INSERT` só em
`fila_sugestoes`, e gerar um JWT restrito a esse role para o Hermes usar no
lugar da `service_role key`. Registrado aqui como próximo passo de
hardening, não bloqueia o funcionamento.

---

## Checklist desta etapa
- [ ] VPS provisionada, Docker instalado
- [ ] Hermes clonado, este repositório clonado ao lado
- [ ] `.env`: `OPENAI_API_KEY` + `OPENAI_BASE_URL` + `SUPABASE_URL` +
      `SUPABASE_SERVICE_KEY`
- [ ] Repositório do projeto montado como volume `:ro` em `/data/salles-ai-agent`
- [ ] `docker-compose up -d` rodando
- [ ] `hermes setup --portal` concluído + `~/.hermes/config.yaml` com
      `provider: "custom"` confirmado
- [ ] Tarefa diária criada via `hermes cron create --workdir` (seção 8)
- [ ] Teste manual (seção 9) validado, incluindo checar se o `AGENTS.md` foi carregado
- [ ] (Depois) role Postgres restrito para substituir a service_role key

## Relacionado
- [`../../AGENTS.md`](../../AGENTS.md) — contexto persistente injetado via `--workdir`
- [`README.md`](README.md) — por que o Hermes fica fora do caminho crítico da venda
- [`configuracao.md`](configuracao.md) — decisões operacionais (cadência, volume mínimo, LLM)
- [`ciclo-aprendizado.md`](ciclo-aprendizado.md) — o fluxo completo dado → sugestão → fila → aprovação
- [`../n8n/workflows/fila-notificar.json`](../n8n/workflows/fila-notificar.json) — quem notifica você (não é o Hermes)
