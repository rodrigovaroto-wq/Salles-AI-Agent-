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
  { produto_id:'comunidade',     nome:'Comunidade',                tipo:'order_bump', preco_centavos:4490, ordem:2, resolve_objecao:[], arquetipos:['mae_protetora','mulher_pertence'], mensalidade_centavos:978, trial_dias:30 },
  { produto_id:'contato_padre',  nome:'Contato Direto com o Padre',tipo:'order_bump', preco_centavos:1990, ordem:3, resolve_objecao:[], arquetipos:['devota_busca'], mensalidade_centavos:547, trial_dias:30 },
];

const AUDIOS = [
  { chave:'saudacao', url:'https://ex/01.mp3', descricao:'Padre Frei cumprimenta quem chegou',
    quando_usar:'Logo na abertura, na primeira resposta.' },
  { chave:'acolhimento_dor', url:'https://ex/04.mp3', descricao:'Padre Frei acolhe quem sofre',
    quando_usar:'Dor real sem risco a vida (P2). NUNCA em P1.' },
  { chave:'acolhimento_preco', url:'https://ex/11.mp3', descricao:'Padre Frei acolhe quem esta apertado',
    quando_usar:'Quando a lead diz que esta caro ou sem condicoes.' },
];

function montar({ texto, historico = [], lead = {}, origem = 'lp' }) {
  const ctx = { prompts: PROMPTS, produtos: PRODUTOS, audios: AUDIOS, lead, historico: historico.slice().reverse() };
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
  { rot:'8. P1 risco a vida', texto:'perdi meu filho mes passado, nao tenho vontade de viver' },
  { rot:'9. P1 + lead ja sinalizada', texto:'mas me fala do produto',
    lead:{ status:'aguardando_humano' } },
  { rot:'11. P2 luto sem risco',   texto:'perdi minha mae ano passado, ainda doi muito' },
  { rot:'12. P2 divida pesada',    texto:'to no fundo do poco com as dividas, nao aguento mais essa situacao' },
  { rot:'13. P2 doenca na familia',texto:'meu marido ta doente e eu to sozinha nisso' },
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
  ['as duas faixas P1/P2 no prompt', s => /P1 = RISCO A VIDA/.test(s) && /P2 = DOR REAL SEM RISCO/.test(s)],
  ['regra de desempate P2',        s => /NA DUVIDA ENTRE P1 E P2, TRATE COMO P2/.test(s)],
  ['proibido emendar oferta na dor', s => /nunca emende oferta na dor/.test(s)],
  ['intent sofrimento disponivel', s => /intent="sofrimento"/.test(s)],
  ['opt_out disponivel',           s => /intent="opt_out"/.test(s)],
  ['P1 manda parar de vender',     s => /pare de vender, nao ofereca produto, nao cite preco/i.test(s)],
  ['schema JSON de resposta',      s => /"mensagens": string\[\]/.test(s)],
  ['nunca inventar produto/preco', s => /nunca invente produto ou preco/.test(s)],
  ['catalogo de audios no prompt', s => /AUDIOS DISPONIVEIS/.test(s) && /acolhimento_dor/.test(s)],
  ['audio nao se repete',          s => /NUNCA repita um audio ja enviado/.test(s)],
  ['mensalidade do contato_padre', s => /R\$ 5,47\/mes apos 30 dias gratis/.test(s) || /JA COMPROU/.test(s) && !/contato_padre \(order_bump\)/.test(s)],
  ['audio proibido em P1',         s => /NUNCA envie audio em P1/.test(s)],
  ['campo audio no schema JSON',   s => /"audio": string\|null/.test(s)],
  ['mensalidade divulgada no catalogo', s => /ASSINATURA: entrada unica acima \+ R\$ 9,78\/mes apos 30 dias gratis/.test(s) || /JA COMPROU/.test(s) && !/comunidade \(order_bump\)/.test(s)],
  ['mensalidade na tabela de desconto', s => !/Total: R\$/.test(s) || /30 dias gratis para conhecer; depois R\$ 9,78\/mes/.test(s)],
];
let falhas = 0;
for (const c of CENARIOS) {
  const sys = montar({ texto: c.texto, lead: c.lead || {} }).messages[0].content;
  for (const [nome, f] of checks) if (!f(sys)) { console.log(`  FALHA "${nome}" em ${c.rot}`); falhas++; }
}
console.log(falhas ? `\n${falhas} falha(s)` : `  todos ok nos ${CENARIOS.length} cenarios`);

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
console.log(`  BLOCO_A identico nos ${CENARIOS.length} cenarios: ${iguais ? 'SIM' : 'NAO -- cache quebrado'}`);
console.log(`  tamanho do prefixo estatico: ~${TOK(prefixos[0])} tokens`);
