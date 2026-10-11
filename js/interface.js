// Componentes de interface das páginas Explorar, todos com elementos nativos
// (select, checkbox, button, table, details): teclado, leitor de tela e foco
// funcionam sem código extra. Os controles seguem o protocolo do `viewof` do
// OJS: expõem `.value` e disparam o evento "input" quando mudam.
import { paginas, hrefComEstado } from "./estado.js";

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
  const raiz = el("div", { class: "controle-explorar" },
    el("label", { for: idSelect, class: "form-label" }, rotulo), select,
    dica ? el("div", { class: "definicao-curta" }, dica) : null);
  const original = (texto) => lista.find((o) => String(o.valor) === texto)?.valor ?? null;
  Object.defineProperty(raiz, "value", {
    get: () => original(select.value),
    set: (v) => { select.value = String(v); }
  });
  select.addEventListener("change", (e) => { e.stopPropagation(); anunciar(raiz); });
  select.addEventListener("input", (e) => e.stopPropagation());
  raiz.value = inicial?.valor;
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

export function botao(texto, aoClicar, { classe = "btn btn-outline-primary btn-sm", rotuloAcessivel = null } = {}) {
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
