// Números em português: milhar com ponto, decimal com vírgula.
//
// Tudo passa por d3.formatLocale com a definição explícita abaixo, nunca por
// Intl nem toLocaleString: o resultado precisa ser o mesmo no navegador do
// leitor, no Node que gera as figuras dos PDFs e no runner do CI, e as rotinas
// de Intl variam com a versão do ICU de cada ambiente.
import { formatLocale } from "d3";

export const localePtBr = formatLocale({
  decimal: ",",
  thousands: ".",
  grouping: [3],
  currency: ["R$ ", ""],
  minus: "-",
  percent: "%"
});

// Casas decimais equivalentes ao `accuracy` do pacote scales: 0,01 → 2.
export function casas(precisao) {
  if (!(precisao > 0) || precisao >= 1) return 0;
  return Math.max(0, Math.round(-Math.log10(precisao)));
}

const vazio = (x) => x === null || x === undefined || Number.isNaN(x);

function protegido(formatador) {
  return (x) => (vazio(x) ? null : formatador(x));
}

export function indice(precisao = 0.01) {
  return protegido(localePtBr.format(`,.${casas(precisao)}f`));
}

export function percentual(precisao = 0.1) {
  return protegido(localePtBr.format(`,.${casas(precisao)}%`));
}

export function contagem() {
  return protegido(localePtBr.format(",.0f"));
}

export function numero(precisao = 1) {
  return protegido(localePtBr.format(`,.${casas(precisao)}f`));
}

// "R$ 1,2 bi" em vez do "R$ 1.2B" da escala curta em inglês, que em português
// se lê como outra coisa.
export function dinheiro({ precisao = 0.1, prefixo = "R$ " } = {}) {
  const cortes = [
    [1e12, " tri"], [1e9, " bi"], [1e6, " mi"], [1e3, " mil"], [1, ""]
  ];
  return (valor) => {
    if (vazio(valor)) return null;
    if (valor === 0) return `${prefixo}0`;
    const magnitude = Math.abs(valor);
    const [corte, sufixo] = cortes.find(([c]) => magnitude >= c) ?? cortes[cortes.length - 1];
    const fmt = localePtBr.format(`,.${sufixo === "" ? 0 : casas(precisao)}f`);
    return `${prefixo}${fmt(valor / corte)}${sufixo}`;
  };
}

// Limite superior de um grupo em escala de percentil. Precisão uniforme no
// mesmo eixo: alternar uma e duas casas faz "99,8 / 99,90 / 99,91" parecer
// um retrocesso.
export function percentil(valores, precisao = null) {
  const lista = Array.isArray(valores) ? valores : [valores];
  const p = precisao ?? (lista.some((x) => x >= 0.999) ? 0.01 : 0.1);
  const fmt = localePtBr.format(`,.${casas(p)}f`);
  const um = (x) => (vazio(x) ? null : fmt(100 * x));
  return Array.isArray(valores) ? lista.map(um) : um(valores);
}

// Formata conforme o tipo do indicador: participação e alíquota em %, o resto
// como índice. É o `format_metric()` do painel antigo.
export function formatoIndicador(id, { precisaoIndice = 0.001, precisaoPercentual = 0.1 } = {}) {
  const ehPercentual = /share$/.test(id) || id === "effective_rate";
  return ehPercentual ? percentual(precisaoPercentual) : indice(precisaoIndice);
}

export function ehParticipacao(id) {
  return /share$/.test(id) || id === "effective_rate" || id === "debt_share";
}

// "Brasil, São Paulo e Pernambuco".
export function juntarNomes(nomes) {
  const lista = nomes.filter((n) => n !== null && n !== undefined && n !== "");
  if (lista.length <= 1) return lista.join("");
  return `${lista.slice(0, -1).join(", ")} e ${lista[lista.length - 1]}`;
}

// Quebra de linha por número de caracteres, como o strwrap() do R: o texto de
// um gráfico não é cortado na largura da figura.
export function quebrarTexto(texto, largura) {
  if (texto === null || texto === undefined || texto === "") return texto;
  const linhas = [];
  let atual = "";
  for (const palavra of String(texto).split(/\s+/).filter(Boolean)) {
    if (atual === "") atual = palavra;
    else if (atual.length + 1 + palavra.length <= largura) atual += ` ${palavra}`;
    else {
      linhas.push(atual);
      atual = palavra;
    }
  }
  if (atual !== "") linhas.push(atual);
  return linhas.join("\n");
}
