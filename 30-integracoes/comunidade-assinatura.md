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

## Cobrança da mensalidade — decisão pendente ⚠️

A geração da cobrança mensal **ainda não foi construída**, porque o caminho
certo depende de uma resposta que só o painel do BlackCat dá:

**Pergunta ao Rodrigo: o BlackCat suporta assinatura/recorrência nativa?**
(produto do tipo "assinatura", cobrança automática mensal no cartão)

- **Plano A — recorrência nativa do BlackCat** (se existir): a mensalidade vira
  um produto de assinatura no próprio BlackCat; o cartão é cobrado
  automaticamente todo mês, sem link novo. Nosso lado só consome os webhooks
  de renovação/falha. É o caminho profissional: menos atrito, menos churn
  involuntário.
- **Plano B — cron no n8n** (funciona de qualquer jeito): workflow diário lê
  `assinaturas` com `proxima_cobranca <= hoje`, gera um `create-sale` de
  R$ 9,78 com `metadata.tipo='mensalidade'` e envia o link por WhatsApp.
  Pago → `ultimo_pagamento = agora`, `proxima_cobranca += 30 dias`,
  `status='ativa'`. Não pago em 3 dias → lembrete; 7 dias → `inadimplente` e
  alerta ao Rodrigo. **Atenção**: o webhook `paid` precisa distinguir
  mensalidade de compra nova (`metadata.tipo`), senão a renovação sobrescreve
  `produtos_comprados`.

Com a resposta, o fluxo escolhido é construído em um passo.

## Regras de transparência (não negociáveis para funcionar)

- O agente **sempre** informa entrada + mensalidade + 30 dias grátis **na mesma
  mensagem** em que oferece a Comunidade. Isso já está no prompt e na tabela de
  desconto; não remover — mensalidade surpresa é chargeback e denúncia na Meta.
- Cancelamento: quando a cliente pedir para cancelar, `status='cancelada'`,
  sem retenção agressiva. Ela mantém o acesso até o fim do período já pago.
- Inadimplência: quem não paga sai do grupo — **quem remove?** (pergunta
  aberta: o padre/admin manualmente, a partir do alerta? Não há API para
  remover membro de grupo do WhatsApp.)

## Entrega por produto (rascunho para aprovação)

Mídia hospedada no **Supabase Storage** (bucket público `entrega`); as URLs
entram em `produtos.entrega_midia`. O PDF do produto principal já está no repo:
`30-integracoes/entrega/oracao-sagrada-de-sao-bento.pdf` (4 páginas, 8,4 MB).
Os áudios chegam em seguida (Rodrigo vai enviar).

Rascunhos de `entrega_texto` — **aguardando aprovação do Rodrigo**:

- **`oracao_sagrada`** *(o PDF vai anexado antes desta mensagem)*
  > Aqui está a sua Oração Sagrada de São Bento, {nome} 🙏
  > Ela é sua para sempre — salve este arquivo com carinho.
  > O Padre Frei recomenda começar hoje mesmo, num momento de silêncio.

- **`oracao_audio`** *(os áudios vão antes desta mensagem)*
  > Estes são os áudios da Oração, gravados pelo próprio Padre Frei.
  > Pode ouvir onde estiver — em casa, no ônibus, antes de dormir.

- **`comunidade`**
  > Seja bem-vinda à Comunidade do Padre Frei 🙏
  > Toque aqui para entrar: {LINK_DO_GRUPO}
  > Lá você recebe áudios e mensagens diárias do padre, além de conteúdos
  > exclusivos antes de todo mundo. Seus primeiros 30 dias são um presente;
  > depois são só R$ 9,78 por mês, e você cancela quando quiser.

- **`contato_padre`**
  > Seu Contato com o Padre está ativo. Ele acontece dentro da Comunidade —
  > é lá que você encontra o canal direto para deixar sua mensagem e seus
  > pedidos de oração ao Padre Frei.

## Perguntas abertas (bloqueiam o fechamento disto)

1. **BlackCat tem recorrência nativa?** → decide Plano A ou B da mensalidade.
2. **`contato_padre` sem `comunidade`**: o contato acontece *dentro* da
   Comunidade, mas é vendido como produto separado (R$ 19,90). Quem compra o
   contato **sem** a comunidade recebe o quê? Opções: (a) o contato inclui
   acesso à comunidade; (b) só se vende o contato junto da comunidade; (c) há
   um canal de contato fora do grupo. Precisa de decisão antes do primeiro
   lead que comprar só esse item.
3. **Link do grupo**: fixo ou renovado? (link fixo vazado = gente entrando sem
   pagar; link renovado exige atualizar `entrega_texto` de tempos em tempos.)
4. **Quem remove inadimplente do grupo**, e em quanto tempo?
