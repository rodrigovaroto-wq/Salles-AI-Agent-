// Ensaio da validação HMAC do webhook do BravoPay.
//
//   node 30-integracoes/n8n/ensaio/ensaio-hmac.js
//
// Roda o jsCode real do node "Validar assinatura", lido direto do
// pagamento-bravopay.json, contra 11 casos — inclusive tentativas de forjar.
//
// Por que este teste existe: sem a validação, quem descobrir a URL do webhook
// manda um `transaction.paid` forjado e recebe a entrega sem pagar. É o único
// node do projeto onde um erro vira prejuízo direto.
const crypto = require('crypto');
const fs = require('fs');

const wf = JSON.parse(fs.readFileSync(__dirname + '/../workflows/pagamento-bravopay.json', 'utf8'));
const src = wf.nodes.find(n => n.name === 'Validar assinatura').parameters.jsCode;

const SEGREDO = 'segredo-de-teste';

function roda(headers, body, segredo = SEGREDO) {
  const nodes = {
    'BravoPay IN': { json: { headers, body } },
    'Buscar segredo do webhook': { json: segredo === null ? [] : [{ valor: segredo }] },
  };
  const fn = new Function('$node', 'require', src);
  return fn(nodes, require)[0].json;
}

function assina(body, ts, segredo = SEGREDO) {
  const h = crypto.createHmac('sha256', segredo).update(ts + '.' + body).digest('hex');
  return `t=${ts},v1=${h}`;
}

const body = JSON.stringify({
  type: 'transaction.paid',
  data: {
    id: 'tx_teste',
    external_reference: '5511988887777',
    amount_cents: 2290,
    metadata: { produtos: 'oracao_sagrada,oracao_audio' },
  },
});
const agora = Math.floor(Date.now() / 1000);

const CASOS = [
  ['assinatura correta',        () => roda({ 'bravopay-signature': assina(body, agora) }, body), true],
  ['cabecalho x-bravopay',      () => roda({ 'x-bravopay-signature': assina(body, agora) }, body), true],
  ['assinatura forjada',        () => roda({ 'bravopay-signature': `t=${agora},v1=${'ab'.repeat(32)}` }, body), false],
  ['segredo errado',            () => roda({ 'bravopay-signature': assina(body, agora, 'outro') }, body), false],
  ['corpo adulterado depois',   () => roda({ 'bravopay-signature': assina(body, agora) }, body.replace('2290', '999900')), false],
  ['replay de 10 min atras',    () => roda({ 'bravopay-signature': assina(body, agora - 600) }, body), false],
  ['timestamp no futuro',       () => roda({ 'bravopay-signature': assina(body, agora + 600) }, body), false],
  ['sem cabecalho',             () => roda({}, body), false],
  ['cabecalho malformado',      () => roda({ 'bravopay-signature': 'lixo' }, body), false],
  ['sem v1',                    () => roda({ 'bravopay-signature': `t=${agora}` }, body), false],
  ['segredo nao cadastrado',    () => roda({ 'bravopay-signature': assina(body, agora) }, body, null), false],
];

let falhas = 0;
for (const [nome, exec, esperado] of CASOS) {
  let r;
  try { r = exec(); } catch (e) { r = { valido: false, motivo: 'EXCECAO: ' + e.message }; }
  const ok = r.valido === esperado;
  if (!ok) falhas++;
  console.log(`  ${ok ? 'ok   ' : 'FALHA'} ${nome.padEnd(26)} valido=${String(r.valido).padEnd(5)} ${r.motivo || ''}`);
}

// o payload válido tem que sair parseado para o node seguinte
const bom = roda({ 'bravopay-signature': assina(body, agora) }, body);
const parseado = bom.corpo && bom.corpo.data && bom.corpo.data.external_reference === '5511988887777';
console.log(`  ${parseado ? 'ok   ' : 'FALHA'} ${'corpo entregue parseado'.padEnd(26)}`);
if (!parseado) falhas++;

console.log(falhas ? `\n${falhas} falha(s)` : `\ntodos os ${CASOS.length + 1} casos passaram`);
process.exit(falhas ? 1 : 0);
