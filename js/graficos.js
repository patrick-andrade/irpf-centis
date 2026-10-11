// Gráficos do projeto, iguais nas páginas Explorar (navegador) e nas figuras dos
// relatórios (Node + jsdom). Cada função recebe os dados já preparados em R e
// devolve o elemento SVG do Plot. `interativo` acrescenta a dica e o ponteiro,
// que só fazem sentido no navegador; `document` permite desenhar no jsdom.
import * as Plot from "@observablehq/plot";
import { quantile } from "d3";
import { cores, fonte, tamanhos, corDestaque, corOrdinal } from "./tokens.js";
import { eixoIndice, eixoParticipacao, eixoDinheiro, eixoAno } from "./escalas.js";
import { marca2018, rotularNoFim, rotularExtremos, linhaZero, cabecalho, eixoOrdinalTopo } from "./marcas.js";
import { indice, percentual } from "./formatos.js";

const finito = (v) => typeof v === "number" && Number.isFinite(v);

export function eixoValor(tipo, valores, opcoes = {}) {
  if (tipo === "participacao" || tipo === "aliquota") return eixoParticipacao(valores, opcoes);
  if (tipo === "dinheiro") return eixoDinheiro(valores, opcoes);
  return eixoIndice(valores, opcoes);
}

// Largura aproximada de um texto em px (Noto Sans 11-12px), para reservar margem
// aos rótulos diretos. Não mede a fonte: basta não cortar o rótulo.
export function larguraTexto(texto, tamanho = tamanhos.anotacao) {
  return Math.ceil(String(texto ?? "").length * tamanho * 0.56);
}

// Margem esquerda que cabe o maior rótulo do eixo y ("R$ 100,0 mil").
export function margemPara(eixo, minima = 48) {
  const rotulos = (eixo?.ticks ?? []).map((t) => (eixo.tickFormat ? eixo.tickFormat(t) : String(t)));
  return Math.max(minima, ...rotulos.map((r) => larguraTexto(r, 12) + 14));
}

function plotar({
  marcas, x, y, color, largura, alturaPainel, margens = {}, cabecalhoTexto = null,
  folgaEixoX = 26, ariaLabel = null, ariaDescription = null, document, projection, extra = {}
}) {
  const temCabecalho = Boolean(cabecalhoTexto && (cabecalhoTexto.titulo || cabecalhoTexto.subtitulo || cabecalhoTexto.nota));
  // Nas figuras com título, o rótulo do eixo y vai na vertical, à esquerda:
  // no alto ele disputaria espaço com o título e o subtítulo.
  const rotuloVertical = temCabecalho && y?.label;
  const margemEsquerda = (margens.left ?? 56) + (rotuloVertical ? 18 : 0);
  if (rotuloVertical) y = { ...y, labelAnchor: "center", labelOffset: margemEsquerda - 4 };
  // O Plot põe o rótulo do eixo x no pé da margem inferior, onde fica a nota
  // da figura: aqui ele fica logo abaixo dos ticks.
  if (temCabecalho && x?.label) x = { ...x, labelOffset: folgaEixoX - 6 };
  const h = temCabecalho ? cabecalho({ ...cabecalhoTexto, largura, margemEsquerda, folgaEixoX }) : null;
  const margemTopo = h ? h.margemTopo : (margens.top ?? 20);
  const margemBase = h ? h.margemBase : (margens.bottom ?? folgaEixoX);
  const svg = Plot.plot({
    document,
    width: largura,
    height: alturaPainel + margemTopo + margemBase,
    marginTop: margemTopo,
    marginBottom: margemBase,
    marginLeft: margemEsquerda,
    marginRight: margens.right ?? 20,
    ariaLabel,
    ariaDescription,
    style: { fontFamily: fonte, fontSize: `${tamanhos.texto}px`, color: cores.tinta, overflow: "visible" },
    x, y, color, projection,
    marks: [...marcas, ...(h ? h.marcas : [])],
    ...extra
  });
  return acessivel(svg);
}

// O gráfico é uma imagem para a tecnologia assistiva: rótulo e descrição no
// elemento raiz, e os valores na tabela ao lado. Os aria-label que o Plot põe
// nos grupos internos ("line", "dot") não têm papel e o axe os acusa.
export function acessivel(svg) {
  if (!svg?.setAttribute) return svg;
  svg.setAttribute("role", "img");
  for (const no of svg.querySelectorAll("[aria-label]")) no.removeAttribute("aria-label");
  for (const no of svg.querySelectorAll("[aria-description]")) no.removeAttribute("aria-description");
  return svg;
}

// Séries no tempo: uma linha por série (geografia, grupo, conceito), com a faixa
// de 2018, rótulos diretos e, opcionalmente, a faixa de Gastwirth e séries
// tracejadas (a variante sem o top 0,01%).
export function series(dados, {
  x = "ano", y = "valor", z = "serie", cor = null, tracejado = null,
  eixo = "indice", eixoOpcoes = {}, rotuloY = null,
  faixa = null, ressalva2018 = true, rotulos = "fim", textoRotulo = null,
  rotularSo = null, formatarExtremos = null, extras = [], extrasAntes = [],
  largura = 640, alturaPainel = 300, margemEsquerda = null, margemDireita = null, girarAnos = false,
  titulo = null, subtitulo = null, nota = null,
  interativo = false, tip = null, ariaLabel = null, ariaDescription = null, document
} = {}) {
  const pontos = dados.filter((d) => finito(d[x]) && finito(d[y]));
  const grupos = [...new Set(pontos.map((d) => d[z]))];
  const paleta = corDestaque(Math.max(grupos.length, 1));
  const corDe = typeof cor === "function" ? cor
    : cor instanceof Map ? (g) => cor.get(g) ?? cores.contexto
      : (g) => paleta[grupos.indexOf(g)] ?? cores.contexto;
  const valoresY = pontos.map((d) => d[y]);
  if (faixa) for (const d of pontos) valoresY.push(d[faixa.inferior], d[faixa.superior]);
  const eixoY = eixoValor(eixo, valoresY.filter(finito), { rotulo: rotuloY, ...eixoOpcoes });
  const anos = [...new Set(pontos.map((d) => d[x]))];
  const ehTracejada = tracejado ?? (() => false);
  const cheias = pontos.filter((d) => !ehTracejada(d));
  const tracejadas = pontos.filter((d) => ehTracejada(d));
  const paraRotulo = rotularSo ? pontos.filter(rotularSo) : cheias;
  const textoDe = textoRotulo ?? ((d) => d[z]);
  const larguraRotulos = rotulos === "fim"
    ? Math.max(0, ...[...new Set(paraRotulo.map(textoDe))].map((t) => larguraTexto(t))) + 14
    : 24;

  const marcas = [
    ...extrasAntes,
    ...(ressalva2018 ? marca2018({ anos }) : []),
    ...(faixa ? [Plot.areaY(cheias.filter((d) => finito(d[faixa.inferior]) && finito(d[faixa.superior])), {
      x, y1: faixa.inferior, y2: faixa.superior, z, fill: cores.grade, fillOpacity: 0.8
    })] : []),
    Plot.line(cheias, { x, y, z, stroke: (d) => corDe(d[z]), strokeWidth: 2 }),
    Plot.line(tracejadas, { x, y, z, stroke: (d) => corDe(d[z]), strokeWidth: 2, strokeDasharray: "5,4" }),
    Plot.dot(pontos, { x, y, fill: (d) => corDe(d[z]), r: 3 }),
    ...(rotulos === "fim" ? rotularNoFim(paraRotulo, { x, y, z, texto: textoDe, cor: (d) => corDe(d[z]) }) : []),
    ...(rotulos === "extremos" ? rotularExtremos(cheias, {
      x, y, formatar: formatarExtremos ?? (eixo === "indice" ? indice(0.001) : percentual(0.1))
    }) : []),
    ...extras,
    ...(interativo ? [Plot.tip(pontos, Plot.pointerX({ x, y, stroke: (d) => corDe(d[z]), title: tip ?? ((d) => `${d[x]} · ${d[z]}: ${eixoY.tickFormat(d[y])}`) }))] : [])
  ];
  return plotar({
    marcas, x: { ...eixoAno(anos), ...(girarAnos ? { tickRotate: -45 } : {}) }, y: eixoY, largura, alturaPainel,
    margens: { left: margemEsquerda ?? margemPara(eixoY), right: margemDireita ?? larguraRotulos },
    folgaEixoX: girarAnos ? 40 : 26,
    cabecalhoTexto: { titulo, subtitulo, nota }, ariaLabel, ariaDescription, document
  });
}

// Curva ao longo dos percentis (até o centésimo 99), com o último 1% sombreado:
// o detalhe do topo fica no gráfico seguinte, em eixo ordinal.
export function curvaPercentil(dados, {
  x = "share_upper", y, eixo = "aliquota", rotuloY = null,
  rotuloX = "Posição na distribuição (limite superior do grupo)",
  faixaTopo = true, anotacaoTopo = null, zero = true, cor = corDestaque(1)[0],
  largura = 640, alturaPainel = 240, margemEsquerda = null,
  titulo = null, subtitulo = null, nota = null,
  interativo = false, tip = null, ariaLabel = null, ariaDescription = null, document
} = {}) {
  const pontos = dados.filter((d) => finito(d[x]));
  const valoresY = pontos.map((d) => d[y]).filter(finito);
  const eixoY = eixoValor(eixo, eixo === "dinheiro" || eixo === "indice" ? [0, ...valoresY] : valoresY, {
    rotulo: rotuloY, ...(eixo === "indice" ? { spanMin: 0.1 } : {})
  });
  const eixoX = eixoParticipacao(pontos.map((d) => d[x]), { ancora: [0, 1], rotulo: rotuloX, grid: false });
  const marcas = [
    ...(faixaTopo ? [Plot.rect([{ x1: 0.99, x2: 1 }], { x1: "x1", x2: "x2", fill: cores.grade, fillOpacity: 0.7 })] : []),
    ...(anotacaoTopo ? [Plot.text([anotacaoTopo], {
      x: 0.985, frameAnchor: "top", textAnchor: "end", lineAnchor: "top", dy: 4,
      fill: cores.textoSuave, fontSize: tamanhos.nota, lineHeight: 1.2
    })] : []),
    ...(zero ? [linhaZero()] : []),
    // Valores ausentes (renda nula do grupo) ficam como lacuna na linha.
    Plot.line(pontos, { x, y: (d) => (finito(d[y]) ? d[y] : NaN), stroke: cor, strokeWidth: 2 }),
    ...(interativo ? [Plot.tip(pontos.filter((d) => finito(d[y])), Plot.pointerX({ x, y, title: tip }))] : [])
  ];
  return plotar({
    marcas, x: eixoX, y: eixoY, largura, alturaPainel, margens: { left: margemEsquerda ?? margemPara(eixoY), right: 20 },
    folgaEixoX: 48, cabecalhoTexto: { titulo, subtitulo, nota }, ariaLabel, ariaDescription, document
  });
}

// Os 20 grupos disjuntos do topo em eixo ordinal de largura igual.
export function curvaTopo(dados, {
  x = "share_upper", y, eixo = "aliquota", rotuloY = null,
  rotuloX = "Percentil de renda (limite superior de cada grupo divulgado)",
  rotularPicoUltimo = false, formatar = null, zero = true, cor = corDestaque(1)[0],
  largura = 640, alturaPainel = 240, margemEsquerda = null,
  titulo = null, subtitulo = null, nota = null,
  interativo = false, tip = null, ariaLabel = null, ariaDescription = null, document
} = {}) {
  const eixoX = eixoOrdinalTopo(dados.map((d) => d[x]));
  const pontos = dados.filter((d) => finito(d[x])).map((d) => ({ ...d, __posicao: eixoX.rotular(d[x]) }));
  const definidos = pontos.filter((d) => finito(d[y]));
  const valoresY = definidos.map((d) => d[y]);
  const eixoY = eixoValor(eixo, eixo === "dinheiro" || eixo === "indice" ? [0, ...valoresY] : valoresY, {
    rotulo: rotuloY, ...(eixo === "indice" ? { spanMin: 0.1 } : {})
  });
  const fmt = formatar ?? eixoY.tickFormat;
  let pico = null;
  let ultimo = null;
  if (rotularPicoUltimo && definidos.length) {
    pico = definidos.reduce((a, b) => (b[y] > a[y] ? b : a));
    ultimo = definidos.reduce((a, b) => (b[x] > a[x] ? b : a));
    if (ultimo === pico) ultimo = null;
  }
  const marcas = [
    ...(zero ? [linhaZero()] : []),
    Plot.line(pontos, { x: "__posicao", y: (d) => (finito(d[y]) ? d[y] : NaN), stroke: cor, strokeWidth: 2 }),
    Plot.dot(definidos, { x: "__posicao", y, fill: cor, r: 3 }),
    ...(pico ? [Plot.text([pico], {
      x: "__posicao", y, text: (d) => fmt(d[y]), dy: -11, fill: cores.tinta, fontSize: tamanhos.anotacao
    })] : []),
    // O último grupo fica na borda direita: o rótulo vai à esquerda do ponto,
    // longe da linha que chega a ele.
    ...(ultimo ? [Plot.text([ultimo], {
      x: "__posicao", y, text: (d) => fmt(d[y]), dy: -9, dx: -6, textAnchor: "end", fill: cores.tinta, fontSize: tamanhos.anotacao
    })] : []),
    ...(interativo ? [Plot.tip(definidos, Plot.pointerX({ x: "__posicao", y, title: tip }))] : [])
  ];
  return plotar({
    marcas,
    x: { type: "point", domain: eixoX.dominio, label: rotuloX, labelArrow: "none", tickRotate: -45, padding: 0.4 },
    y: eixoY, largura, alturaPainel, margens: { left: margemEsquerda ?? margemPara(eixoY), right: 24 },
    folgaEixoX: 86, cabecalhoTexto: { titulo, subtitulo, nota }, ariaLabel, ariaDescription, document
  });
}

// Barras horizontais: o comprimento é a mensagem, então o zero é obrigatório.
export function barras(dados, {
  x = "valor", y = "rotulo", eixo = "dinheiro", rotuloX = null, cor = corDestaque(1)[0],
  ordem = null, largura = 640, alturaBarra = 24, margemEsquerda = null,
  interativo = false, tip = null, ariaLabel = null, ariaDescription = null, document, nota = null
} = {}) {
  const pontos = dados.filter((d) => finito(d[x]));
  const dominioY = ordem ?? [...pontos].sort((a, b) => b[x] - a[x]).map((d) => d[y]);
  const eixoX = eixoValor(eixo, [0, ...pontos.map((d) => d[x])], {
    rotulo: rotuloX, ...(eixo === "indice" ? { spanMin: 0 } : {})
  });
  const esquerda = margemEsquerda ?? Math.min(280, Math.max(...dominioY.map((t) => larguraTexto(t, 12)), 40) + 12);
  const marcas = [
    Plot.barX(pontos, { x, y, fill: cor, insetTop: 3, insetBottom: 3 }),
    Plot.ruleX([0], { stroke: cores.referencia }),
    ...(interativo ? [Plot.tip(pontos, Plot.pointerY({ x, y, title: tip }))] : [])
  ];
  return plotar({
    marcas, x: { ...eixoX, grid: true }, y: { domain: dominioY, label: null, tickSize: 0 },
    largura, alturaPainel: Math.max(dominioY.length, 1) * alturaBarra,
    margens: { left: esquerda, right: 28, top: 8 }, folgaEixoX: rotuloX ? 40 : 26,
    cabecalhoTexto: { nota }, ariaLabel, ariaDescription, document
  });
}

// Classes quantílicas (método 7 do R, o mesmo do d3.quantile) para o mapa. Com
// um outlier estadual, uma escala contínua colapsaria o contraste das demais.
export function classesQuantis(valores, n = 5) {
  const finitos = valores.filter(finito).sort((a, b) => a - b);
  if (finitos.length < 2) return null;
  const quebras = [...new Set(Array.from({ length: n + 1 }, (_, i) => quantile(finitos, i / n)))];
  if (quebras.length < 2) return null;
  return { quebras, cores: corOrdinal(Math.max(quebras.length - 1, 2)).slice(0, quebras.length - 1) };
}

export function mapaUF(malha, valorPorUf, {
  rotulos = [], formatar = (v) => String(v), largura = 480, alturaPainel = 460,
  interativo = false, ariaLabel = null, ariaDescription = null, document, nClasses = 5
} = {}) {
  const valor = (f) => valorPorUf.get(f.properties.uf);
  const classes = classesQuantis([...valorPorUf.values()], nClasses);
  const comValor = malha.features.filter((f) => finito(valor(f)));
  const color = classes
    ? { type: "threshold", domain: classes.quebras.slice(1, -1), range: classes.cores }
    : { type: "linear", range: [corOrdinal(5)[0], corOrdinal(5)[4]] };
  const marcas = [
    Plot.geo(malha, { fill: cores.semValor, stroke: "white", strokeWidth: 0.6 }),
    Plot.geo(comValor, { fill: valor, stroke: "white", strokeWidth: 0.6 }),
    Plot.text(rotulos, {
      x: "long", y: "lat", text: "uf", fontSize: 10, fill: cores.tinta,
      stroke: "white", strokeWidth: 3, strokeOpacity: 0.75, paintOrder: "stroke"
    }),
    ...(interativo ? [Plot.tip(comValor, Plot.pointer(Plot.geoCentroid({
      title: (f) => `${f.properties.nome}: ${formatar(valor(f))}`
    })))] : [])
  ];
  const svg = plotar({
    marcas, color, largura, alturaPainel, margens: { left: 4, right: 4, top: 4, bottom: 4 },
    folgaEixoX: 4, projection: { type: "mercator", domain: malha }, ariaLabel, ariaDescription, document
  });
  svg.classes = classes;
  return svg;
}
