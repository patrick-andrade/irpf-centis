// Estrutura dos gráficos desenhados no jsdom: o que o leitor precisa ver (faixa
// de 2018, séries, rótulos) e o que a tecnologia assistiva precisa receber.
import { test } from "node:test";
import assert from "node:assert/strict";
import { JSDOM } from "jsdom";
import { series, curvaPercentil, curvaTopo, barras, classesQuantis, acessivel } from "../../js/graficos.js";

const { document } = new JSDOM("").window;

const anos = [2017, 2018, 2019, 2020];
const dados = anos.flatMap((ano) => [
  { ano, valor: 0.55 + (ano === 2018 ? 0.1 : 0), serie: "Brasil" },
  { ano, valor: 0.6, serie: "São Paulo" }
]);

test("séries: faixa de 2018, uma linha por série e rótulos no fim", () => {
  const svg = series(dados, { document, z: "serie", rotuloY: "Gini" });
  assert.equal(svg.getAttribute("role"), "img");
  const textos = [...svg.querySelectorAll("text")].map((t) => t.textContent);
  assert.ok(textos.includes("não comparável"));
  assert.ok(textos.includes("Brasil") && textos.includes("São Paulo"));
  assert.ok(svg.querySelectorAll("rect").length >= 1);
  assert.ok(svg.querySelectorAll("path").length >= 2);
});

test("séries sem 2018 não desenham a faixa", () => {
  const svg = series(dados.filter((d) => d.ano !== 2018), { document, z: "serie" });
  assert.ok(![...svg.querySelectorAll("text")].some((t) => t.textContent === "não comparável"));
});

test("série tracejada para a variante sem o top 0,01%", () => {
  const comVariante = [...dados, ...anos.map((ano) => ({ ano, valor: 0.5, serie: "Sem topo" }))];
  const svg = series(comVariante, { document, z: "serie", tracejado: (d) => d.serie === "Sem topo" });
  assert.ok(svg.querySelector("[stroke-dasharray='5,4']"));
});

test("rótulo e descrição só na raiz do gráfico (sem aria-label nos grupos)", () => {
  const svg = series(dados, { document, z: "serie", ariaLabel: "Gini por ano", ariaDescription: "Valores na tabela." });
  assert.equal(svg.getAttribute("aria-label"), "Gini por ano");
  assert.equal([...svg.querySelectorAll("g[aria-label]")].length, 0);
  assert.equal(acessivel(null), null);
});

test("curva por percentil com lacuna onde falta valor", () => {
  const curva = [0.1, 0.5, 0.9, 0.99].map((p, i) => ({ share_upper: p, effective_rate: i === 1 ? null : p / 10 }));
  const svg = curvaPercentil(curva, { document, y: "effective_rate" });
  assert.equal(svg.getAttribute("role"), "img");
  // A linha da série é o caminho mais longo (os outros são marcas de eixo).
  const linha = [...svg.querySelectorAll("path[d]")].sort((a, b) => b.getAttribute("d").length - a.getAttribute("d").length)[0];
  // Lacuna: o caminho tem mais de um segmento (dois "M").
  assert.ok((linha.getAttribute("d").match(/M/g) ?? []).length >= 2, linha.getAttribute("d"));
});

test("topo em eixo ordinal com pico e último rotulados", () => {
  const topo = [0.99, 0.991, 0.999, 1].map((p, i) => ({ share_upper: p, effective_rate: [0.07, 0.09, 0.05, 0.01][i] }));
  const svg = curvaTopo(topo, { document, y: "effective_rate", rotularPicoUltimo: true });
  const textos = [...svg.querySelectorAll("text")].map((t) => t.textContent);
  assert.ok(textos.includes("9,0%"), "pico rotulado");
  assert.ok(textos.includes("1,0%"), "último rotulado");
  assert.ok(textos.includes("99,10"));
});

test("barras partem do zero", () => {
  const svg = barras([{ rotulo: "A", valor: 10 }, { rotulo: "B", valor: 5 }], { document, eixo: "dinheiro" });
  assert.equal(svg.querySelectorAll("rect").length, 2);
});

test("classes do mapa por quantis, com fallback para dado degenerado", () => {
  const c = classesQuantis([0.5, 0.55, 0.58, 0.61, 0.64, 0.7]);
  assert.equal(c.quebras[0], 0.5);
  assert.equal(c.quebras[c.quebras.length - 1], 0.7);
  assert.equal(c.cores.length, c.quebras.length - 1);
  assert.equal(classesQuantis([0.6, 0.6, 0.6]), null);
  assert.equal(classesQuantis([Number.NaN, 0.6]), null);
});

test("ano sem valor interrompe a linha e continua no eixo", () => {
  const comLacuna = [2021, 2022, 2023, 2024].map((ano) => ({ ano, valor: ano === 2023 ? null : 0.5 + ano / 1e4, serie: "SP" }));
  const svg = series(comLacuna, { document, z: "serie", ressalva2018: false });
  const linha = [...svg.querySelectorAll("path[d]")].sort((a, b) => b.getAttribute("d").length - a.getAttribute("d").length)[0];
  // Dois trechos: 2021-2022 e 2024 sozinho (sem reta de 2022 a 2024).
  assert.ok((linha.getAttribute("d").match(/M/g) ?? []).length >= 2, linha.getAttribute("d"));
  const ticks = [...svg.querySelectorAll("text")].map((t) => t.textContent);
  assert.ok(ticks.includes("2023"), "2023 sumiu do eixo");
  // Sem ponto desenhado no ano ausente.
  assert.equal(svg.querySelectorAll("circle").length, 3);
});
