// Marcas e anotações compartilhadas pelos gráficos das páginas e dos PDFs.
import * as Plot from "@observablehq/plot";
import { cores, tamanhos } from "./tokens.js";
import { indice, percentil, quebrarTexto } from "./formatos.js";

// 2018 carrega ressalva metodológica: um único grupo do topo destoa na fonte
// oficial (docs/limitations.md). A faixa entra antes das linhas, para ficar
// atrás delas, e o rótulo vai na base, longe dos picos do próprio ano.
// Sem 2018 na série, não há marca.
export function marca2018({ anos = null, ano = 2018, texto = "não comparável" } = {}) {
  if (anos && !anos.includes(ano)) return [];
  return [
    Plot.rect([{ x1: ano - 0.5, x2: ano + 0.5 }], {
      x1: "x1", x2: "x2", fill: cores.grade, fillOpacity: 0.55
    }),
    Plot.text([texto], {
      x: ano, frameAnchor: "bottom", dy: -6, fill: cores.textoSuave,
      fontSize: tamanhos.nota
    })
  ];
}

export function linhaZero({ eixo = "y" } = {}) {
  const opcoes = { stroke: cores.referencia, strokeWidth: 0.6 };
  return eixo === "y" ? Plot.ruleY([0], opcoes) : Plot.ruleX([0], opcoes);
}

// Último ponto finito de cada série, para rótulos diretos no fim da linha.
export function ultimosPontos(dados, { x, y, z }) {
  const ultimos = new Map();
  for (const d of dados) {
    if (!Number.isFinite(d[x]) || !Number.isFinite(d[y])) continue;
    const atual = ultimos.get(d[z]);
    if (!atual || d[x] > atual[x]) ultimos.set(d[z], d);
  }
  return [...ultimos.values()];
}

// Posições verticais dos rótulos do fim: séries que terminam próximas fariam os
// rótulos se sobrepor. Empurra de baixo para cima, mantendo a ordem vertical
// (que é o que o rótulo direto existe para preservar) e só o necessário.
export function separarRotulos(valores, { amplitude, separacaoMin = 0.05 } = {}) {
  const minimo = separacaoMin * (Number.isFinite(amplitude) && amplitude > 0 ? amplitude : 1);
  const ordem = valores.map((v, i) => [v, i]).sort((a, b) => a[0] - b[0]);
  const saida = new Array(valores.length);
  let anterior = -Infinity;
  for (const [v, i] of ordem) {
    const posicao = v - anterior < minimo ? anterior + minimo : v;
    saida[i] = posicao;
    anterior = posicao;
  }
  return saida;
}

// Rótulo direto no fim de cada linha, na cor da série.
export function rotularNoFim(dados, { x, y, z, texto = z, cor, separacaoMin = 0.05, dx = 8, fontSize = tamanhos.anotacao }) {
  const finitos = dados.filter((d) => Number.isFinite(d[x]) && Number.isFinite(d[y]));
  if (finitos.length === 0) return [];
  const valoresY = finitos.map((d) => d[y]);
  const amplitude = Math.max(...valoresY) - Math.min(...valoresY);
  const ultimos = ultimosPontos(finitos, { x, y, z });
  const posicoes = separarRotulos(ultimos.map((d) => d[y]), { amplitude, separacaoMin });
  const rotulos = ultimos.map((d, i) => ({ ...d, __y: posicoes[i] }));
  return [Plot.text(rotulos, {
    x, y: "__y", text: typeof texto === "function" ? texto : (d) => d[texto],
    fill: cor ?? z, textAnchor: "start", dx, fontSize
  })];
}

// Primeiro e último valor rotulados: o leitor lê os extremos sem mirar o eixo.
export function rotularExtremos(dados, { x, y, formatar = indice(0.001), cor = cores.tinta, fontSize = tamanhos.anotacao }) {
  const finitos = dados
    .filter((d) => Number.isFinite(d[x]) && Number.isFinite(d[y]))
    .sort((a, b) => a[x] - b[x]);
  if (finitos.length === 0) return [];
  const primeiro = finitos[0];
  const ultimo = finitos[finitos.length - 1];
  const marcas = [Plot.text([primeiro], {
    x, y, text: (d) => formatar(d[y]), textAnchor: finitos.length > 1 ? "start" : "middle",
    dx: finitos.length > 1 ? 4 : 0, dy: -10, fill: cor, fontSize
  })];
  if (finitos.length > 1) {
    marcas.push(Plot.text([ultimo], {
      x, y, text: (d) => formatar(d[y]), textAnchor: "end", dx: -4, dy: -10, fill: cor, fontSize
    }));
  }
  return marcas;
}

// Grupos disjuntos do topo: o centil 99, os dez décimos do top 1% e os dez do
// top 0,1%. Em eixo linear de percentil eles ocupam 2% da largura; em eixo
// ordinal, cada um ganha a mesma largura.
export const codigosTopo = Object.freeze([99, 101, 102, 103, 104, 105, 106, 107, 108, 109,
  111, 112, 113, 114, 115, 116, 117, 118, 119, 120]);

export function eixoOrdinalTopo(limitesSuperiores) {
  const unicos = [...new Set(limitesSuperiores.filter(Number.isFinite))].sort((a, b) => a - b);
  const rotulos = percentil(unicos);
  const mapa = new Map(unicos.map((v, i) => [v, rotulos[i]]));
  return { dominio: rotulos, rotular: (v) => mapa.get(v) ?? percentil(v) };
}

// Título, subtítulo e nota dentro do SVG, para as figuras dos PDFs. O texto é
// quebrado por caracteres (como o strwrap do R), e as margens crescem com o
// número de linhas: nada é cortado na largura da figura.
export function cabecalho({ titulo = null, subtitulo = null, nota = null, largura = 560 } = {}) {
  const porCaractereTitulo = Math.floor(largura / 8.4);
  const porCaractereTexto = Math.floor(largura / 6.6);
  const t = titulo ? quebrarTexto(titulo, porCaractereTitulo) : null;
  const s = subtitulo ? quebrarTexto(subtitulo, porCaractereTexto) : null;
  const n = nota ? quebrarTexto(nota, Math.floor(largura / 5.6)) : null;
  const linhas = (x) => (x ? x.split("\n").length : 0);
  const alturaTitulo = linhas(t) * 19;
  const alturaSub = linhas(s) * 16;
  const topo = 12 + alturaTitulo + (s ? 4 + alturaSub : 0) + 16;
  const base = n ? 14 + linhas(n) * 13 : 0;
  const marcas = [];
  if (t) {
    marcas.push(Plot.text([t], {
      frameAnchor: "top-left", lineAnchor: "top", textAnchor: "start",
      dy: -topo + 8, fontSize: tamanhos.titulo, fontWeight: "bold", fill: cores.tinta, lineHeight: 1.25
    }));
  }
  if (s) {
    marcas.push(Plot.text([s], {
      frameAnchor: "top-left", lineAnchor: "top", textAnchor: "start",
      dy: -topo + 12 + alturaTitulo, fontSize: tamanhos.subtitulo, fill: cores.textoSuave, lineHeight: 1.3
    }));
  }
  if (n) {
    marcas.push(Plot.text([n], {
      frameAnchor: "bottom-left", lineAnchor: "top", textAnchor: "start",
      dy: base - linhas(n) * 13 + 22, fontSize: tamanhos.nota, fill: cores.textoSuave, lineHeight: 1.25
    }));
  }
  return { marcas, margemTopo: topo, margemBase: base };
}
