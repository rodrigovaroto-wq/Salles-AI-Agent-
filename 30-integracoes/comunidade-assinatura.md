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
| Link do grupo (único, universal) | `migracao-config.sql` + nó "Buscar link da comunidade" | pronto, falta rodar e preencher |
| Cobrança mensal automática (Pagar.me) | `pagarme/README.md` | especificada; workflow aguarda doc do BravoPay |

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

## Cobrança da mensalidade — resolvida com Pagar.me (27/07)

**Decisão:** BlackCat sai, entram **BravoPay** (Pix/avulso) e **Pagar.me**
(cartão e assinatura).

O BlackCat não tinha como fazer isso: sem tokenização e sem recorrência,
cobrar todo mês exigiria guardar número e CVV do cartão — proibido pelo
PCI-DSS — e pedir cartão dentro do WhatsApp. O Pagar.me resolve pelo caminho
certo: **checkout hospedado**. A cliente recebe um link, preenche o cartão na
página do Pagar.me, e a cobrança mensal roda sozinha a partir do dia 31. O
cartão nunca passa pelo nosso lado.

Detalhes de integração em [`pagarme/README.md`](pagarme/README.md).

```
dia 0   entrada R$ 44,90 + cadastro do cartão (checkout Pagar.me)
        └─ subscription.created → assinaturas: trial até o dia 30
        └─ order.paid           → entrega
dia 31  Pagar.me cobra R$ 9,78 no cartão, sozinho
        charge.paid           → proxima_cobranca += 30d, status='ativa'
        charge.payment_failed → status='inadimplente' + alerta
```

**Ainda não construído**: o workflow `pagamento-pagarme.json` aguarda a
documentação do BravoPay, para não construir o mesmo webhook duas vezes.

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
| `comunidade` | — | boas-vindas + `{LINK_COMUNIDADE}` + mensalidade |
| `contato_padre` | — | "Ele acontece aqui pelo WhatsApp…" |

`{LINK_COMUNIDADE}` é substituído em runtime pelo valor de
`configuracoes.link_comunidade`. Não use `{nome}` nos textos de entrega: o
webhook não carrega o nome da lead nesse ponto do fluxo.

## Decisões de 27/07

| Questão | Decisão |
|---|---|
| Gateway de cartão/assinatura | **Pagar.me** (checkout hospedado). BlackCat sai; BravoPay assume Pix/avulso |
| `contato_padre` sem `comunidade` | Contato acontece **pelo WhatsApp**, no canal da conversa. **Não** dá acesso ao grupo — produtos separados |
| Link do grupo | **Único e universal**, o mesmo para todas. Guardado em `configuracoes.link_comunidade` |
| Remoção de inadimplente | Manual, pelo admin, a partir do alerta |

### Link do grupo — operação

Link único e universal, guardado em `configuracoes.link_comunidade` e
substituído em runtime no lugar de `{LINK_COMUNIDADE}`. Trocar o link é um
`UPDATE` numa linha — não mexe no texto de entrega nem republica workflow.

Se a chave ainda estiver com o placeholder `<<COLE_AQUI_O_LINK_DO_GRUPO>>`, a
entrega **não** manda o placeholder cru: a cliente recebe "seu link chega em
seguida" e o alerta dispara para o Rodrigo.

O texto de entrega **não** afirma que o link é pessoal ou de uso único — com um
link universal isso seria falso, e é o tipo de frase que vira reclamação quando
a cliente descobre. Ela recebe o link e a mensagem de boas-vindas, sem promessa
de exclusividade.
