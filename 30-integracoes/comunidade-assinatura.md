# Comunidade como Assinatura — modelo, cobrança e entrega

Definido em 27/07: a Comunidade passa a ser **R$ 44,90 de entrada (única) +
R$ 9,78/mês, com os primeiros 30 dias grátis**. A mensalidade começa no dia 31.

## O que já está construído (neste repo)

| Peça | Onde | Estado |
|---|---|---|
| Campos `mensalidade_centavos` / `trial_dias` em `produtos` | `supabase/migracao-comunidade-assinatura.sql` | pronto, falta rodar |
| Tabela `assinaturas` (trial → ativa → inadimplente/cancelada) | idem | pronto, falta rodar |
| Registro automático da assinatura no webhook `paid` | `pagamento-blackcat.json` → nós "Tem assinatura?" / "Registrar assinatura" | pronto |
| Divulgação obrigatória da mensalidade pelo agente | node "Montar mensagens OpenAI" (catálogo + tabela de desconto) e FATOS do `objecoes.md` | pronto |
| Entrega com mídia (PDF/áudio no chat) | `sub-enviar-whatsapp.json` (tipos `documento`/`audio`) + `pagamento-blackcat.json` | pronto |
| Textos de entrega dos 4 produtos | `migracao-comunidade-assinatura.sql` §4 | pronto, falta rodar |
| Link individual por compradora (fila atômica) | `migracao-links-comunidade.sql` + nó "Consumir link da comunidade" | pronto, falta rodar e abastecer |
| Cobrança mensal (link renovável) | **não construída** — ver seção abaixo | aguarda decisão de gateway |

## Linha do tempo de uma venda da Comunidade

```
dia 0   lead paga R$ 44,90 (entrada, no carrinho normal com desconto do stack)
        └─ webhook paid → entrega (link do grupo) + assinaturas: status='trial',
           trial_ate = proxima_cobranca = dia 30, valor congelado em R$ 9,78
dia 30  fim do período grátis
dia 31  primeira mensalidade
depois  uma mensalidade a cada 30 dias
```

O valor é **congelado na adesão** (`assinaturas.valor_centavos`): um reajuste
futuro não muda quem já entrou.

## Cobrança da mensalidade — pesquisado em 27/07 ⚠️

**O BlackCat não suporta assinatura.** Conferido na documentação oficial
(https://docs.blackcatoficial.com/): os únicos endpoints são
`POST /sales/create-sale`, `GET /sales/{id}/status`, `GET /sales/seller` e
`POST /sales/create-withdrawal`. Não há endpoint de assinatura, plano,
recorrência **nem tokenização de cartão**. O `create-sale` recebe os dados do
cartão em texto puro (`card.number`, `card.cvv`) a cada transação.

Isso tem uma consequência dura: **não existe caminho para "cadastrar o cartão e
cobrar todo mês automaticamente" no BlackCat.** Para repetir a cobrança seria
preciso guardar número e CVV do cartão e reenviá-los mensalmente — e armazenar
CVV é proibido pelo PCI-DSS sem exceção, além de exigir que o agente peça
número de cartão dentro do WhatsApp, deixando dado de cartão no histórico da
conversa, no Supabase e no contexto da OpenAI. **Não construí isso e não
recomendo construir.**

### O que dá para fazer com o BlackCat (implementado)

**Link mensal renovável.** Um workflow diário lê `assinaturas` com
`proxima_cobranca <= hoje`, gera um `create-sale` de R$ 9,78 com
`metadata.tipo='mensalidade'` e manda o link pelo WhatsApp. A cliente toca e
paga (Pix ou cartão, como preferir).

- Pago → `ultimo_pagamento = now()`, `proxima_cobranca += 30 dias`, `status='ativa'`
- 3 dias sem pagar → lembrete
- 7 dias sem pagar → `status='inadimplente'` + alerta ao Rodrigo para remover do grupo

É honesto, funciona hoje e serve para os testes. O custo é churn: cobrança que
exige ação mensal da cliente perde gente que simplesmente esqueceu.

### Para a assinatura de verdade (na migração de gateway)

Como vocês já planejam trocar de gateway, este é o requisito a levar na escolha:
**tokenização de cartão + cobrança recorrente nativa**. Gateways brasileiros que
têm isso: Pagar.me, Asaas, Iugu, Vindi, Stripe. Com qualquer um deles a cliente
cadastra o cartão uma vez numa página segura do gateway (o cartão nunca passa
pelo nosso lado), e a cobrança mensal roda sozinha — que é exatamente o
"precisa adicionar um cartão de crédito para assinar" que você pediu.

Quando migrarem, o que já está construído aqui continua valendo: a tabela
`assinaturas`, o registro no webhook `paid`, a divulgação obrigatória da
mensalidade e o controle de trial. Só o node que gera a cobrança muda.

## Regras de transparência (não negociáveis para funcionar)

- O agente **sempre** informa entrada + mensalidade + 30 dias grátis **na mesma
  mensagem** em que oferece a Comunidade. Isso já está no prompt e na tabela de
  desconto; não remover — mensalidade surpresa é chargeback e denúncia na Meta.
- Cancelamento: quando a cliente pedir para cancelar, `status='cancelada'`,
  sem retenção agressiva. Ela mantém o acesso até o fim do período já pago.
- Inadimplência: 7 dias sem pagar → `status='inadimplente'` e alerta ao
  Rodrigo. A remoção do grupo é **manual** (não há API do WhatsApp para
  remover membro).

## Entrega por produto — aprovada em 27/07

Os textos estão aplicados em `migracao-comunidade-assinatura.sql` (seção 4).
Mídia hospedada no **Supabase Storage** (bucket público `entrega`); as URLs
entram em `produtos.entrega_midia`. O PDF do produto principal já está no repo:
`30-integracoes/entrega/oracao-sagrada-de-sao-bento.pdf` (4 páginas, 8,4 MB).
Os áudios chegam em seguida.

| Produto | Mídia antes do texto | Texto |
|---|---|---|
| `oracao_sagrada` | o PDF | "Aqui está a sua Oração Sagrada de São Bento 🙏 …" |
| `oracao_audio` | os áudios | "Estes são os áudios da Oração, gravados pelo próprio Padre Frei…" |
| `comunidade` | — | boas-vindas + `{LINK_COMUNIDADE}` + mensalidade + "este link é só seu" |
| `contato_padre` | — | "Ele acontece aqui pelo WhatsApp…" |

`{LINK_COMUNIDADE}` é substituído em runtime pelo link individual consumido da
fila. Não use `{nome}` nos textos de entrega: o webhook do BlackCat não carrega
o nome da lead nesse ponto do fluxo.

## Decisões de 27/07

| Questão | Decisão |
|---|---|
| Recorrência nativa no BlackCat | **Não existe** — link mensal renovável por enquanto; requisito para a migração de gateway |
| `contato_padre` sem `comunidade` | Contato acontece **pelo WhatsApp**, no canal da conversa. **Não** dá acesso ao grupo — produtos separados |
| Link do grupo | **Individual**, 1 acesso por compradora. Fila em `links_comunidade`, consumida atomicamente na entrega |
| Remoção de inadimplente | Manual, pelo admin, a partir do alerta |

### Fila de links — operação

Não existe API do WhatsApp para gerar convite de grupo, então os links são
criados em lote no app e cadastrados em `links_comunidade`. A entrega consome
um por compradora via `consumir_link_comunidade()`, que é atômica (`for update
skip locked`) — duas compradoras simultâneas nunca recebem o mesmo link. Reenvio
do webhook devolve o mesmo link que já foi entregue àquela lead.

**Se a fila esvaziar**, a cliente recebe "seu link chega em seguida" e o alerta
de entrega dispara para o Rodrigo — nunca um link quebrado ou o placeholder cru.
Conferir estoque: `select * from estoque_links_comunidade;`
