// Componentes de interface das páginas Explorar, todos com elementos nativos
// (select, checkbox, button, table, details): teclado, leitor de tela e foco
// funcionam sem código extra. Os controles seguem o protocolo do `viewof` do
// OJS: expõem `.value` e disparam o evento "input" quando mudam.
import { paginas, hrefComEstado } from "./estado.js";
import { cores } from "./tokens.js";

let contador = 0;
const novoId = (prefixo) => `${prefixo}-${++contador}`;

export function el(tag, atributos = {}, ...filhos) {
  const no = document.createElement(tag);
  for (const [nome, valor] of Object.entries(atributos ?? {})) {
    if (valor === null || valor === undefined || valor === false) continue;
    if (nome === "class") no.className = valor;
    else if (nome === "dataset") Object.assign(no.dataset, valor);
    else if (nome.startsWith("on") && typeof valor === "function") no.addEventListener(nome.slice(2), valor);
    else no.setAttribute(nome, valor === true ? "" : String(valor));
  }
  for (const filho of filhos.flat(Infinity)) {
    if (filho === null || filho === undefined || filho === false) continue;
    no.append(typeof filho === "object" && filho.nodeType ? filho : document.createTextNode(String(filho)));
  }
  return no;
}

function anunciar(alvo) {
  alvo.dispatchEvent(new Event("input", { bubbles: true }));
}

// Seletor: `opcoes` é uma lista de { valor, rotulo } (ou de strings).
export function seletor({ rotulo, opcoes, valor = null, id = null, dica = null }) {
  const lista = opcoes.map((o) => (typeof o === "object" ? o : { valor: o, rotulo: String(o) }));
  const idSelect = id ?? novoId("seletor");
  const select = el("select", { id: idSelect, class: "form-select form-select-sm" },
    lista.map((o) => el("option", { value: String(o.valor) }, o.rotulo)));
  const inicial = lista.find((o) => String(o.valor) === String(valor)) ?? lista[0];
  if (inicial) select.value = String(inicial.valor);
  // `dica` pode ser texto fixo ou função do valor escolhido: a definição de
  // uma linha muda junto com a escolha.
  const caixaDica = dica ? el("div", { class: "definicao-curta", id: `${idSelect}-dica` }) : null;
  if (caixaDica) select.setAttribute("aria-describedby", caixaDica.id);
  const raiz = el("div", { class: "controle-explorar" },
    el("label", { for: idSelect, class: "form-label" }, rotulo), select, caixaDica);
  const original = (texto) => lista.find((o) => String(o.valor) === texto)?.valor ?? null;
  const atualizarDica = () => {
    if (caixaDica) caixaDica.textContent = (typeof dica === "function" ? dica(original(select.value)) : dica) ?? "";
  };
  Object.defineProperty(raiz, "value", {
    get: () => original(select.value),
    set: (v) => { select.value = String(v); atualizarDica(); }
  });
  select.addEventListener("change", (e) => { e.stopPropagation(); atualizarDica(); anunciar(raiz); });
  select.addEventListener("input", (e) => e.stopPropagation());
  raiz.value = inicial?.valor;
  return raiz;
}

// Agrupa vários controles num só elemento com `.value` = { nome: valor }. Uma
// célula `viewof` recebe todos os filtros de uma vez, e a faixa de filtros é
// um bloco só no layout.
export function grupoFiltros(controles, { classe = "explorar-filtros", rotulo = "Filtros" } = {}) {
  const ler = () => Object.fromEntries(Object.entries(controles).map(([nome, c]) => [nome, c.value]));
  const raiz = el("div", { class: classe, role: "group", "aria-label": rotulo }, Object.values(controles));
  raiz.value = ler();
  // Registrado antes do ouvinte do OJS: atualiza o valor antes de ele ler.
  raiz.addEventListener("input", () => { raiz.value = ler(); });
  return raiz;
}

export function caixa({ rotulo, valor = false, id = null }) {
  const idCaixa = id ?? novoId("caixa");
  const input = el("input", { type: "checkbox", id: idCaixa, class: "form-check-input" });
  input.checked = Boolean(valor);
  const raiz = el("div", { class: "form-check controle-explorar" }, input,
    el("label", { for: idCaixa, class: "form-check-label" }, rotulo));
  Object.defineProperty(raiz, "value", { get: () => input.checked, set: (v) => { input.checked = Boolean(v); } });
  input.addEventListener("change", (e) => { e.stopPropagation(); anunciar(raiz); });
  input.addEventListener("input", (e) => e.stopPropagation());
  return raiz;
}

// Grupo de opções exclusivas (rádio), dentro de fieldset/legend.
export function grupoOpcoes({ rotulo, opcoes, valor = null }) {
  const nome = novoId("grupo");
  const lista = opcoes.map((o) => (typeof o === "object" ? o : { valor: o, rotulo: String(o) }));
  const inicial = lista.find((o) => String(o.valor) === String(valor)) ?? lista[0];
  const entradas = lista.map((o) => {
    const idOpcao = novoId("opcao");
    const input = el("input", { type: "radio", name: nome, id: idOpcao, value: String(o.valor), class: "form-check-input" });
    input.checked = o === inicial;
    return el("div", { class: "form-check form-check-inline" }, input,
      el("label", { for: idOpcao, class: "form-check-label" }, o.rotulo));
  });
  const raiz = el("fieldset", { class: "controle-explorar" }, el("legend", { class: "form-label" }, rotulo), entradas);
  Object.defineProperty(raiz, "value", {
    get: () => {
      const marcado = raiz.querySelector("input:checked");
      return lista.find((o) => String(o.valor) === marcado?.value)?.valor ?? null;
    }
  });
  raiz.addEventListener("change", (e) => { if (e.target !== raiz) { e.stopPropagation(); anunciar(raiz); } });
  return raiz;
}

export function botao(texto, aoClicar, { classe = "btn btn-sm botao-explorar", rotuloAcessivel = null } = {}) {
  return el("button", { type: "button", class: classe, "aria-label": rotuloAcessivel, onclick: aoClicar }, texto);
}

// Tabela acessível: legenda, cabeçalhos com escopo e números alinhados.
// `colunas`: [{ id, rotulo, formatar?, numerica? }].
export function tabela({ linhas, colunas, legenda = null, classe = "tabela-explorar" }) {
  const cabeca = el("thead", {}, el("tr", {}, colunas.map((c) =>
    el("th", { scope: "col", class: c.numerica ? "num" : null }, c.rotulo))));
  const corpo = el("tbody", {}, linhas.map((l) => el("tr", {}, colunas.map((c, i) => {
    const bruto = l[c.id];
    const texto = c.formatar ? c.formatar(bruto, l) : bruto;
    const atributos = { class: c.numerica ? "num" : null };
    return i === 0 && c.cabecalhoLinha
      ? el("th", { ...atributos, scope: "row" }, texto ?? "–")
      : el("td", atributos, texto ?? "–");
  }))));
  return el("div", { class: "table-responsive" },
    el("table", { class: `table table-sm table-striped ${classe}` },
      legenda ? el("caption", {}, legenda) : null, cabeca, corpo));
}

// "?" com a definição do termo. Botão que abre e fecha um quadro (disclosure),
// com link para a ficha completa no glossário.
export function ajuda(termo, texto, { href = null } = {}) {
  const idQuadro = novoId("ajuda");
  const quadro = el("span", { id: idQuadro, class: "quadro-ajuda", role: "note", hidden: true },
    texto, href ? [" ", el("a", { href }, "Ver no glossário")] : null);
  const gatilho = el("button", {
    type: "button", class: "icone-ajuda", "aria-expanded": "false", "aria-controls": idQuadro,
    "aria-label": `O que é: ${termo}`, title: `O que é: ${termo}`
  }, "?");
  const alternar = (abrir) => {
    gatilho.setAttribute("aria-expanded", String(abrir));
    quadro.hidden = !abrir;
  };
  gatilho.addEventListener("click", () => alternar(quadro.hidden));
  gatilho.addEventListener("keydown", (e) => { if (e.key === "Escape") alternar(false); });
  return el("span", { class: "ajuda-explorar" }, gatilho, quadro);
}

// Frase com o valor lido no gráfico. `aria-live` faz o leitor de tela anunciar.
export function leitura({ dica = "Passe o cursor ou toque no gráfico, ou escolha um ano, para ler os valores." } = {}) {
  const alvo = el("span", { class: "leitura-dica" }, dica);
  const raiz = el("div", { class: "leitura-ponto", "aria-live": "polite" }, alvo);
  raiz.atualizar = (texto) => {
    alvo.className = texto ? "" : "leitura-dica";
    alvo.textContent = texto || dica;
  };
  return raiz;
}

export function caixaValor({ titulo, valor, variacao = null, ajudaTermo = null }) {
  return el("div", { class: "caixa-valor" },
    el("div", { class: "caixa-valor-titulo" }, titulo, ajudaTermo ? [" ", ajudaTermo] : null),
    el("div", { class: "caixa-valor-numero" }, valor ?? "–"),
    variacao ? el("p", { class: "caixa-valor-variacao" }, variacao) : null);
}

// Subnavegação das páginas Explorar. Os links levam ano e geografia.
export function subnav(atual, comum = {}) {
  return el("nav", { class: "subnav-explorar", "aria-label": "Páginas do Explorar" },
    el("ul", {}, paginas.map((p) => el("li", {},
      el("a", {
        href: hrefComEstado(p, comum), dataset: { pagina: p.id },
        "aria-current": p.id === atual ? "page" : null
      }, p.titulo)))));
}

// Rodapé de bloco: Nota, Observação e Fonte, nesta ordem.
export function rodape({ notas = [], observacoes = [], fonte = null }) {
  const bloco = (rotulo, itens) => {
    const lista = (Array.isArray(itens) ? itens : [itens]).filter(Boolean);
    if (lista.length === 0) return null;
    return el("div", { class: "rodape-item" }, el("strong", {}, `${rotulo}: `),
      lista.length === 1 ? el("span", {}, lista[0]) : el("ul", {}, lista.map((i) => el("li", {}, i))));
  };
  return el("div", { class: "bloco-rodape", role: "note" },
    bloco("Nota", notas), bloco("Observação", observacoes), fonte ? bloco("Fonte", fonte) : null);
}

// Glossário recolhido no fim de cada página: os textos vêm de
// config/schema/indicators.csv e rankings.csv (glossario.json). Fica depois
// dos gráficos, de propósito: explicar antes empurraria a visualização para
// fora da primeira tela.
export function itemGlossario({ termo, resumo = null, detalhe = null, nota = null, href = null }) {
  return [
    el("dt", {}, termo, href ? [" ", el("a", { href, class: "small" }, "(ficha)")] : null),
    el("dd", {},
      resumo ? el("span", {}, resumo) : null,
      detalhe ? el("span", { class: "glossario-detalhe" }, detalhe) : null,
      nota ? el("span", { class: "glossario-nota" }, nota) : null)
  ];
}

export function blocoConceitos({ conceitos = [], indicadores = [], extras = [], adicional = null }) {
  const secao = (titulo, itens) => (itens.length === 0 ? null : [
    el("p", { class: "glossario-titulo" }, titulo),
    el("dl", { class: "glossario-lista" }, itens.map(itemGlossario))
  ]);
  return el("details", { class: "bloco-conceitos" },
    el("summary", {}, "Conceitos e indicadores"),
    secao(conceitos.length > 1 ? "Conceitos de renda:" : "Conceito de renda:", conceitos),
    secao(indicadores.length > 1 ? "Indicadores:" : "Indicador:", indicadores),
    secao("Como ler esta página:", extras),
    adicional);
}

// Os onze conceitos de renda numa tabela compacta, com o escolhido destacado.
export function tabelaConceitos(conceitos, destaque = null) {
  return el("table", { class: "tabela-conceitos" },
    el("caption", { class: "visually-hidden" }, "Conceitos de renda disponíveis"),
    el("thead", {}, el("tr", {}, ["Tabela", "Conceito", "Composição", "Anos"].map((t) => el("th", { scope: "col" }, t)))),
    el("tbody", {}, conceitos.map((c) => el("tr", { class: c.ranking_id === destaque ? "conceito-principal" : null },
      el("td", {}, c.roman), el("td", {}, c.label), el("td", {}, c.formula),
      el("td", {}, c.year_max ? `${c.year_min}-${c.year_max}` : `${c.year_min}-`)))));
}

// Legenda do tipo de linha (contínua e tracejada), quando há duas séries.
export function legendaLinhas(itens) {
  const traco = (tracejado) => {
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("width", "28");
    svg.setAttribute("height", "8");
    svg.setAttribute("aria-hidden", "true");
    const linha = document.createElementNS("http://www.w3.org/2000/svg", "line");
    for (const [k, v] of Object.entries({ x1: 0, x2: 28, y1: 4, y2: 4, stroke: cores.textoSuave, "stroke-width": 2 })) linha.setAttribute(k, v);
    if (tracejado) linha.setAttribute("stroke-dasharray", "5,4");
    svg.append(linha);
    return svg;
  };
  return el("p", { class: "legenda-linhas" }, itens.map((i) => [traco(i.tracejado), i.rotulo]));
}

// Legenda das classes do mapa, com os limites de cada classe.
export function legendaClasses(quebras, coresClasses, formatar) {
  if (!quebras) return null;
  const itens = coresClasses.map((cor, i) => el("li", {},
    el("span", { class: "amostra", style: `background:${cor}`, "aria-hidden": "true" }),
    `${formatar(quebras[i])} a ${formatar(quebras[i + 1])}`));
  itens.push(el("li", {}, el("span", { class: "amostra", style: `background:${cores.semValor}`, "aria-hidden": "true" }), "sem dado"));
  return el("ul", { class: "legenda-classes", "aria-label": "Classes do mapa" }, itens);
}
