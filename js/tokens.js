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

// viridisLite::mako(max(n, 2), begin = 0.22, end = 0.60, direction = -1),
// gerada uma vez em R e fixada aqui: d3 não tem a mako, e a rampa precisa ser
// idêntica nas páginas e nos PDFs. Do mais claro (grupo mais amplo) ao mais
// escuro (grupo mais restrito). A ponta clara para em 0,60 (#3497A9, 3,4:1
// contra o branco): a 0,78 do painel antigo (#55CAAD) dava 2:1 e não atingia o
// mínimo de 3:1 para linhas e marcas (WCAG 1.4.11).
const mako = Object.freeze({
  1: ["#3497A9"],
  2: ["#3497A9", "#3B2E5D"],
  3: ["#3497A9", "#38609D", "#3B2E5D"],
  4: ["#3497A9", "#3573A1", "#3F4C93", "#3B2E5D"],
  5: ["#3497A9", "#357CA3", "#38609D", "#414387", "#3B2E5D"],
  6: ["#3497A9", "#3481A4", "#366B9F", "#3C5598", "#413E7F", "#3B2E5D"],
  7: ["#3497A9", "#3485A5", "#3573A1", "#38609D", "#3F4C93", "#403C79", "#3B2E5D"],
  8: ["#3497A9", "#3487A6", "#3578A2", "#37699F", "#3B589A", "#40488D", "#403A76", "#3B2E5D"]
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

// Contraste WCAG entre uma cor e o fundo branco.
function canal(c) {
  const v = c / 255;
  return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
}

function rgbDe(hex) {
  const h = hex.replace("#", "");
  return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
}

export function contrasteComBranco(hex) {
  const [r, g, b] = rgbDe(hex).map(canal);
  const luminancia = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  return 1.05 / (luminancia + 0.05);
}

// Cor de rótulo de texto: a cor da série, escurecida em direção à tinta só o
// necessário para chegar a 4,5:1 contra o branco (WCAG 1.4.3). O rótulo segue
// reconhecível como da série e legível em 11 px.
export function corTexto(hex, minimo = 4.5) {
  if (typeof hex !== "string" || !/^#[0-9a-fA-F]{6}$/.test(hex)) return hex;
  const origem = rgbDe(hex);
  const alvo = rgbDe(cores.tinta);
  for (let passo = 0; passo <= 20; passo++) {
    const t = passo / 20;
    const mistura = origem.map((c, i) => Math.round(c + (alvo[i] - c) * t));
    const candidato = `#${mistura.map((c) => c.toString(16).padStart(2, "0")).join("")}`.toUpperCase();
    if (contrasteComBranco(candidato) >= minimo) return candidato;
  }
  return cores.tinta;
}

// A primeira família é a dos PDFs (Typst carrega a Noto Sans de styles/fonts);
// no navegador, as páginas já servem a Noto Sans como webfont.
export const fonte = '"Noto Sans", "Segoe UI", system-ui, sans-serif';

export const tamanhos = Object.freeze({ texto: 12, titulo: 15, subtitulo: 12, nota: 10, anotacao: 11 });
