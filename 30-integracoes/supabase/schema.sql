-- Supabase — schema do agente de vendas
-- Cole no SQL Editor do Supabase e rode. gen_random_uuid() já está disponível.
-- Deriva de ../../20-memoria/ e ../hermes/.

-- ========== LEADS (1 registro por pessoa) ==========
create table if not exists leads (
  lead_id               text primary key,                 -- wa_id normalizado
  nome                  text,
  criado_em             timestamptz not null default now(),
  origem_canal          text check (origem_canal in ('meta_ads','tiktok_ads','organico')),
  origem_campanha       text,
  origem_criativo       text,
  arquetipo             text check (arquetipo in ('mae_protetora','guerreira_fe','devota_busca','mulher_pertence')),
  estado_emocional      text check (estado_emocional in ('dor','esperanca','desejo','urgencia','decisao','alivio','gratidao','pertencimento')),
  etapa_funil           text check (etapa_funil in ('descoberta','consideracao','comprou_principal','comprou_upsell','recorrente')),
  objetivo_declarado    text,
  dores                 text[] default '{}',
  objecoes              text[] default '{}',
  produtos_comprados    jsonb  default '[]',
  consentimento_contato boolean not null default false,   -- opt-in (LGPD / janela 24h)
  status                text not null default 'ativo' check (status in ('ativo','abandonou','cliente','opt_out')),
  ultima_interacao      timestamptz
);
create index if not exists idx_leads_status on leads(status);
create index if not exists idx_leads_ultima  on leads(ultima_interacao);

-- ========== CONVERSAS (N eventos por lead) ==========
create table if not exists conversas (
  evento_id            uuid primary key default gen_random_uuid(),
  lead_id              text not null references leads(lead_id) on delete cascade,
  ocorrido_em          timestamptz not null default now(),
  etapa_processo       text check (etapa_processo in ('conexao','descoberta','apresentacao','objecao','fechamento','recuperacao','upsell')),
  mensagem_agente      text,
  mensagem_lead        text,
  objecao_detectada    text,
  gatilho_usado        text,
  resultado_parcial    text check (resultado_parcial in ('avancou','estagnou','recuou','converteu','perdeu')),
  sentimento_lead      text check (sentimento_lead in ('positivo','neutro','resistente')),
  -- oferta (stack / pivô)
  produtos_ofertados   text[] default '{}',
  produtos_aceitos     text[] default '{}',
  desconto_aplicado_pct numeric,
  pivo_catalogo        boolean default false,
  produto_pivo_id      text,
  link_blackcat_id     text,
  -- evento-resumo (preenchido no fecho da conversa)
  desfecho             text check (desfecho in ('venda','sem_venda','follow_up_agendado')),
  etapa_de_perda       text,
  mensagem_pivo        text,
  tempo_ate_decisao    integer   -- minutos entre 1a mensagem e desfecho
);
create index if not exists idx_conversas_lead     on conversas(lead_id);
create index if not exists idx_conversas_ocorrido on conversas(ocorrido_em);

-- ========== FILA DE SUGESTÕES (Hermes -> aprovação humana) ==========
create table if not exists fila_sugestoes (
  sugestao_id        uuid primary key default gen_random_uuid(),
  criado_em          timestamptz not null default now(),
  area               text check (area in ('abertura','descoberta','objecao','stack_oferta','follow_up','catalogo')),
  arquivo_alvo       text,
  problema_observado text,
  hipotese_impacto   text,
  mudanca_proposta   text,
  teste_sugerido     text,
  confianca          text check (confianca in ('alta','media','baixa')),
  risco_conformidade text check (risco_conformidade in ('alto','medio','baixo')),
  padrao_disparado   text,
  status             text not null default 'pendente' check (status in ('pendente','aprovada','rejeitada')),
  decidido_por       text,          -- sempre humano
  decidido_em        timestamptz,
  motivo_rejeicao    text,
  aplicado_em        timestamptz
);
create index if not exists idx_fila_status on fila_sugestoes(status);
create index if not exists idx_fila_risco  on fila_sugestoes(risco_conformidade);

-- ========== PROMPT ATIVO (versionado, com rollback) ==========
create table if not exists prompt_ativo (
  id                 bigserial primary key,
  chave              text not null,          -- ex.: 'objetivo', 'compliance', 'skill:copy'
  versao             integer not null,
  conteudo           text not null,
  ativo              boolean not null default true,
  origem_sugestao_id uuid references fila_sugestoes(sugestao_id),
  aplicado_em        timestamptz not null default now()
);
-- garante só UMA versão ativa por chave (troca: ativo=false na antiga, insere nova ativa)
create unique index if not exists idx_prompt_ativo_unico on prompt_ativo(chave) where ativo;

-- ========== PRODUTOS (catálogo real — fonte de verdade em runtime) ==========
create table if not exists produtos (
  produto_id     text primary key,
  nome           text not null,
  tipo           text not null check (tipo in ('principal','order_bump','alternativo')),
  preco_centavos integer not null,
  ordem          integer not null default 0,   -- ordem de apresentacao no stack
  ativo          boolean not null default true
);

insert into produtos (produto_id, nome, tipo, preco_centavos, ordem) values
  ('oracao_sagrada', 'Oração Sagrada',              'principal',   2290, 0),
  ('oracao_audio',   'Oração em Áudio',              'order_bump', 1390, 1),
  ('comunidade',     'Comunidade',                   'order_bump', 4490, 2),
  ('contato_padre',  'Contato Direto com o Padre',   'order_bump', 1990, 3)
on conflict (produto_id) do update set
  nome = excluded.nome, tipo = excluded.tipo,
  preco_centavos = excluded.preco_centavos, ordem = excluded.ordem;

-- ========== MÉTRICAS DE PERÍODO (snapshot p/ o Hermes analisar) ==========
create table if not exists metricas_periodo (
  id                   bigserial primary key,
  periodo_inicio       date not null,
  periodo_fim          date not null,
  receita_por_conversa numeric,   -- métrica principal (CONTEXT2)
  taxa_conversao       numeric,
  ticket_medio         numeric,
  taxa_recuperacao     numeric,
  tempo_medio_decisao  numeric,
  taxa_resposta        numeric,
  criado_em            timestamptz not null default now()
);

-- ========== SEGURANÇA (LGPD) ==========
-- RLS ligado, sem policies públicas: só o service_role (n8n / Hermes) acessa.
-- Isso protege o PII dos leads. Use a service_role key no backend, nunca a anon key.
alter table leads            enable row level security;
alter table conversas        enable row level security;
alter table fila_sugestoes   enable row level security;
alter table prompt_ativo     enable row level security;
alter table metricas_periodo enable row level security;
alter table produtos         enable row level security;
