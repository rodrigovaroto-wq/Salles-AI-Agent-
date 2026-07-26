#!/usr/bin/env python3
"""Compoe workflow-completo.json a partir dos 5 arquivos individuais.

Rode sempre que editar um dos individuais:

    python3 30-integracoes/n8n/workflows/gerar-workflow-completo.py

Por que existe: o consolidado precisa ser a soma EXATA dos individuais. Mantido
a mao ele diverge -- foi o que aconteceu (tres nos ficaram sem prefixo de ramo
e os mecanismos novos nunca chegaram nele). Gerando, a divergencia deixa de ser
possivel.

O que o gerador faz:
  - prefixa os `id` por ramo (`av-`, `pb-`, ...) para nao colidirem;
  - desloca cada ramo em `y` para os 5 nao se sobreporem no canvas;
  - copia nos e conexoes sem alterar nada mais.

Os nomes dos nos NAO sao prefixados de proposito: as conexoes e as expressoes
`$node["..."]` referenciam nos pelo nome, entao renomear quebraria as duas
coisas. O gerador valida que nao ha nome repetido entre ramos -- se voce criar
um nome duplicado num individual, ele falha aqui em vez de gerar um consolidado
silenciosamente quebrado.
"""

import json
import pathlib
import sys

AQUI = pathlib.Path(__file__).parent

# (arquivo, prefixo de id) -- a ordem define a ordem vertical no canvas.
RAMOS = [
    ("agente-vendas", "av"),
    ("pagamento-blackcat", "pb"),
    ("followup-24h", "f24"),
    ("fila-notificar", "fn"),
    ("fila-decidir", "fd"),
]

ESPACO_ENTRE_RAMOS = 320  # px de folga vertical


def gerar() -> dict:
    nodes, connections, vistos = [], {}, {}
    topo = 0

    for arquivo, prefixo in RAMOS:
        dados = json.loads((AQUI / f"{arquivo}.json").read_text())

        for n in dados["nodes"]:
            if n["name"] in vistos:
                sys.exit(
                    f"ERRO: o no {n['name']!r} existe em {arquivo}.json e em "
                    f"{vistos[n['name']]}.json. Nomes precisam ser unicos entre "
                    f"ramos -- conexoes e expressoes $node[] referenciam por nome."
                )
            vistos[n["name"]] = arquivo

        ys = [n["position"][1] for n in dados["nodes"]]
        desloc = topo - min(ys)

        for n in dados["nodes"]:
            n = json.loads(json.dumps(n))  # copia, nao mexe no individual
            n["id"] = f"{prefixo}-{n['id']}"
            n["position"] = [n["position"][0], n["position"][1] + desloc]
            nodes.append(n)

        connections.update(dados["connections"])
        topo = desloc + max(ys) + ESPACO_ENTRE_RAMOS

    return {
        "name": "salles-ai-agent — operacao completa (todos os gatilhos)",
        "active": False,
        "settings": {},
        "nodes": nodes,
        "connections": connections,
    }


def validar(wf: dict) -> None:
    nomes = [n["name"] for n in wf["nodes"]]
    ids = [n["id"] for n in wf["nodes"]]
    assert len(set(nomes)) == len(nomes), "nome de no duplicado"
    assert len(set(ids)) == len(ids), "id de no duplicado"

    conhecidos = set(nomes)
    for origem, saidas in wf["connections"].items():
        assert origem in conhecidos, f"conexao a partir de no inexistente: {origem}"
        for ramo in saidas["main"]:
            for aresta in ramo:
                assert aresta["node"] in conhecidos, f"conexao para no inexistente: {aresta['node']}"

    posicoes = [tuple(n["position"]) for n in wf["nodes"]]
    assert len(set(posicoes)) == len(posicoes), "dois nos na mesma posicao"


if __name__ == "__main__":
    wf = gerar()
    validar(wf)
    destino = AQUI / "workflow-completo.json"
    destino.write_text(json.dumps(wf, indent=2, ensure_ascii=False) + "\n")
    print(f"{destino.name}: {len(wf['nodes'])} nos, {len(wf['connections'])} origens de conexao")
