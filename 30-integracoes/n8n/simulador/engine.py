"""Executa um workflow do n8n fora do n8n.

Percorre o grafo de verdade, avalia as expressoes `={{ }}` em Node com o mesmo
contexto ($json / $node[...]), roda os nos Code em Node, e manda as chamadas ao
Supabase para um Postgres real. OpenAI, WhatsApp e BlackCat sao dublados.

Serve para pegar o que validacao estatica nao pega: referencia a campo que nao
existe, expressao que quebra, ramo do IF que nunca dispara, ordem errada.
"""
import json
import subprocess
import tempfile
import pathlib
import pgrest

NODE = "node"


class Sim:
    def __init__(self, caminho_wf, mocks=None, verbose=False):
        wf = json.load(open(caminho_wf))
        self.nodes = {n["name"]: n for n in wf["nodes"]}
        self.conns = wf["connections"]
        self.mocks = mocks or {}
        self.verbose = verbose
        self.saida = {}       # nome do no -> lista de itens
        self.trilha = []      # ordem de execucao, para inspecao

    # ---------- avaliacao de expressao n8n ----------
    def _js(self, corpo, ctx_json, extra=""):
        ctx = {k: {"json": (v[0]["json"] if v else {}), "all": v} for k, v in self.saida.items()}
        script = f"""
const CTX = {json.dumps(ctx)};
const $json = {json.dumps(ctx_json)};
const $node = new Proxy({{}}, {{ get: (_, k) => {{
  if (!(k in CTX)) throw new Error('$node["'+String(k)+'"] nao existe ou ainda nao rodou');
  return {{ json: CTX[k].json }};
}} }});
const $input = {{
  first: () => ({{ json: $json }}),
  all:   () => ITENS,
}};
{extra}
const R = ({corpo});
console.log(JSON.stringify(R === undefined ? null : R));
"""
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
            f.write(script)
            caminho = f.name
        r = subprocess.run([NODE, caminho], capture_output=True, text=True)
        pathlib.Path(caminho).unlink()
        if r.returncode != 0:
            raise RuntimeError(f"expressao falhou: {r.stderr.strip()[:400]}")
        return json.loads(r.stdout or "null")

    def _expr(self, valor, ctx_json):
        """Resolve '={{ ... }}' — inteiro ou interpolado no meio de uma string."""
        if not isinstance(valor, str) or not valor.startswith("="):
            return valor
        corpo = valor[1:]
        if corpo.startswith("{{") and corpo.endswith("}}") and corpo.count("{{") == 1:
            return self._js(corpo[2:-2], ctx_json)
        # interpolado: monta template string
        import re
        partes = re.split(r"\{\{(.*?)\}\}", corpo)
        js = "`" + "".join(
            p.replace("`", "\\`").replace("${", "\\${") if i % 2 == 0 else "${" + p + "}"
            for i, p in enumerate(partes)
        ) + "`"
        return self._js(js, ctx_json)

    def _code(self, node, itens):
        js = node["parameters"]["jsCode"]
        primeiro = itens[0]["json"] if itens else {}
        r = self._js("(() => {" + js + "})()", primeiro,
                     extra=f"const ITENS = {json.dumps(itens)};")
        if r is None:
            return []
        return r if isinstance(r, list) else [r]

    # ---------- execucao ----------
    def _rodar(self, node, itens):
        t = node["type"].split(".")[-1]
        p = node.get("parameters", {})
        ctx = itens[0]["json"] if itens else {}

        if t in ("webhook", "executeWorkflowTrigger", "scheduleTrigger", "cron"):
            return itens, 0
        if t == "noOp":
            return itens, 0
        if t == "wait":
            return itens, 0
        if t == "merge":
            # No simulador o IF so segue por um ramo, entao chega um lado so.
            return itens, 0
        if t == "respondToWebhook":
            return itens, 0
        if t == "code":
            return self._code(node, itens), 0
        if t == "executeWorkflow":
            fn = self.mocks.get("__sub__")
            return (fn(itens) if fn else [{"json": {"ok": True, "enviadas": len(itens), "total": len(itens)}}]), 0
        if t == "if":
            c = p["conditions"]["conditions"][0]
            esq = self._expr(c["leftValue"], ctx)
            op = c["operator"]["operation"]
            dir_ = c["rightValue"]
            if op == "equals":
                ok = esq == dir_
            elif op == "notEquals":
                ok = esq != dir_
            elif op == "notEmpty":
                ok = esq not in (None, "", [], {})
            elif op == "gt":
                ok = (esq or 0) > (dir_ or 0)
            elif op == "lt":
                ok = (esq or 0) < (dir_ or 0)
            elif op == "empty":
                ok = esq in (None, "", [], {})
            else:
                raise RuntimeError(f"operador de IF nao suportado: {op}")
            return itens, (0 if ok else 1)
        if t == "httpRequest":
            url = self._expr(p["url"], ctx)
            metodo = p.get("method", "GET")
            corpo = self._expr(p["jsonBody"], ctx) if p.get("jsonBody") else None
            prefer = " ".join(h.get("value", "") for h in
                              p.get("headerParameters", {}).get("parameters", []))
            if "supabase" in url:
                try:
                    res = pgrest.request(metodo, url, corpo, prefer)
                except Exception as e:
                    if node.get("onError") == "continueRegularOutput":
                        return [{"json": {"error": {"message": str(e)}}}], 0
                    raise
                # O HTTP Request do n8n NAO explode array de resposta: mantem
                # um item unico cujo json E o array. Documentado no README dos
                # workflows e assumido por "Separar leads (1 item cada)".
                return [{"json": res if res is not None else {}}], 0
            fn = self.mocks.get(node["name"])
            if fn is None:
                raise RuntimeError(f"sem mock para o no externo: {node['name']} ({url[:60]})")
            return fn(corpo, ctx), 0
        raise RuntimeError(f"tipo de no nao suportado: {t}")

    def executar(self, gatilho, entrada):
        fila = [(gatilho, [{"json": entrada}])]
        while fila:
            nome, itens = fila.pop(0)
            node = self.nodes[nome]
            saida, ramo = self._rodar(node, itens)
            self.saida[nome] = saida
            self.trilha.append(nome)
            if self.verbose:
                print(f"    · {nome}" + (f"  [ramo {ramo}]" if node["type"].endswith("if") else ""))
            if not saida:
                continue
            ramos = self.conns.get(nome, {}).get("main", [])
            if ramo < len(ramos):
                for aresta in ramos[ramo]:
                    fila.append((aresta["node"], saida))
        return self.saida
