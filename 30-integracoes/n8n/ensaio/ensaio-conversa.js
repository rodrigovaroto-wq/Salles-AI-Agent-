#!/usr/bin/env node
// Simulador de CONVERSA: caminha o grafo real do agente-vendas.json com um
// estado de lead fingido e mostra, para cada cenário, por onde o fluxo passa e
// o que a lead recebe de fato.
//
// O ensaio de prompt mostra o que o agente *pensaria*. Este mostra o que o
// sistema *faria* — que é onde os dois piores defeitos moraram. Não chama
// OpenAI, não toca no Supabase, não manda WhatsApp: só percorre as conexões e
// avalia as condições dos IF contra um estado sintético.
//
//   node 30-integracoes/n8n/ensaio/ensaio-conversa.js

const fs = require('fs');
const path = require('path');

const wf = JSON.parse(fs.readFileSync(
  path.join(__dirname, '..', 'workflows', 'agente-vendas.json'), 'utf8'));
const NODES = Object.fromEntries(wf.nodes.map((n) => [n.name, n]));
const CONNS = wf.connections;

// ─────────────────────────────────────────────────────────────────────
// Como cada portão decide, dado o estado do cenário. Espelha a condição
// declarada no JSON; o ensaio de topologia garante que os dois lados existem.
// ─────────────────────────────────────────────────────────────────────
const PORTOES = {
  'Mensagem inedita?':   (s) => !s.duplicata,
  'E audio?':            (s) => s.tipo === 'audio',
  'Conversa encerrada?': (s) => s.status === 'opt_out' || s.status === 'aguardando_humano',
  'Tem texto para responder?': (s) => !!s.texto,
  'Ainda sou a ultima?': (s) => !s.superada,
  'OpenAI respondeu?':   (s) => !s.openaiFalhou,
  'Intent = gerar_link?': (s) => s.intent === 'gerar_link',
  'Venda criada?':       (s) => !s.gatewayFalhou,
  'Arquetipo detectado?': (s) => !!s.arquetipo,
  'Intent = sofrimento?': (s) => s.intent === 'sofrimento',
  'Intent = opt_out?':   (s) => s.intent === 'opt_out',
};

// O que cada node significa em linguagem de negócio.
const EFEITOS = {
  'Registrar opt-out':                'GRAVA status=opt_out e consentimento=false',
  'Marcar sofrimento na conversa':    'GRAVA status=aguardando_humano',
  'Enviar alerta de sofrimento':      'AVISA O RODRIGO (handoff de P1)',
  'Enviar resposta ao lead':          'ENVIA a resposta para a lead',
  'Enviar link de pagamento':         'ENVIA o link de pagamento',
  'Enviar pedido de texto':           'ENVIA pedido de texto (midia sem legenda)',
  'Enviar aviso de falha':            'AVISA O RODRIGO (OpenAI falhou)',
  'Enviar falha do link':             'AVISA O RODRIGO (gateway falhou)',
  'Chamar OpenAI':                    'CHAMA A OPENAI (custa dinheiro)',
  'Criar cobranca BravoPay':          'CRIA COBRANCA no gateway',
  'Registrar lead':                   'grava/atualiza a lead',
  'Conversa encerrada (fim silencioso)': 'FIM SILENCIOSO (nada e enviado)',
  'Duplicata ignorada':               'descarta reenvio do WhatsApp',
  'Superada por mensagem nova':       'encerra: outra mensagem chegou antes',
};

function percorrer(estado) {
  const visitados = new Set();
  const trilha = [];
  const fila = ['WhatsApp IN'];

  while (fila.length) {
    const nome = fila.shift();
    if (visitados.has(nome)) continue;
    visitados.add(nome);
    trilha.push(nome);

    const saidas = (CONNS[nome] || {}).main || [];
    const no = NODES[nome];

    if (no && no.type === 'n8n-nodes-base.if') {
      const decisor = PORTOES[nome];
      if (!decisor) throw new Error(`portao sem regra no simulador: ${nome}`);
      const idx = decisor(estado) ? 0 : 1;
      for (const c of (saidas[idx] || [])) fila.push(c.node);
    } else {
      for (const m of saidas) for (const c of (m || [])) fila.push(c.node);
    }
  }
  return { visitados, trilha };
}

const BASE = {
  tipo: 'text', texto: 'oi', status: 'ativo', duplicata: false, superada: false,
  openaiFalhou: false, gatewayFalhou: false, intent: 'qualificando', arquetipo: null,
};

const CENARIOS = [
  { rot: 'Lead nova, pergunta preco', est: {},
    espera: ['Chamar OpenAI', 'Enviar resposta ao lead'],
    naoEspera: ['Conversa encerrada (fim silencioso)', 'Enviar alerta de sofrimento'] },

  { rot: 'P1 — risco a vida', est: { intent: 'sofrimento', texto: 'vou me matar' },
    espera: ['Enviar resposta ao lead', 'Enviar alerta de sofrimento', 'Marcar sofrimento na conversa'],
    naoEspera: ['Criar cobranca BravoPay'] },

  { rot: 'P1 — mensagem SEGUINTE (lead ja marcada)', est: { status: 'aguardando_humano' },
    espera: ['Conversa encerrada (fim silencioso)'],
    naoEspera: ['Chamar OpenAI', 'Enviar resposta ao lead'] },

  { rot: 'P2 — dor sem risco, deve vender', est: { intent: 'qualificando', texto: 'nao aguento mais essa vida' },
    espera: ['Chamar OpenAI', 'Enviar resposta ao lead'],
    naoEspera: ['Enviar alerta de sofrimento', 'Marcar sofrimento na conversa'] },

  { rot: 'Opt-out — pediu para parar', est: { intent: 'opt_out', texto: 'nao me manda mais' },
    espera: ['Enviar resposta ao lead', 'Registrar opt-out'],
    naoEspera: ['Criar cobranca BravoPay'] },

  { rot: 'Opt-out — mensagem SEGUINTE', est: { status: 'opt_out' },
    espera: ['Conversa encerrada (fim silencioso)'],
    naoEspera: ['Chamar OpenAI', 'Enviar resposta ao lead'] },

  { rot: 'Fechamento — gera link', est: { intent: 'gerar_link' },
    espera: ['Criar cobranca BravoPay', 'Enviar link de pagamento', 'Guardar link gerado'],
    naoEspera: ['Enviar falha do link'] },

  { rot: 'Gateway fora do ar', est: { intent: 'gerar_link', gatewayFalhou: true },
    espera: ['Enviar falha do link'],
    naoEspera: ['Enviar link de pagamento'] },

  { rot: 'OpenAI sem saldo', est: { openaiFalhou: true },
    espera: ['Enviar aviso de falha'],
    naoEspera: ['Enviar resposta ao lead'] },

  { rot: 'Reenvio do WhatsApp (duplicata)', est: { duplicata: true },
    espera: ['Duplicata ignorada'],
    naoEspera: ['Chamar OpenAI', 'Enviar resposta ao lead'] },

  { rot: 'Rajada: mensagem superada', est: { superada: true },
    espera: ['Superada por mensagem nova'],
    naoEspera: ['Chamar OpenAI', 'Enviar resposta ao lead'] },

  { rot: 'Audio recebido', est: { tipo: 'audio' },
    espera: ['Transcrever audio (Whisper)', 'Chamar OpenAI'],
    naoEspera: ['Enviar pedido de texto'] },

  { rot: 'Figurinha/imagem (sem texto)', est: { tipo: 'imagem', texto: '' },
    espera: ['Enviar pedido de texto'],
    naoEspera: ['Chamar OpenAI'] },
];

let falhas = 0;
console.log('=== SIMULACAO DE CONVERSA (caminho real no grafo) ===\n');

for (const c of CENARIOS) {
  const estado = { ...BASE, ...c.est };
  const { visitados } = percorrer(estado);

  const faltando = (c.espera || []).filter((n) => !visitados.has(n));
  const indevidos = (c.naoEspera || []).filter((n) => visitados.has(n));
  const ok = !faltando.length && !indevidos.length;
  if (!ok) falhas++;

  console.log(`${ok ? 'ok   ' : 'FALHA'} ${c.rot}`);
  const efeitos = [...visitados].filter((n) => EFEITOS[n]).map((n) => EFEITOS[n]);
  for (const e of efeitos) console.log(`         · ${e}`);
  if (faltando.length)  console.log(`      >> NAO ACONTECEU (devia): ${faltando.join(', ')}`);
  if (indevidos.length) console.log(`      >> ACONTECEU (nao devia): ${indevidos.join(', ')}`);
  console.log('');
}

console.log(falhas === 0
  ? `todos os ${CENARIOS.length} cenarios de conversa se comportaram como esperado`
  : `${falhas} de ${CENARIOS.length} cenarios DIVERGIRAM`);
process.exit(falhas === 0 ? 0 : 1);
