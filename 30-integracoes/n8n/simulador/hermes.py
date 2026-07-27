from cenarios import *
import pgrest
pgrest._sql("delete from fila_sugestoes")
pgrest._sql("""insert into fila_sugestoes(area,arquivo_alvo,problema_observado,mudanca_proposta,
  confianca,risco_conformidade,status) values
 ('abertura','00-nucleo/objetivo.md','abertura fria','Nova abertura','alta','alto','pendente'),
 ('objecao','00-nucleo/objecoes.md','objecao preco','Novo texto','media','baixo','pendente');""")
enviados.clear()

print("═══ fila-notificar: digest diario ═══")
s=Sim(WF+"fila-notificar.json",mocks={"__sub__":sub_whatsapp})
s.executar("Digest diario",{})
esperar(len(enviados)==1, f"um digest enviado (={len(enviados)})")
esperar("Aprovar:" in enviados[0]["texto"] if enviados else False, "digest traz links de decisao")
pend=pgrest.request("GET","https://x/rest/v1/fila_sugestoes?notificado_em=is.null")
esperar(len(pend)==0, f"sugestoes marcadas como notificadas (restam {len(pend)})")

print("\n═══ fila-notificar roda de novo no dia seguinte ═══")
enviados.clear()
s=Sim(WF+"fila-notificar.json",mocks={"__sub__":sub_whatsapp})
s.executar("Digest diario",{})
esperar(len(enviados)==0 and "Nada pendente" in s.trilha, "NAO reenvia as mesmas sugestoes")

print("\n═══ fila-decidir: aprovar aplica em prompt_ativo ═══")
sug=pgrest.request("GET","https://x/rest/v1/fila_sugestoes?arquivo_alvo=eq.00-nucleo/objecoes.md")[0]
antes=pgrest.request("GET","https://x/rest/v1/prompt_ativo?chave=eq.objecoes&ativo=eq.true")[0]
def gh(corpo,ctx): return [{"json":{"sha":"abc123","content":{"sha":"def456"}}}]
s=Sim(WF+"fila-decidir.json",mocks={"Buscar SHA do arquivo no GitHub":gh,"Commitar mudanca no GitHub":gh})
s.executar("Clique aprovar/rejeitar",{"query":{"id":sug["sugestao_id"],"decisao":"aprovada"}})
depois=pgrest.request("GET","https://x/rest/v1/prompt_ativo?chave=eq.objecoes&ativo=eq.true")
esperar(len(depois)==1, f"exatamente 1 versao ativa (={len(depois)})")
esperar(depois[0]["versao"]==antes["versao"]+1, f"versao subiu {antes['versao']}->{depois[0]['versao']}")
esperar(depois[0]["conteudo"]=="Novo texto", "conteudo novo aplicado")
velha=pgrest.request("GET",f"https://x/rest/v1/prompt_ativo?chave=eq.objecoes&versao=eq.{antes['versao']}")[0]
esperar(velha["ativo"] is False, "versao antiga preservada como inativa (rollback possivel)")
d=pgrest.request("GET",f"https://x/rest/v1/fila_sugestoes?sugestao_id=eq.{sug['sugestao_id']}")[0]
esperar(d["status"]=="aprovada" and d["aplicado_em"], "fila marcada como aprovada e aplicada")

print("\n═══ fila-decidir: rejeitar NAO aplica ═══")
sug2=pgrest.request("GET","https://x/rest/v1/fila_sugestoes?arquivo_alvo=eq.00-nucleo/objetivo.md")[0]
n_antes=len(pgrest.request("GET","https://x/rest/v1/prompt_ativo"))
s=Sim(WF+"fila-decidir.json",mocks={"Buscar SHA do arquivo no GitHub":gh,"Commitar mudanca no GitHub":gh})
s.executar("Clique aprovar/rejeitar",{"query":{"id":sug2["sugestao_id"],"decisao":"rejeitada"}})
esperar(len(pgrest.request("GET","https://x/rest/v1/prompt_ativo"))==n_antes, "nenhuma versao nova criada")
esperar("Rejeitada (sem aplicacao)" in s.trilha, "seguiu o ramo de rejeicao")

print("\n═══ followup-24h ═══")
pgrest._sql("delete from leads where lead_id like 'FU%'")
pgrest._sql("""insert into leads(lead_id,nome,status,consentimento_contato,ultima_interacao,followups_enviados)
 values ('FU1','Ana','ativo',true,now()-interval '30 hours',0),
        ('FU2','Bia','ativo',false,now()-interval '30 hours',0);""")
enviados.clear()
s=Sim(WF+"followup-24h.json",mocks={"__sub__":sub_whatsapp})
s.executar("A cada hora",{})
esperar(len(enviados)==1 and enviados[0]["to"]=="FU1", f"so FU1 recebeu ({[e['to'] for e in enviados]})")
esperar(enviados[0]["tipo"]=="template", "enviado como template (fora da janela de 24h)")
fu=pgrest.request("GET","https://x/rest/v1/leads?lead_id=eq.FU1")[0]
esperar(fu["followups_enviados"]==1 and fu["ultimo_followup_em"], "contador e data marcados")
enviados.clear()
s=Sim(WF+"followup-24h.json",mocks={"__sub__":sub_whatsapp})
s.executar("A cada hora",{})
esperar(len(enviados)==0, f"na hora seguinte NAO reenvia (={len(enviados)})")

print(f"\n{'='*46}\nFALHAS: {esperar.falhas}")
