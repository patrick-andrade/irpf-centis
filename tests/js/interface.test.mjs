// Componentes nativos: valor e evento "input" (protocolo do viewof do OJS),
// rótulos associados e atributos de acessibilidade.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { JSDOM } from "jsdom";

let ui;
before(async () => {
  const { window } = new JSDOM("<!doctype html><html lang='pt-BR'><body></body></html>");
  globalThis.window = window;
  globalThis.document = window.document;
  globalThis.Event = window.Event;
  ui = await import("../../js/interface.js");
});

test("seletor expõe .value com o tipo original e anuncia mudanças", () => {
  const s = ui.seletor({ rotulo: "Ano", opcoes: [2023, 2024].map((a) => ({ valor: a, rotulo: String(a) })), valor: 2024 });
  assert.equal(s.value, 2024);
  let eventos = 0;
  s.addEventListener("input", () => eventos++);
  const select = s.querySelector("select");
  select.value = "2023";
  select.dispatchEvent(new window.Event("change", { bubbles: true }));
  assert.equal(s.value, 2023);
  assert.equal(eventos, 1);
  // Rótulo ligado ao controle: leitor de tela anuncia o nome.
  assert.equal(s.querySelector("label").getAttribute("for"), select.id);
});

test("valor inicial fora das opções cai na primeira", () => {
  const s = ui.seletor({ rotulo: "Geo", opcoes: ["BR", "SP"], valor: "ZZ" });
  assert.equal(s.value, "BR");
});

test("caixa de marcação", () => {
  const c = ui.caixa({ rotulo: "Sem o top 0,01%", valor: true });
  assert.equal(c.value, true);
});

test("tabela com legenda e cabeçalhos com escopo", () => {
  const t = ui.tabela({
    linhas: [{ ano: 2024, v: 0.5 }], legenda: "Valores",
    colunas: [{ id: "ano", rotulo: "Ano", cabecalhoLinha: true }, { id: "v", rotulo: "Valor", numerica: true, formatar: (x) => String(x) }]
  });
  assert.equal(t.querySelector("caption").textContent, "Valores");
  assert.equal(t.querySelectorAll("th[scope=col]").length, 2);
  assert.equal(t.querySelector("tbody th").getAttribute("scope"), "row");
  assert.equal(t.querySelector("td.num").textContent, "0.5");
});

test("ajuda abre e fecha pelo botão, com aria-expanded", () => {
  const a = ui.ajuda("Gini", "Mede a desigualdade.", { href: "../glossario.html#gini_grouped" });
  const botao = a.querySelector("button");
  const quadro = a.querySelector(".quadro-ajuda");
  assert.equal(botao.getAttribute("aria-label"), "O que é: Gini");
  assert.equal(quadro.hidden, true);
  botao.click();
  assert.equal(botao.getAttribute("aria-expanded"), "true");
  assert.equal(quadro.hidden, false);
  assert.ok(quadro.querySelector("a").href.endsWith("#gini_grouped"));
});

test("leitura anuncia em aria-live e volta à dica quando vazia", () => {
  const l = ui.leitura();
  assert.equal(l.getAttribute("aria-live"), "polite");
  l.atualizar("2024 · Brasil: 0,604");
  assert.equal(l.textContent, "2024 · Brasil: 0,604");
  l.atualizar("");
  assert.match(l.textContent, /Passe o cursor/);
});

test("subnavegação marca a página atual e leva o estado", () => {
  const nav = ui.subnav("topos", { geo: "SP", ano: 2023 });
  const atual = nav.querySelector("[aria-current=page]");
  assert.equal(atual.dataset.pagina, "topos");
  assert.equal(nav.querySelector("[data-pagina=evolucao]").getAttribute("href"), "evolucao.html?geo=SP");
});

test("rodapé na ordem Nota, Observação, Fonte", () => {
  const r = ui.rodape({ fonte: "Receita Federal", notas: ["n1"], observacoes: ["o1", "o2"] });
  const rotulos = [...r.querySelectorAll("strong")].map((s) => s.textContent);
  assert.deepEqual(rotulos, ["Nota: ", "Observação: ", "Fonte: "]);
  assert.equal(r.getAttribute("role"), "note");
});
