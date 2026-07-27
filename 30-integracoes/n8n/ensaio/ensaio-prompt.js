// Ensaio local do node "Montar mensagens OpenAI".
// Roda o jsCode real extraido do agente-vendas.json contra contexto simulado,
// com o conteudo real de prompt_ativo e o catalogo real do schema.sql.
// Nao chama OpenAI, nao escreve no Supabase, nao cria cobranca no BlackCat.
const fs = require('fs');

const NUCLEO = __dirname + '/../../../00-nucleo/';
const PROMPTS = [
  { chave: 'objetivo',   conteudo: fs.readFileSync(NUCLEO + 'objetivo.md', 'utf8') },
  { chave: 'compliance', conteudo: fs.readFileSync(NUCLEO + 'compliance-e-etica.md', 'utf8') },
  { chave: 'objecoes',   conteudo: fs.readFileSync(NUCLEO + 'objecoes.md', 'utf8') },
];

// catalogo identico ao insert do schema.sql
const PRODUTOS = [
  { produto_id:'oracao_sagrada', nome:'Oração Sagrada',            tipo:'principal',  preco_centavos:2290, ordem:0, resolve_objecao:[], arquetipos:[] },
  { produto_id:'oracao_audio',   nome:'Oração em Áudio',           tipo:'order_bump', preco_centavos:1390, ordem:1, resolve_objecao:['preco','sem_interesse_principal','vou_pensar'], arquetipos:['guerreira_fe'] },
  { produto_id:'comunidade',     nome:'Comunidade',                tipo:'order_bump', preco_centavos:4490, ordem:2, resolve_objecao:[], arquetipos:['mae_protetora','mulher_pertence'] },
  { produto_id:'contato_padre',  nome:'Contato Direto com o Padre',tipo:'order_bump', preco_centavos:1990, ordem:3, resolve_objecao:[], arquetipos:['devota_busca'] },
];

function montar({ texto, historico = [], lead = {}, origem = 'lp' }) {
  const ctx = { prompts: PROMPTS, produtos: PRODUTOS, lead, historico: historico.slice().reverse() };
  const nodes = {
    'Carregar contexto': { json: ctx },
    'Extrair mensagem e origem': { json: { origem } },
    'Consumir buffer': { json: texto },
  };
  const wf = JSON.parse(fs.readFileSync(__dirname + '/../workflows/agente-vendas.json', 'utf8'));
  const src = wf.nodes.find(n => n.name === 'Montar mensagens OpenAI').parameters.jsCode;
  const fn = new Function('$node', src);
  return fn(nodes)[0].json;
}

const CENARIOS = [
  { rot:'1. Abertura vinda da LP', texto:'vi o anuncio e quero saber mais' },
  { rot:'2. Preço',       texto:'quanto custa?' },
  { rot:'3. Aceite',      texto:'quero sim' },
  { rot:'4. Stack',       texto:'vou levar tudo' },
  { rot:'5. Dados',       texto:'maria@teste.com, 111.444.777-35' },
  { rot:'6. Objeção cara',texto:'esta caro demais, vou pensar' },
  { rot:'7. Garantia',    texto:'tem garantia? e se eu nao gostar?' },
  { rot:'8. SOFRIMENTO',  texto:'perdi meu filho mes passado, nao tenho vontade de viver' },
  { rot:'9. SOFRIMENTO + lead ja sinalizada', texto:'mas me fala do produto',
    lead:{ status:'aguardando_humano' } },
  { rot:'10. Cliente que ja comprou', texto:'como acesso?',
    lead:{ produtos_comprados:[{produto_id:'oracao_sagrada'}] } },
];

const TOK = s => Math.round(s.length / 3.7);
let linhas = [];

for (const c of CENARIOS) {
  const out = montar({ texto: c.texto, lead: c.lead || {} });
  const sys = out.messages[0].content;
  const secoes = (sys.match(/^## [A-Q]\./gm) || []).map(s => s.replace('## ','').slice(0,2));
  linhas.push({
    cenario: c.rot,
    tokens: TOK(sys),
    objecoes: secoes.join(' ') || '(so nucleo)',
    modoSemVenda: /MODO SEM VENDA/.test(sys) ? 'SIM' : '-',
    tabela: /Total: R\$/.test(sys) ? 'sim' : '-',
    jaComprou: /JA COMPROU/.test(sys) ? 'sim' : '-',
  });
}

console.log('| cenario | tokens | secoes de objecao | modo s/ venda | tabela | ja comprou |');
console.log('|---|---|---|---|---|---|');
for (const l of linhas) {
  console.log(`| ${l.cenario} | ${l.tokens} | ${l.objecoes} | ${l.modoSemVenda} | ${l.tabela} | ${l.jaComprou} |`);
}

// ---- verificacoes de guardrail ----
console.log('\n=== GUARDRAILS (system prompt de cada cenario) ===');
const checks = [
  ['CVV 188 sempre presente',      s => /CVV 188/.test(s)],
  ['intent sofrimento disponivel', s => /intent="sofrimento"/.test(s)],
  ['opt_out disponivel',           s => /intent="opt_out"/.test(s)],
  ['pare de vender no BLOCO_A',    s => /Pare de vender/.test(s)],
  ['schema JSON de resposta',      s => /"mensagens": string\[\]/.test(s)],
  ['nunca inventar produto/preco', s => /nunca invente produto ou preco/.test(s)],
];
let falhas = 0;
for (const c of CENARIOS) {
  const sys = montar({ texto: c.texto, lead: c.lead || {} }).messages[0].content;
  for (const [nome, f] of checks) if (!f(sys)) { console.log(`  FALHA "${nome}" em ${c.rot}`); falhas++; }
}
console.log(falhas ? `\n${falhas} falha(s)` : '  todos ok nos 10 cenarios');

// ---- prefixo de cache: BLOCO_A tem que ser byte-identico entre leads ----
console.log('\n=== PREFIXO DE CACHE ===');
const marca = 'Origem do lead nesta conversa:';
const prefixos = CENARIOS.map(c => {
  const s = montar({ texto: c.texto, lead: c.lead || {} }).messages[0].content;
  const i = s.indexOf(marca);
  const corte = s.slice(0, i > 0 ? i : s.length);
  // o bloco sob demanda entra antes da marca; o estatico termina no fim do BLOCO_A
  return corte.split('GUIA DE OBJECOES -- SECOES RELEVANTES')[0];
});
const iguais = prefixos.every(p => p === prefixos[0]);
console.log(`  BLOCO_A identico nos 10 cenarios: ${iguais ? 'SIM' : 'NAO -- cache quebrado'}`);
console.log(`  tamanho do prefixo estatico: ~${TOK(prefixos[0])} tokens`);
