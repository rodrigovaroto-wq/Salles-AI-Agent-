"""Mini-PostgREST: traduz as URLs que os workflows usam para SQL real.

Cobre exatamente os 19 padroes presentes nos workflows -- nao e um PostgREST
completo, e nao precisa ser. O objetivo e que uma URL errada, um campo com nome
errado ou um filtro mal montado FALHE aqui, como falharia no Supabase.
"""
import json
import re
import subprocess
import urllib.parse

PSQL = ["psql", "-h", "/tmp", "-p", "55432", "-U", "postgres", "-d", "salles", "-tA"]


def _sql(q):
    r = subprocess.run(PSQL + ["-c", q], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"SQL FALHOU\n  query: {q[:300]}\n  erro: {r.stderr.strip()[:400]}")
    return r.stdout.strip()


def _rows(q):
    out = _sql(f"select coalesce(json_agg(t),'[]') from ({q}) t")
    return json.loads(out or "[]")


def _rows_cte(q):
    """INSERT/UPDATE ... RETURNING nao pode ir em subquery; precisa de CTE."""
    out = _sql(f"with r as ({q}) select coalesce(json_agg(r),'[]') from r")
    return json.loads(out or "[]")


def _lit(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list) and all(isinstance(x, str) for x in v):
        # lista de strings -> text[] (produtos_aceitos, dores, objecoes)
        return "array[" + ",".join(_lit(x) for x in v) + "]::text[]"
    if isinstance(v, (dict, list)):
        return "'" + json.dumps(v).replace("'", "''") + "'::jsonb"
    return "'" + str(v).replace("'", "''") + "'"


def _filtro(chave, valor):
    """Traduz um filtro PostgREST (col=eq.x, col=in.(a,b), col=is.null...)."""
    if chave in ("select", "order", "limit", "offset"):
        return None
    if chave == "or":
        partes = valor.strip("()").split(",")
        return "(" + " or ".join(_or_termo(p) for p in partes) + ")"
    op, _, arg = valor.partition(".")
    if op == "eq":
        return f"{chave} = {_lit(arg)}"
    if op == "neq":
        return f"{chave} <> {_lit(arg)}"
    if op == "lt":
        return f"{chave} < {_lit(arg)}"
    if op == "gte":
        return f"{chave} >= {_lit(arg)}"
    if op == "is":
        return f"{chave} is {'null' if arg == 'null' else arg}"
    if op == "in":
        vals = arg.strip("()").split(",")
        return f"{chave} in ({','.join(_lit(v) for v in vals)})"
    raise RuntimeError(f"operador PostgREST nao suportado no simulador: {chave}={valor}")


def _or_termo(t):
    col, _, resto = t.partition(".")
    op, _, arg = resto.partition(".")
    if op == "is":
        return f"{col} is null"
    if op == "lt":
        return f"{col} < {_lit(arg)}"
    raise RuntimeError(f"termo 'or' nao suportado: {t}")


def request(method, url, body=None, prefer=""):
    caminho = url.split("/rest/v1/")[1]
    recurso, _, qs = caminho.partition("?")
    params = urllib.parse.parse_qs(qs, keep_blank_values=True)
    params = {k: v[0] for k, v in params.items()}

    # ---- RPC ----
    if recurso.startswith("rpc/"):
        fn = recurso[4:]
        args = ", ".join(f"{k} := {_lit(v)}" for k, v in (body or {}).items())
        out = _sql(f"select coalesce(to_json(r)::text,'null') from {fn}({args}) r")
        # funcao que devolve escalar vem como valor cru
        try:
            val = json.loads(out) if out else None
        except json.JSONDecodeError:
            val = out or None
        if fn in ("registrar_lead", "registrar_compra") and isinstance(val, str):
            val = json.loads(val)
        return val

    onde = [f for f in (_filtro(k, v) for k, v in params.items()) if f]
    where = (" where " + " and ".join(onde)) if onde else ""

    if method == "GET":
        cols = params.get("select", "*")
        ordem = ""
        if "order" in params:
            partes = []
            for o in params["order"].split(","):
                c, _, d = o.partition(".")
                partes.append(f"{c} {'desc' if d == 'desc' else 'asc'}")
            ordem = " order by " + ", ".join(partes)
        lim = f" limit {params['limit']}" if "limit" in params else ""
        return _rows(f"select {cols} from {recurso}{where}{ordem}{lim}")

    if method == "POST":
        campos = list(body.keys())
        vals = ", ".join(_lit(body[c]) for c in campos)
        conflito = " on conflict do nothing" if "ignore-duplicates" in prefer else ""
        return _rows_cte(f"insert into {recurso} ({','.join(campos)}) values ({vals}){conflito} returning *")

    if method == "PATCH":
        sets = ", ".join(f"{k} = {_lit(v)}" for k, v in body.items())
        return _rows_cte(f"update {recurso} set {sets}{where} returning *")

    raise RuntimeError(f"metodo nao suportado: {method}")
