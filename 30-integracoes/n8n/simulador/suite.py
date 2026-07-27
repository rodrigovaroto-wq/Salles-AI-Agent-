from cenarios import *
import pgrest
W="5511900000009"
def limpa():
    pgrest._sql(f"delete from leads where lead_id like '55119000000%'")
    pgrest._sql("delete from eventos_processados")
limpa(); enviados.clear()

print("═══ 1. Venda completa: qualificar → stack → dados → link ═══")
rodar_agente("oi [ref:lp]", IA(m=["Que bom que voce chegou."]), wa=W)
rodar_agente("quanto custa?", IA(m=["A Oracao Sagrada e R$ 22,90."]), wa=W)
rodar_agente("quero", IA(m=["Otimo!","Quer completar com os complementos?"], i="aceitou_stack", p=["oracao_sagrada"]), wa=W)
rodar_agente("quero tudo, maria@x.com, 111.444.777-35",
   IA(m=["Perfeito, gerando seu link."], i="gerar_link",
      p=["oracao_sagrada","oracao_audio","comunidade","contato_padre"],
      e="maria@x.com", c="111.444.777-35"), wa=W)
lead=pgrest.request("GET",f"https://x/rest/v1/leads?lead_id=eq.{W}")[0]
esperar(any("pay.blackcat" in e.get("texto","") for e in enviados), "link de pagamento enviado")
esperar(lead["email"]=="maria@x.com" and lead["cpf"]=="11144477735", f"email/CPF gravados (cpf={lead['cpf']})")
esperar(lead["ultimo_link_url"] is not None, "link guardado para reaproveitamento")
esperar(lead["status"]=="ativo", f"status ainda 'ativo' antes de pagar (={lead['status']})")

print("\n═══ 2. Desconto anunciado == cobrado ═══")
s=Sim(WF+"agente-vendas.json",mocks={"__sub__":sub_whatsapp,"Criar venda BlackCat":blackcat,"Chamar OpenAI":openai(
   IA(i="gerar_link",p=["oracao_sagrada","oracao_audio","comunidade","contato_padre"],
      e="a@b.c",c="11144477735"))})
s.executar("WhatsApp IN", payload("fecho tudo", W))
carrinho=s.saida["Montar items do carrinho"][0]["json"]
prompt=s.saida["Montar mensagens OpenAI"][0]["json"]["messages"][0]["content"]
import re
anunciado=re.findall(r"Total: R\$ ([\d,]+)", prompt)
esperar(carrinho["descontoPct"]==30, f"desconto de 30% para 4 itens (={carrinho['descontoPct']}%)")
cobrado=f"{carrinho['amount']/100:.2f}".replace(".",",")
esperar(anunciado and anunciado[-1]==cobrado, f"anunciado R$ {anunciado[-1] if anunciado else '?'} == cobrado R$ {cobrado}")

print("\n═══ 3. Pagamento e entrega ═══")
enviados.clear()
rodar_pagamento(W,[{"produto_id":"oracao_sagrada","title":"Oração Sagrada"}])
lead=pgrest.request("GET",f"https://x/rest/v1/leads?lead_id=eq.{W}")[0]
esperar(lead["status"]=="cliente", "status virou cliente")
esperar(any("exemplo/oracao_sagrada" in e.get("texto","") for e in enviados), "entrega com o link real do produto")
esperar(lead["ultimo_link_url"] is None, "link consumido foi limpo")

print("\n═══ 4. Reenvio do webhook não entrega duas vezes ═══")
antes=len(enviados)
rodar_pagamento(W,[{"produto_id":"oracao_sagrada","title":"Oração Sagrada"}])
esperar(len(enviados)==antes, f"nada reenviado (antes={antes}, depois={len(enviados)})")

print("\n═══ 5. Cliente não recebe oferta do que já tem ═══")
s=Sim(WF+"agente-vendas.json",mocks={"__sub__":sub_whatsapp,"Criar venda BlackCat":blackcat,"Chamar OpenAI":openai(IA(m=["oi"]))})
s.executar("WhatsApp IN", payload("oi de novo", W))
p2=s.saida["Montar mensagens OpenAI"][0]["json"]["messages"][0]["content"]
esperar("oracao_sagrada (principal)" not in p2, "Oração Sagrada fora do catálogo ofertável")
esperar("JA COMPROU" in p2, "prompt avisa o que ela já tem")

print("\n═══ 6. Handoff por sofrimento ═══")
W2="5511900000002"
rodar_agente("perdi meu filho, nao aguento mais",
   IA(m=["Sinto muito de verdade."], i="sofrimento"), wa=W2)
l2=pgrest.request("GET",f"https://x/rest/v1/leads?lead_id=eq.{W2}")[0]
esperar(l2["status"]=="aguardando_humano", f"lead marcado (={l2['status']})")
esperar(any("RODRIGO" in str(e.get("to","")) for e in enviados), "alerta disparado ao humano")
enviados.clear()
s=Sim(WF+"agente-vendas.json",mocks={"__sub__":sub_whatsapp,"Criar venda BlackCat":blackcat,"Chamar OpenAI":openai(IA(m=["Estou aqui."],i="sofrimento"))})
s.executar("WhatsApp IN", payload("oi", W2))
l2=pgrest.request("GET",f"https://x/rest/v1/leads?lead_id=eq.{W2}")[0]
esperar(l2["status"]=="aguardando_humano", "estado SOBREVIVE à mensagem seguinte")
esperar("MODO SEM VENDA" in s.saida["Montar mensagens OpenAI"][0]["json"]["messages"][0]["content"],
        "prompt entra em modo sem venda")

print("\n═══ 7. Opt-out ═══")
W3="5511900000003"
rodar_agente("nao quero mais receber", IA(m=["Tudo bem, respeito."], i="opt_out"), wa=W3)
l3=pgrest.request("GET",f"https://x/rest/v1/leads?lead_id=eq.{W3}")[0]
esperar(l3["status"]=="opt_out" and l3["consentimento_contato"] is False, "opt_out + consentimento derrubado")
enviados.clear()
s=Sim(WF+"agente-vendas.json",mocks={"__sub__":sub_whatsapp,"Criar venda BlackCat":blackcat,"Chamar OpenAI":openai(IA(m=["oi"]))})
s.executar("WhatsApp IN", payload("oi", W3))
esperar("Opt-out respeitado" in s.trilha and not enviados, "nova mensagem NÃO recebe resposta")
esperar("Chamar OpenAI" not in s.trilha, "nem gasta chamada de OpenAI")

print("\n═══ 8. Falha da OpenAI ═══")
enviados.clear()
def falha(corpo,ctx): return [{"json":{"error":{"message":"insufficient_quota"}}}]
s=Sim(WF+"agente-vendas.json",mocks={"__sub__":sub_whatsapp,"Criar venda BlackCat":blackcat,"Chamar OpenAI":falha})
s.executar("WhatsApp IN", payload("oi", "5511900000004"))
esperar(any("probleminha" in e.get("texto","") for e in enviados), "lead avisada, não fica no vácuo")
esperar(any("RODRIGO" in str(e.get("to","")) for e in enviados), "Rodrigo alertado")

print(f"\n{'='*46}\nFALHAS: {esperar.falhas}")
