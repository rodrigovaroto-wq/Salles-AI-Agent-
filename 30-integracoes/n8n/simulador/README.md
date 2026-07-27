# Simulador — roda os workflows fora do n8n

Executa o grafo do n8n de verdade contra um **Postgres real**, com OpenAI,
WhatsApp e BlackCat dublados. Serve para o que validação estática não pega:
expressão que quebra, campo com nome errado, ramo de `IF` invertido, ordem de
nós errada, `$json` que mudou de forma no meio do fluxo.

Encontrou **5 defeitos** que sintaxe e integridade davam como corretos —
incluindo dois que teriam parado a operação inteira.

## Rodar

```bash
# 1. sobe um Postgres descartável
mkdir -p /tmp/pgt && chown postgres:postgres /tmp/pgt && chmod 700 /tmp/pgt
su -s /bin/bash postgres -c "export PATH=/usr/lib/postgresql/16/bin:\$PATH; \
  initdb -D /tmp/pgt/data -U postgres --auth=trust && \
  pg_ctl -D /tmp/pgt/data -o '-k /tmp -p 55432' -l /tmp/pgt/log start"

# 2. aplica o schema e as migrações
psql -h /tmp -p 55432 -U postgres -c "create database salles"
psql -h /tmp -p 55432 -U postgres -d salles -c "create role service_role; create role authenticator"
for f in schema migracao-aguardando-humano migracao-entrega migracao-robustez; do
  psql -h /tmp -p 55432 -U postgres -d salles -f ../../supabase/$f.sql
done
psql -h /tmp -p 55432 -U postgres -d salles -c "
  insert into prompt_ativo(chave,versao,conteudo,ativo) values
   ('objetivo',1,'...',true),('compliance',1,'...',true),('objecoes',1,'...',true);
  update produtos set entrega_texto='Seu acesso a '||nome||': https://exemplo/'||produto_id;"

# 3. roda
cd 30-integracoes/n8n/simulador
python3 suite.py     # funil de venda: 21 verificações
python3 hermes.py    # ciclo Hermes + follow-up: 13 verificações
```

## Arquivos

| Arquivo | Papel |
|---|---|
| `pgrest.py` | mini-PostgREST: traduz as URLs dos workflows para SQL real |
| `engine.py` | percorre o grafo, avalia expressões `={{ }}` em Node, roda os nós Code |
| `cenarios.py` | dublês de OpenAI/WhatsApp/BlackCat e utilitários |
| `suite.py` | venda → stack → link → pagamento → entrega, mais os casos de borda |
| `hermes.py` | digest, aprovação/rejeição e follow-up |

## Fidelidade — o que importa acertar

- **Array de resposta do Supabase é UM item**, cujo `json` é o array. É assim que
  o n8n se comporta, e `Separar leads (1 item cada)` depende disso. Simular como
  N itens dá falso positivo.
- **Resposta escalar** o n8n embrulha em `{data: ...}`. Por isso `consumir_buffer`
  passou a devolver objeto: o simulador expôs a ambiguidade.
- **`$json` muda de forma** a cada nó HTTP. Vários bugs vieram daí.

## Limites

Não simula: concorrência real entre execuções, o nó `Wait` (passa direto), o
comportamento de `batching` no envio, nem a Graph API. Para isso, o ensaio do
`VALIDACAO.md` §3.5 contra o n8n de verdade continua necessário.
