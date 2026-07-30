#!/usr/bin/env node
// Ensaio de TOPOLOGIA dos workflows.
//
// Os outros dois ensaios validam o que o agente *pensa* (prompt) e o que ele
// *aceita* (HMAC). Nenhum dos dois olha por onde o fluxo **passa** — e foi
// exatamente aí que moraram os dois piores defeitos do projeto:
//
//   - o portão de opt-out com as saídas invertidas (toda lead caía no fim
//     silencioso e ninguém era respondido);
//   - a saída `true` do "Intent = sofrimento?" vazia (P1 era detectado e nada
//     acontecia: nem handoff, nem alerta, nem registro no banco).
//
// Os dois passariam por qualquer teste de prompt. Este arquivo fecha a lacuna.
//
//   node 30-integracoes/n8n/ensaio/ensaio-topologia.js

const fs = require('fs');
const path = require('path');

const DIR = path.join(__dirname, '..', 'workflows');
const IGNORAR = new Set(['workflow-completo.json']);

// ─────────────────────────────────────────────────────────────────────
// Caminhos que precisam existir, nome a nome. Cada linha é uma regra de
// negócio que já quebrou uma vez.
// ─────────────────────────────────────────────────────────────────────
const CAMINHOS_OBRIGATORIOS = {
  'agente-vendas.json': [
    { de: 'Intent = sofrimento?', saida: 0, ate: 'Marcar sofrimento na conversa',
      porque: 'P1 sem handoff: o agente detecta risco a vida e nao avisa ninguem nem marca aguardando_humano' },
    { de: 'Intent = opt_out?', saida: 0, ate: 'Registrar opt-out',
      porque: 'quem pede para parar continua recebendo mensagem' },
    { de: 'Conversa encerrada?', saida: 1, ate: 'Chamar OpenAI',
      porque: 'lead normal nao chega ao agente' },
    { de: 'Mensagem inedita?', saida: 0, ate: 'Chamar OpenAI',
      porque: 'mensagem nova nao e processada' },
    { de: 'Mensagem inedita?', saida: 1, ate: 'Duplicata ignorada',
      porque: 'reenvio do WhatsApp seria respondido duas vezes' },
    { de: 'Consumir buffer', saida: 0, ate: 'Chamar OpenAI',
      porque: 'o texto da lead nao chega no modelo' },
    { de: 'OpenAI respondeu?', saida: 1, ate: 'Enviar aviso de falha',
      porque: 'falha da OpenAI vira silencio para a lead' },
    { de: 'Venda criada?', saida: 1, ate: 'Enviar falha do link',
      porque: 'falha do gateway vira silencio para quem quis comprar' },
  ],
  'pagamento-bravopay.json': [
    { de: 'Assinatura valida?', saida: 0, ate: 'Registrar compra',
      porque: 'webhook legitimo nao registra a venda' },
    { de: 'Assinatura valida?', saida: 1, ate: 'Webhook recusado (assinatura invalida)',
      porque: 'webhook forjado seguiria para a entrega' },
    { de: 'Webhook inedito?', saida: 1, ate: 'Reenvio ignorado',
      porque: 'reenvio do gateway entregaria o produto duas vezes' },
    { de: 'event = paid?', saida: 0, ate: 'Enviar entrega',
      porque: 'quem pagou nao recebe' },
    { de: 'Falta conteudo de entrega?', saida: 0, ate: 'Enviar alerta de entrega',
      porque: 'cliente paga por algo sem conteudo cadastrado e ninguem e avisado' },
  ],
};

// Saídas que podem terminar sem destino: ramos paralelos de efeito colateral
// que simplesmente nao fazem nada no caso negativo.
const TERMINAIS_ACEITOS = new Set([
  'agente-vendas.json::Intent = opt_out?::1',
  'pagamento-bravopay.json::Tem assinatura?::1',
]);

// ─────────────────────────────────────────────────────────────────────

function carregar(arq) {
  const wf = JSON.parse(fs.readFileSync(path.join(DIR, arq), 'utf8'));
  const nomes = new Set(wf.nodes.map((n) => n.name));
  const conns = wf.connections || {};
  return { wf, nomes, conns };
}

function destinos(conns, no, saida) {
  const m = (conns[no] || {}).main || [];
  return (m[saida] || []).map((c) => c.node);
}

// Existe caminho de `de` (a partir da saída indicada) ate `ate`?
function alcanca(conns, de, saida, ate) {
  const vistos = new Set();
  const fila = [...destinos(conns, de, saida)];
  while (fila.length) {
    const atual = fila.shift();
    if (atual === ate) return true;
    if (vistos.has(atual)) continue;
    vistos.add(atual);
    for (const m of ((conns[atual] || {}).main || [])) {
      for (const c of (m || [])) fila.push(c.node);
    }
  }
  return false;
}

let falhas = 0;
let checagens = 0;
const linhas = [];

function reportar(ok, arq, msg, porque) {
  checagens++;
  if (!ok) falhas++;
  linhas.push(`  ${ok ? 'ok  ' : 'FALHA'}  ${arq.replace('.json', '').padEnd(20)} ${msg}${ok || !porque ? '' : `\n           -> ${porque}`}`);
}

const arquivos = fs.readdirSync(DIR)
  .filter((f) => f.endsWith('.json') && !IGNORAR.has(f))
  .sort();

console.log('=== 1. NOS ORFAOS (existem no canvas e nunca recebem dados) ===');
for (const arq of arquivos) {
  const { wf, conns } = carregar(arq);
  const alvos = new Set();
  for (const o of Object.values(conns)) {
    for (const m of (o.main || [])) for (const c of (m || [])) alvos.add(c.node);
  }
  const orfaos = wf.nodes
    .filter((n) => !/trigger|webhook/i.test(n.type))
    .filter((n) => !alvos.has(n.name))
    .map((n) => n.name);
  reportar(orfaos.length === 0, arq,
    orfaos.length ? `orfaos: ${orfaos.join(', ')}` : 'nenhum orfao',
    'um no que nunca recebe dados nunca roda -- o efeito dele simplesmente nao acontece');
}

console.log(linhas.splice(0).join('\n'));

console.log('\n=== 2. SAIDAS DE IF SEM DESTINO (ramo morto) ===');
for (const arq of arquivos) {
  const { wf, conns } = carregar(arq);
  for (const n of wf.nodes.filter((x) => x.type === 'n8n-nodes-base.if')) {
    const m = (conns[n.name] || {}).main || [];
    for (const saida of [0, 1]) {
      const chave = `${arq}::${n.name}::${saida}`;
      const vazia = !(m[saida] || []).length;
      if (vazia && TERMINAIS_ACEITOS.has(chave)) {
        linhas.push(`  ok    ${arq.replace('.json', '').padEnd(20)} ${n.name} [${saida}] vazia (terminal aceito)`);
        checagens++;
        continue;
      }
      reportar(!vazia, arq, `${n.name} [${saida}] ${vazia ? 'VAZIA' : 'ligada'}`,
        'metade da decisao nao leva a lugar nenhum');
    }
  }
}
console.log(linhas.splice(0).join('\n'));

console.log('\n=== 3. CAMINHOS OBRIGATORIOS ===');
for (const [arq, regras] of Object.entries(CAMINHOS_OBRIGATORIOS)) {
  const { nomes, conns } = carregar(arq);
  for (const r of regras) {
    if (!nomes.has(r.de) || !nomes.has(r.ate)) {
      reportar(false, arq, `${r.de} [${r.saida}] ~> ${r.ate}  (no inexistente)`, r.porque);
      continue;
    }
    reportar(alcanca(conns, r.de, r.saida, r.ate), arq,
      `${r.de} [${r.saida}] ~> ${r.ate}`, r.porque);
  }
}
console.log(linhas.splice(0).join('\n'));

console.log('\n=== 4. REFERENCIAS $node A NOS INEXISTENTES ===');
for (const arq of arquivos) {
  const { wf, nomes } = carregar(arq);
  const quebradas = [];
  for (const n of wf.nodes) {
    const txt = JSON.stringify(n.parameters || {});
    for (const m of txt.matchAll(/\$node\[\\?"([^"\\]+)\\?"\]/g)) {
      if (!nomes.has(m[1])) quebradas.push(`${n.name} -> $node["${m[1]}"]`);
    }
  }
  reportar(quebradas.length === 0, arq,
    quebradas.length ? `referencias quebradas: ${[...new Set(quebradas)].join('; ')}` : 'todas as referencias $node existem',
    'expressao aponta para um no que nao existe: vira undefined em runtime');
}
console.log(linhas.splice(0).join('\n'));

console.log('\n=== 5. PLACEHOLDERS AINDA ABERTOS ===');
let placeholders = 0;
for (const arq of arquivos) {
  const txt = fs.readFileSync(path.join(DIR, arq), 'utf8');
  const achados = [...txt.matchAll(/<<[A-Z_]+>>/g)].map((m) => m[0]);
  if (achados.length) {
    placeholders += achados.length;
    const contagem = {};
    for (const a of achados) contagem[a] = (contagem[a] || 0) + 1;
    console.log(`  ${arq.replace('.json', '').padEnd(20)} ${Object.entries(contagem).map(([k, v]) => `${k} x${v}`).join(', ')}`);
  }
}
if (!placeholders) console.log('  nenhum');
else console.log(`  (${placeholders} ocorrencias -- nao sao falha de topologia, mas o fluxo nao funciona ao vivo enquanto estiverem la)`);

console.log(`\n${falhas === 0 ? `todas as ${checagens} checagens de topologia passaram` : `${falhas} de ${checagens} checagens FALHARAM`}`);
process.exit(falhas === 0 ? 0 : 1);
