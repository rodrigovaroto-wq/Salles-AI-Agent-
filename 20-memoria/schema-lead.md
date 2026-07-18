# Schema — Ficha do Lead

Um registro por pessoa. É a "ficha permanente" que o agente carrega no início de
cada conversa. Deriva do CONTEXT6 (Inteligência de Aprendizado) do núcleo.

## Campos

| Campo | Tipo | Descrição | Exemplo |
|---|---|---|---|
| `lead_id` | string | Identificador único (ex.: número WhatsApp normalizado) | `5511987654321` |
| `nome` | string | Nome informado pelo lead | `Maria` |
| `criado_em` | datetime | Primeiro contato | `2026-07-18T14:03:00Z` |
| `origem_canal` | enum | De onde veio | `meta_ads` / `tiktok_ads` / `organico` |
| `origem_campanha` | string | Campanha/conjunto de anúncio | `campanha-protecao-julho` |
| `origem_criativo` | string | Criativo que trouxe o lead | `criativo-antena-v3` |
| `arquetipo` | enum | Perfil dominante (ver copy-persuasao) | `mae_protetora` / `guerreira_fe` / `devota_busca` / `mulher_pertence` |
| `estado_emocional` | enum | Estado atual (ver ciclos-emocionais) | `dor` / `esperanca` / `desejo` / `urgencia` / `decisao` / `alivio` / `gratidao` / `pertencimento` |
| `etapa_funil` | enum | Fase da jornada (ver jornada-do-lead) | `descoberta` / `consideracao` / `comprou_principal` / `comprou_upsell` / `recorrente` |
| `objetivo_declarado` | text | O que o lead quer alcançar | `unir a família / paz` |
| `dores` | array | Dores principais mapeadas | `["solidão", "medo pela família"]` |
| `objecoes` | array | Objeções apresentadas | `["preço", "desconfiança"]` |
| `produtos_comprados` | array | Histórico de compras reais | `[{"produto":"oracao","valor":99.90,"data":"..."}]` |
| `consentimento_contato` | bool | Opt-in explícito para receber mensagens | `true` |
| `status` | enum | Situação atual | `ativo` / `abandonou` / `cliente` / `opt_out` |
| `ultima_interacao` | datetime | Timestamp da última mensagem | `2026-07-18T14:20:00Z` |

## Notas de conformidade
- `consentimento_contato` e `status: opt_out` são **obrigatórios** para respeitar
  LGPD e o direito do lead de parar de receber mensagens (CONTEXT8 do núcleo).
- Nunca preencher `produtos_comprados` com compras que não aconteceram.
