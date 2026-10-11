// Peças repetidas entre as páginas Explorar: opções dos seletores, textos do
// glossário, cabeçalho de cartão com ações. Cada página .qmd fica só com o que
// é dela.
import { el, botao, ajuda, leitura } from "./interface.js";
import { curvaPercentil, curvaTopo } from "./graficos.js";
import { codigosTopo } from "./marcas.js";
import { notaTopoOrdinal } from "./textos.js";
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

// Par de gráficos das páginas de rendimentos, bens e dívidas: a distribuição
// até o centésimo 99 em eixo de percentil e os 20 grupos do topo em eixo
// ordinal, cada um com a sua frase de leitura (aria-live). Os mesmos valores
// ficam na aba Tabela, para quem não usa o ponteiro.
export function parCurvas({
  dados, y, eixo, rotuloY, rotuloX = "Posição na distribuição de renda (limite superior do grupo)",
  formatar, descricao, largura, alturaPainel = 240, ariaPrincipal, ariaTopo
}) {
  const definido = (d) => Number.isFinite(d[y]);
  const principal = dados.filter((d) => d.bin_code <= 99).sort((a, b) => a.share_upper - b.share_upper);
  const topo = dados.filter((d) => codigosTopo.includes(d.bin_code)).sort((a, b) => a.share_upper - b.share_upper);
  const frase = (nome, d) => (d && definido(d) ? `${nome}: ${descricao} ${formatar(d[y])}` : "");
  const dica = "Passe o cursor ou toque no gráfico para ler os valores; eles também estão na aba Tabela.";

  const g1 = curvaPercentil(principal, {
    y, eixo, rotuloY, rotuloX, largura, alturaPainel, interativo: true,
    tip: (d) => frase(nomeGrupoPercentil(d.share_upper), d), ariaLabel: ariaPrincipal,
    ariaDescription: "O último 1% fica sombreado e é detalhado no gráfico seguinte. Os valores estão na aba Tabela."
  });
  const l1 = leitura({ dica });
  g1.addEventListener("input", () => l1.atualizar(g1.value ? frase(nomeGrupoPercentil(g1.value.share_upper), g1.value) : ""));

  const g2 = curvaTopo(topo, {
    y, eixo, rotuloY, largura, alturaPainel, interativo: true,
    tip: (d) => frase(nomeGrupoPercentil(null, d.__posicao), d), ariaLabel: ariaTopo,
    ariaDescription: "Cada grupo do topo ocupa a mesma largura. Os valores estão na aba Tabela."
  });
  const l2 = leitura({ dica });
  g2.addEventListener("input", () => l2.atualizar(g2.value ? frase(nomeGrupoPercentil(null, g2.value.__posicao), g2.value) : ""));

  return el("div", {},
    principal.length ? [el("div", { class: "grafico-explorar" }, g1), l1] : el("p", {}, "Sem valores para a seleção."),
    el("p", { class: "nota-grafico" }, notaTopoOrdinal),
    topo.length ? [el("div", { class: "grafico-explorar" }, g2), l2] : el("p", {}, "Sem valores no topo para a seleção."));
}

// Rótulo do grupo em tabelas: "até o percentil 45,0" ou "99,91".
export function rotuloGrupo(d) {
  return codigosTopo.includes(d.bin_code) ? `${percentil(d.share_upper, 0.01)}` : `${percentil(d.share_upper, 0.1)}`;
}
