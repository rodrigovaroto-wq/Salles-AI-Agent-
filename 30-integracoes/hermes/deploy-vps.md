# Deploy do Hermes na VPS

Passo a passo para subir o Hermes Agent (NousResearch, open-source, MIT) numa
VPS própria — o PikaPods não roda, porque só aceita apps do catálogo dele
(sem Docker customizado), ver `../setup-plataformas.md`.

**Peça-chave da arquitetura do Hermes:** ele não usa um arquivo de config YAML
para tarefas — as tarefas são descritas em **linguagem natural** e rodam em
**sessões isoladas**: ele só faz o que estiver escrito explicitamente no
prompt da tarefa, não improvisa passos. Isso muda o formato deste guia em
relação aos outros: aqui o "código" é texto.

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

Preencha no `.env`:
- **Provedor LLM:** OpenAI + `OPENAI_API_KEY` (decisão já registrada em
  `configuracao.md`, item 4).
- **Não** configure tokens de Telegram/Discord/WhatsApp — o Hermes não fala
  com ninguém neste projeto (ver `README.md` desta pasta, "por que essa
  fronteira existe").
- Adicione também (usadas na tarefa da seção 7):
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

## 8. Criar a tarefa diária (o "cron" do Hermes)

Sintaxe real do agendador (não é YAML — é linguagem natural com schedule):

```bash
docker exec -it hermes-agent-hermes-1 hermes cron create "0 8 * * *" \
"Voce e o analista de performance do agente de vendas do projeto em /data/salles-ai-agent.

1. Leia /data/salles-ai-agent/00-nucleo/compliance-e-etica.md (secao 2 -- proibicoes absolutas) e /data/salles-ai-agent/30-integracoes/hermes/fila-aprovacao.md (schema da fila) antes de comecar.

2. Consulte via HTTP GET, usando os headers apikey e Authorization Bearer com o valor da env SUPABASE_SERVICE_KEY:
   {SUPABASE_URL}/rest/v1/conversas?ocorrido_em=gte.<24h atras em ISO>
   Se o total de linhas retornadas for menor que 25, PARE aqui e nao faca mais nada.

3. Se houver 25 ou mais, analise os dados: quais gatilhos mais converteram, quais objecoes mais aparecem, onde o funil perde mais gente, mensagens-pivo. Gere de 1 a 5 hipoteses de melhoria, cada uma no formato: area, arquivo_alvo, problema_observado, hipotese_impacto, mudanca_proposta (texto literal), teste_sugerido, confianca (alta/media/baixa).

4. Para CADA hipotese, classifique risco_conformidade comparando a mudanca_proposta com as proibicoes da secao 2 do compliance-e-etica.md que voce leu no passo 1: se bater com qualquer uma delas, risco_conformidade=alto e preencha padrao_disparado com qual proibicao foi tocada. Caso contrario avalie medio ou baixo conforme o volume de dados que sustenta a hipotese.

5. Envie CADA hipotese via HTTP POST para {SUPABASE_URL}/rest/v1/fila_sugestoes (mesmos headers do passo 2, mais Content-Type: application/json), com status=pendente. NAO escreva em nenhuma outra tabela. NAO envie mensagem para nenhum canal de chat -- essa tarefa e so leitura de conversas/aprendizado e escrita na fila." \
--deliver local --name hermes-diario
```

Note que a entrega (`--deliver local`) é só um registro local da execução — a
notificação para você já é feita pelo `fila-notificar.json` no n8n, lendo a
tabela `fila_sugestoes` diretamente. Evita notificação duplicada.

## 9. Testar antes de confiar no cron

Antes de deixar rodando sozinho por 1 dia inteiro, converse diretamente com o
Hermes pedindo para executar a tarefa **uma vez agora**, e confira:
- Ele leu o `compliance-e-etica.md` antes de gerar sugestões?
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
- [ ] Hermes clonado, `.env` preenchido (OpenAI + Supabase)
- [ ] Repositório do projeto montado como volume `:ro`
- [ ] `docker-compose up -d` rodando
- [ ] `hermes setup --portal` concluído
- [ ] Tarefa diária criada via `hermes cron create` (seção 8)
- [ ] Teste manual (seção 9) validado antes de confiar no agendamento
- [ ] (Depois) role Postgres restrito para substituir a service_role key

## Relacionado
- [`README.md`](README.md) — por que o Hermes fica fora do caminho crítico da venda
- [`configuracao.md`](configuracao.md) — decisões operacionais (cadência, volume mínimo, LLM)
- [`ciclo-aprendizado.md`](ciclo-aprendizado.md) — o fluxo completo dado → sugestão → fila → aprovação
- [`../n8n/workflows/fila-notificar.json`](../n8n/workflows/fila-notificar.json) — quem notifica você (não é o Hermes)
