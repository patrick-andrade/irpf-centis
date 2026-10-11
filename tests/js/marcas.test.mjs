// Marcas compartilhadas e paletas: casos de test-viz.R.
import { test } from "node:test";
import assert from "node:assert/strict";
import { separarRotulos, ultimosPontos, eixoOrdinalTopo, codigosTopo, marca2018, rotularNoFim, rotularExtremos } from "../../js/marcas.js";
import { corOrdinal, corDestaque, coresOrdinais, cores, destaque } from "../../js/tokens.js";

test("séries que terminam próximas recebem rótulos separados", () => {
  const amplitude = 0.062 - 0.056;
  const posicoes = separarRotulos([0.062, 0.058], { amplitude, separacaoMin: 0.05 }).sort((a, b) => a - b);
  assert.ok(posicoes[1] - posicoes[0] >= 0.05 * amplitude - 1e-12);
  // A ordem vertical é preservada.
  const tres = separarRotulos([0.5, 0.5001, 0.2], { amplitude: 0.3 });
  assert.ok(tres[2] < tres[0] && tres[0] < tres[1]);
});

test("último ponto finito de cada série", () => {
  const dados = [
    { ano: 2023, v: 1, g: "a" }, { ano: 2024, v: null, g: "a" }, { ano: 2024, v: 3, g: "b" }
  ];
  const ultimos = ultimosPontos(dados, { x: "ano", y: "v", z: "g" });
  assert.deepEqual(ultimos.map((d) => [d.g, d.ano]).sort(), [["a", 2023], ["b", 2024]]);
});

test("eixo ordinal do topo: 20 grupos, rótulos com duas casas", () => {
  assert.equal(codigosTopo.length, 20);
  const eixo = eixoOrdinalTopo([0.9991, 0.99, 0.9992, 1]);
  assert.deepEqual(eixo.dominio, ["99,00", "99,91", "99,92", "100,00"]);
  assert.equal(eixo.rotular(0.9991), "99,91");
});

test("faixa de 2018 só existe quando a série cobre o ano", () => {
  assert.equal(marca2018({ anos: [2019, 2020] }).length, 0);
  assert.equal(marca2018({ anos: [2017, 2018] }).length, 2);
});

test("anotações lidam com série vazia sem quebrar", () => {
  assert.deepEqual(rotularNoFim([], { x: "ano", y: "v", z: "g" }), []);
  assert.deepEqual(rotularExtremos([], { x: "ano", y: "v" }), []);
});

test("rampa ordinal distinta e destaque Okabe-Ito", () => {
  const quatro = corOrdinal(4);
  assert.equal(quatro.length, 4);
  assert.equal(new Set(quatro).size, 4);
  assert.deepEqual(corOrdinal(4, { inverter: true }), [...quatro].reverse());
  assert.deepEqual(corOrdinal(0), []);
  assert.ok(corDestaque(3).every((c) => destaque.includes(c)));
});

test("série de contexto sai da rampa e recebe cinza", () => {
  const paleta = coresOrdinais(["Todos os declarantes", "Top 10%", "Top 1%"], { contexto: ["Todos os declarantes"] });
  assert.equal(paleta[0], cores.contexto);
  assert.ok(!paleta.slice(1).includes(cores.contexto));
});
