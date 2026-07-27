"""Roda o funil inteiro contra Postgres real, com OpenAI/WhatsApp/BlackCat dublados."""
import json
import sys
import pgrest
from engine import Sim

WF = "/home/user/Salles-AI-Agent-/30-integracoes/n8n/workflows/"
enviados = []   # tudo que teria ido para o WhatsApp

def sub_whatsapp(itens):
    for i in itens:
        enviados.append(i["json"])
    return [{"json": {"ok": True, "enviadas": len(itens), "total": len(itens)}}]

def openai(resposta):
    def _mock(corpo, ctx):
        _mock.ultimo_prompt = corpo["messages"][0]["content"]
        _mock.ultima_msg = corpo["messages"][-1]["content"]
        return [{"json": {"choices": [{"message": {"content": json.dumps(resposta)}}]}}]
    return _mock

def blackcat(corpo, ctx):
    return [{"json": {"data": {"invoiceUrl": "https://pay.blackcat/abc123",
                               "transactionId": "tx_sim_1"}}}]

def payload(texto, wa="5511900000001", nome="Maria", msg_id=None):
    import time
    return {"body": {"entry": [{"changes": [{"value": {
        "contacts": [{"profile": {"name": nome}, "wa_id": wa}],
        "messages": [{"id": msg_id or f"m{time.time_ns()}", "from": wa,
                      "type": "text", "text": {"body": texto}}]}}]}]}}

def rodar_agente(texto, resposta_ia, wa="5511900000001", msg_id=None, verbose=False):
    s = Sim(WF + "agente-vendas.json",
            mocks={"__sub__": sub_whatsapp, "Chamar OpenAI": openai(resposta_ia), "Criar venda BlackCat": blackcat},
            verbose=verbose)
    s.executar("WhatsApp IN", payload(texto, wa, msg_id=msg_id))
    return s

def rodar_pagamento(wa, items, evento="transaction.paid", tx="tx_sim_1", verbose=False):
    s = Sim(WF + "pagamento-blackcat.json", mocks={"__sub__": sub_whatsapp}, verbose=verbose)
    s.executar("BlackCat IN", {"body": {"event": evento, "externalReference": wa,
                                        "transactionId": tx, "items": items}})
    return s

IA = lambda **kw: {"mensagens": kw.get("m", ["ok"]), "intent": kw.get("i", "qualificando"),
                   "produtos_aceitos": kw.get("p", []), "arquetipo": kw.get("a"),
                   "pivo_downsell": False, "email": kw.get("e"), "cpf": kw.get("c")}

def esperar(cond, msg):
    print(("  ✅ " if cond else "  ❌ ") + msg)
    if not cond:
        esperar.falhas += 1
esperar.falhas = 0
