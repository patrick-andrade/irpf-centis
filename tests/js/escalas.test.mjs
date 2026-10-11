// Nenhuma escala volta a ser automática: o domínio é declarado, as âncoras são
// redondas e os extremos do eixo ficam rotulados. Casos de test-viz.R.
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  passoBonito, dominioAncorado, quebrasDoDominio, eixoIndice, eixoParticipacao,
  eixoAliquota, eixoAno, eixoDinheiro
} from "../../js/escalas.js";

const perto = (a, b, tol = 1e-9) => assert.ok(Math.abs(a - b) <= tol, `${a} ≠ ${b}`);

test("passoBonito devolve a escada 1-2-5", () => {
  perto(passoBonito(0.1), 0.02);
  perto(passoBonito(1), 0.2);
  perto(passoBonito(0.5), 0.1);
  assert.ok(passoBonito(0) > 0);
  assert.ok(passoBonito(Number.NaN) > 0);
});

test("eixo de índice garante amplitude mínima e âncoras redondas", () => {
  // Gini patrimonial real: 16 anos dentro de 0,03.
  const eixo = eixoIndice([0.851, 0.862, 0.880], { spanMin: 0.15 });
  assert.ok(eixo.domain[1] - eixo.domain[0] >= 0.15 - 1e-9);
  assert.ok(eixo.domain[0] <= 0.851);
  assert.ok(eixo.domain[1] >= 0.880);
  // Extremos do eixo coincidem com quebras: nada de limite sem rótulo.
  perto(eixo.ticks[0], eixo.domain[0]);
  perto(eixo.ticks[eixo.ticks.length - 1], eixo.domain[1]);
});

test("eixo de índice respeita âncora fixa", () => {
  const eixo = eixoIndice([0.851, 0.880], { ancora: [0.70, 1.00] });
  assert.deepEqual(eixo.domain, [0.7, 1]);
  perto(eixo.ticks[0], 0.7);
  perto(eixo.ticks[eixo.ticks.length - 1], 1);
});

test("participação e alíquota sempre incluem zero", () => {
  const participacao = eixoParticipacao([0.48, 0.52, 0.59]);
  assert.equal(participacao.domain[0], 0);
  assert.ok(participacao.ticks.includes(0));
  const aliquota = eixoAliquota([0, 0.0735, 0.1008]);
  assert.equal(aliquota.domain[0], 0);
  assert.ok(aliquota.domain[1] >= 0.1008);
  assert.ok(aliquota.domain[1] <= 1);
});

test("participação não passa de 100%", () => {
  assert.ok(eixoParticipacao([0.2, 0.98]).domain[1] <= 1);
});

test("eixo de ano rotula todos os anos, com folga fixa", () => {
  const eixo = eixoAno([2020, 2017, 2024, 2017]);
  assert.deepEqual(eixo.ticks, [2017, 2020, 2024]);
  assert.deepEqual(eixo.domain, [2016.7, 2024.3]);
  assert.equal(eixo.tickFormat(2018), "2018");
});

test("domínio sem valores finitos cai em [0, 1]", () => {
  assert.deepEqual(dominioAncorado([Number.NaN, null]), [0, 1]);
});

test("quebras cobrem o domínio sem ruído de ponto flutuante", () => {
  const quebras = quebrasDoDominio([0.5, 0.7]);
  assert.deepEqual(quebras, [0.5, 0.55, 0.6, 0.65, 0.7]);
});

test("eixo monetário rotula com a escala curta e inclui o zero", () => {
  const eixo = eixoDinheiro([1.2e9, 3.5e9]);
  assert.equal(eixo.domain[0], 0);
  assert.match(eixo.tickFormat(eixo.ticks[eixo.ticks.length - 1]), /bi$/);
});

test("eixos não desenham a seta do rótulo (fora da Noto Sans)", () => {
  assert.equal(eixoIndice([0.5, 0.6]).labelArrow, "none");
  assert.equal(eixoAno([2017, 2024]).labelArrow, "none");
});

test("rótulos dos ticks têm as casas que os valores pedem", () => {
  // Domínio que começa fora do passo: ticks em 0,475, 0,525…
  const eixo = eixoIndice([0.4975, 0.6675], { spanMin: 0.15 });
  const rotulos = eixo.ticks.map(eixo.tickFormat);
  assert.equal(new Set(rotulos).size, rotulos.length);
  assert.ok(rotulos.every((r, i) => Math.abs(Number(r.replace(",", ".")) - eixo.ticks[i]) < 1e-9), rotulos.join(" "));
});
