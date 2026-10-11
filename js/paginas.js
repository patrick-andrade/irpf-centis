// Peças repetidas entre as páginas Explorar: opções dos seletores, textos do
// glossário, cabeçalho de cartão com ações. Cada página .qmd fica só com o que
// é dela.
import { el, botao, ajuda } from "./interface.js";
import { copiarLink } from "./estado.js";
import { baixarCsv } from "./csv.js";
import { paraLinhas } from "./dados.js";
import { percentil } from "./formatos.js";

// Chave de ordenação sem acentos: "Paraíba" entre "Pará" e "Paraná". Os
// diacríticos ficam separados pela normalização NFD (faixa U+0300 a U+036F).
const DIACRITICOS = new RegExp("[" + String.fromCharCode(0x300) + "-" + String.fromCharCode(0x36f) + "]", "g");
export function semAcento(texto) {
  return String(texto ?? "").normalize("NFD").replace(DIACRITICOS, "").toLowerCase();
}

export function opcoesGeografia(comum, { codigos = null } = {}) {
  const geos = paraLinhas(comum.geografias);
  return geos
    .filter((g) => !codigos || codigos.includes(g.geo_code))
    .map((g) => ({ valor: g.geo_code, rotulo: g.geo_name }));
}

export function opcoesAno(anos) {
  return [...anos].sort((a, b) => b - a).map((a) => ({ valor: a, rotulo: String(a) }));
}

export function glossarioDe(glossario) {
  const indicadores = paraLinhas(glossario.indicadores);
  const conceitos = paraLinhas(glossario.conceitos);
  const indicador = (id) => indicadores.find((i) => i.indicator_id === id);
  const conceito = (id) => conceitos.find((c) => c.ranking_id === id);
  return {
    indicadores, conceitos, indicador, conceito,
    // Definição e leitura juntas, como no "?" do painel antigo.
    textoAjuda: (id) => {
      const i = indicador(id);
      return i ? [i.definition, i.reading].filter(Boolean).join(" ") : null;
    },
    ajudaIndicador: (id, termo = null) => {
      const i = indicador(id);
      if (!i) return null;
      return ajuda(termo ?? i.short_label, [i.definition, i.reading].filter(Boolean).join(" "),
        { href: `../glossario.html#indicador-${id}` });
    },
    itemIndicador: (id) => {
      const i = indicador(id);
      return i ? {
        termo: i.short_label, resumo: i.definition, detalhe: i.reading, nota: i.grouped_note,
        href: `../glossario.html#indicador-${id}`
      } : null;
    },
    itemConceito: (id) => {
      const c = conceito(id);
      return c ? {
        termo: c.label, resumo: c.formula, detalhe: c.definition, href: `../glossario.html#conceito-${id}`
      } : null;
    }
  };
}

// Cabeçalho de cartão: título à esquerda; baixar CSV e copiar link à direita.
export function cabecalhoCartao({ titulo, id = null, csv = null, link = true, extra = null }) {
  const acoes = [];
  if (csv) acoes.push(botao("Baixar dados (CSV)", () => baixarCsv(csv.linhas(), csv.colunas, csv.arquivo)));
  if (link) acoes.push(botao("Copiar link desta visão", (e) => copiarLink(e.currentTarget)));
  return el("div", { class: "cabecalho-com-acao" },
    el("h2", { id }, titulo, extra), acoes.length ? el("div", { class: "acoes-explorar" }, acoes) : null);
}

// Texto de leitura de uma curva por percentil ("Até o percentil 45,0: …").
export function nomeGrupoPercentil(shareUpper, rotuloOrdinal = null) {
  if (rotuloOrdinal) return `Grupo até o percentil ${rotuloOrdinal}`;
  return `Até o percentil ${percentil(shareUpper, 1)}`;
}

// Largura útil de um gráfico dentro do cartão. O conteúdo do site vai até
// 960 px (styles/site.scss) e o cartão e as abas tiram ~110 px de margem:
// desenhar mais largo faria o navegador encolher o SVG, e o texto junto.
export function larguraGrafico(largura, fracao = 1) {
  const util = Math.min(largura, 960) - 110;
  return Math.max(300, Math.floor(util * fracao));
}
