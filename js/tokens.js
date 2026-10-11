// Tokens visuais do projeto: as mesmas cores das páginas (styles/site.scss) e
// dos gráficos, no navegador e nas figuras dos relatórios.
//
// Cada cor tem um significado só. O mesmo âmbar já foi "RB3" num gráfico e
// "ponto de destaque" em outro; aqui a paleta qualitativa (Okabe-Ito) serve a
// categorias sem ordem e a rampa ordinal (mako) a séries aninhadas.

export const cores = Object.freeze({
  tinta: "#101D40",
  textoSuave: "#586179",
  grade: "#DBE3EF",
  referencia: "#7D8BA1",
  contexto: "#6B7890",
  fundo: "#FFFFFF",
  semValor: "#E9ECEF",
  azul: "#156DF9"
});

// Okabe-Ito: segura para as formas comuns de daltonismo.
export const destaque = Object.freeze([
  "#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9", "#000000"
]);

export function corDestaque(n = 1) {
  return destaque.slice(0, Math.min(Math.max(n, 0), destaque.length));
}

// viridisLite::mako(max(n, 2), begin = 0.22, end = 0.78, direction = -1),
// gerada uma vez em R e fixada aqui: d3 não tem a mako, e a rampa precisa ser
// idêntica nas páginas e nos PDFs. Do mais claro (grupo mais amplo) ao mais
// escuro (grupo mais restrito).
const mako = Object.freeze({
  1: ["#55CAAD"],
  2: ["#55CAAD", "#3B2E5D"],
  3: ["#55CAAD", "#357BA2", "#3B2E5D"],
  4: ["#55CAAD", "#3495A9", "#385F9C", "#3B2E5D"],
  5: ["#55CAAD", "#36A2AB", "#357BA2", "#3D5195", "#3B2E5D"],
  6: ["#55CAAD", "#38AAAC", "#348BA6", "#366A9F", "#40498E", "#3B2E5D"],
  7: ["#55CAAD", "#3BAFAD", "#3495A9", "#357BA2", "#385F9C", "#414387", "#3B2E5D"],
  8: ["#55CAAD", "#3DB4AD", "#359CAA", "#3486A5", "#366FA0", "#3B5799", "#414081", "#3B2E5D"]
});

export function corOrdinal(n, { inverter = false } = {}) {
  if (!(n > 0)) return [];
  const rampa = [...(mako[Math.min(n, 8)] ?? mako[8])];
  return inverter ? rampa.reverse() : rampa;
}

// Séries de referência ("todos os declarantes" ao lado dos grupos do topo) não
// fazem parte do aninhamento: ficam em cinza e fora da rampa.
export function coresOrdinais(niveis, { contexto = [], inverter = false } = {}) {
  const ordenados = niveis.filter((n) => !contexto.includes(n));
  const rampa = corOrdinal(ordenados.length, { inverter });
  const mapa = new Map(ordenados.map((n, i) => [n, rampa[i]]));
  for (const c of contexto) mapa.set(c, cores.contexto);
  return niveis.map((n) => mapa.get(n));
}

// A primeira família é a dos PDFs (Typst carrega a Noto Sans de styles/fonts);
// no navegador, as páginas já servem a Noto Sans como webfont.
export const fonte = '"Noto Sans", "Segoe UI", system-ui, sans-serif';

export const tamanhos = Object.freeze({ texto: 12, titulo: 15, subtitulo: 12, nota: 10, anotacao: 11 });
