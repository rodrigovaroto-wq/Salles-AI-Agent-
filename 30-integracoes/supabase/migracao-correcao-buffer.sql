-- ═══════════════════════════════════════════════════════════════════
-- Correção: consumir_buffer devolvia sempre string vazia
-- ═══════════════════════════════════════════════════════════════════
--
-- A versão de `migracao-robustez.sql` fazia:
--
--     update leads
--        set buffer_mensagens = '{}'
--      where lead_id = p_lead_id and ultima_msg_id = p_msg_id
--     returning array_to_string(buffer_mensagens, E'\n') into v_texto;
--
-- `RETURNING` num UPDATE enxerga a linha **já modificada**. Quando o
-- array_to_string rodava, `buffer_mensagens` já era `'{}'` — então v_texto
-- vinha `''`, nunca o texto acumulado.
--
-- Efeito ao vivo: TODA mensagem de lead chegava vazia no agente. O debounce
-- não juntava nada; ele apagava. Reproduzido em Postgres 16:
--
--     buffer no banco : {"primeira mensagem","segunda mensagem"}
--     consumir_buffer : ''        <- devia ser as duas mensagens
--
-- O caso "superada por mensagem nova" continuava certo (devolvia NULL), o que
-- é justamente por que o defeito passava despercebido: o caminho de exceção
-- funcionava e o caminho normal não.
--
-- A correção lê o buffer ANTES de zerar. O `for update` segura a linha até o
-- commit, então duas execuções concorrentes não leem o mesmo buffer — só a
-- primeira encontra `ultima_msg_id` batendo, a outra cai no `not found`.

create or replace function consumir_buffer(
  p_lead_id text,
  p_msg_id  text
)
returns text
language plpgsql
as $$
declare
  v_texto text;
begin
  -- Só quem ainda é a última mensagem tem direito de responder.
  select array_to_string(buffer_mensagens, E'\n')
    into v_texto
    from leads
   where lead_id = p_lead_id
     and ultima_msg_id = p_msg_id
     for update;

  if not found then
    return null;   -- NULL = superada por mensagem mais nova
  end if;

  update leads
     set buffer_mensagens = '{}'
   where lead_id = p_lead_id;

  return v_texto;
end;
$$;

comment on function consumir_buffer is
  'Devolve o texto acumulado no buffer e o zera, mas só para quem ainda é a '
  'última mensagem. Lê antes de zerar: RETURNING num UPDATE já enxerga a linha '
  'modificada e devolvia sempre string vazia.';

grant execute on function consumir_buffer(text, text) to service_role;

-- ── Conferência ────────────────────────────────────────────────────
-- Rode depois de aplicar. O esperado é a segunda linha trazer as duas
-- mensagens juntas, e a terceira trazer NULL.
--
--   insert into leads (lead_id) values ('_teste_buffer')
--     on conflict (lead_id) do update set buffer_mensagens = '{}', ultima_msg_id = null;
--   select bufferizar_mensagem('_teste_buffer', 'm1', 'primeira');
--   select bufferizar_mensagem('_teste_buffer', 'm2', 'segunda');
--   select consumir_buffer('_teste_buffer', 'm2');   -- 'primeira\nsegunda'
--   select consumir_buffer('_teste_buffer', 'm1');   -- NULL
--   delete from leads where lead_id = '_teste_buffer';
