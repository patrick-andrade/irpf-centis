// Domínios declarados, com âncoras redondas.
//
// Correll, Bertini & Franconeri (CHI 2020): indicar o truncamento de um eixo não
// desfaz o exagero percebido, então a faixa é escolhida a partir do domínio e
// declarada. Sem isso, 0,03 de variação no Gini patrimonial ocupava a altura
// inteira do gráfico e 16 anos estáveis viravam um penhasco. Onde a
// codificação é comprimento (barras), o zero não é negociável.
import { indice, percentual, dinheiro } from "./formatos.js";

// Remove o ruído de ponto flutuante de floor(x / passo) * passo.
const limpo = (x) => Math.round(x * 1e10) / 1e10;

// Passo redondo da escada 1-2-2,5-5-10.
export function passoBonito(amplitude, alvo = 5) {
  if (!Number.isFinite(amplitude) || amplitude <= 0) return 1;
  const bruto = amplitude / Math.max(alvo, 1);
  const magnitude = 10 ** Math.floor(Math.log10(bruto));
  const candidatos = [1, 2, 2.5, 5, 10].map((c) => c * magnitude);
  let melhor = candidatos[0];
  for (const c of candidatos) if (Math.abs(c - bruto) < Math.abs(melhor - bruto)) melhor = c;
  return limpo(melhor);
}

// [mínimo, máximo] arredondado para fora, com amplitude mínima garantida.
export function dominioAncorado(valores, {
  spanMin = 0, ancora = null, incluirZero = false, teto = null, passo = null
} = {}) {
  if (ancora) return [Math.min(ancora[0], ancora[1]), Math.max(ancora[0], ancora[1])];
  const finitos = valores.filter((v) => Number.isFinite(v));
  if (finitos.length === 0) return [0, 1];

  let baixo = Math.min(...finitos);
  let alto = Math.max(...finitos);
  if (incluirZero) baixo = Math.min(0, baixo);
  if (alto === baixo) alto = baixo + Math.max(spanMin, Math.abs(baixo) * 0.1, 1e-6);

  // A amplitude mínima expande em torno do centro dos dados, não do zero.
  if (alto - baixo < spanMin) {
    const centro = (alto + baixo) / 2;
    baixo = centro - spanMin / 2;
    alto = centro + spanMin / 2;
    if (incluirZero) baixo = Math.min(0, baixo);
  }

  const p = passo ?? passoBonito(alto - baixo);
  baixo = limpo(Math.floor(limpo(baixo / p)) * p);
  alto = limpo(Math.ceil(limpo(alto / p)) * p);
  if (incluirZero) baixo = Math.min(0, baixo);
  if (teto !== null) alto = Math.min(alto, teto);
  return [baixo, alto];
}

export function quebrasDoDominio(dominio, passo = null) {
  const p = passo ?? passoBonito(dominio[1] - dominio[0]);
  const quebras = [];
  for (let i = 0; ; i++) {
    const valor = limpo(dominio[0] + i * p);
    if (valor > dominio[1] + 1e-9) break;
    quebras.push(valor);
  }
  return quebras;
}

// Opções de eixo para o Plot. `labelArrow: "none"`: a seta do Plot não existe
// na Noto Sans e faria o Typst trocar a fonte do rótulo inteiro no PDF.
function eixo(dominio, quebras, tickFormat, rotulo, grid) {
  return {
    domain: dominio, ticks: quebras, tickFormat, label: rotulo ?? null,
    labelArrow: "none", grid, nice: false
  };
}

// Índices limitados (Gini, Atkinson, Theil). Amplitude mínima de 0,15: cobre a
// distância entre RTB (~0,50) e RB5 sem deixar 0,03 preencher o gráfico.
export function eixoIndice(valores, { spanMin = 0.15, ancora = null, precisao = 0.01, rotulo = null, grid = true } = {}) {
  const dominio = dominioAncorado(valores, { spanMin, ancora });
  return eixo(dominio, quebrasDoDominio(dominio), indice(precisao), rotulo, grid);
}

// Participações e alíquotas: o zero entra sempre e o teto é 100%.
export function eixoParticipacao(valores, { ancora = null, precisao = 0.1, rotulo = null, grid = true } = {}) {
  const dominio = dominioAncorado(valores, { ancora, incluirZero: true, teto: 1 });
  return eixo(dominio, quebrasDoDominio(dominio), percentual(precisao), rotulo, grid);
}

export const eixoAliquota = eixoParticipacao;

export function eixoDinheiro(valores, { incluirZero = true, rotulo = null, grid = true } = {}) {
  const dominio = dominioAncorado(valores, { incluirZero });
  return eixo(dominio, quebrasDoDominio(dominio), dinheiro(), rotulo, grid);
}

// Todo ano rotulado, com folga fixa de 0,3 ano: os extremos ficam legíveis.
export function eixoAno(anos, { rotulo = null } = {}) {
  const lista = [...new Set(anos.filter((a) => Number.isFinite(a)))].sort((a, b) => a - b);
  const dominio = lista.length ? [lista[0] - 0.3, lista[lista.length - 1] + 0.3] : [0, 1];
  return {
    domain: dominio, ticks: lista, tickFormat: (d) => String(d), label: rotulo,
    labelArrow: "none", nice: false
  };
}
