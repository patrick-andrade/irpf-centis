// Formatos em português: os mesmos casos que tests/testthat/test-viz.R
// verificava nos rótulos do ggplot.
import { test } from "node:test";
import assert from "node:assert/strict";
import {
  indice, percentual, contagem, dinheiro, percentil, juntarNomes, quebrarTexto, casas,
  formatoIndicador
} from "../../js/formatos.js";

test("vírgula decimal e ponto de milhar", () => {
  assert.equal(indice(0.001)(0.6039), "0,604");
  assert.equal(percentual(0.1)(0.2507), "25,1%");
  assert.equal(contagem()(41676499), "41.676.499");
  assert.equal(indice(0.01)(1234.5), "1.234,50");
});

test("valores ausentes não viram texto", () => {
  assert.equal(indice()(null), null);
  assert.equal(percentual()(Number.NaN), null);
  assert.equal(dinheiro()(undefined), null);
});

test("dinheiro usa a escala curta em português", () => {
  const f = dinheiro();
  const saida = [0, 1500, 2.5e6, 1.2e9, 3e12].map(f);
  assert.equal(saida[0], "R$ 0");
  assert.match(saida[1], /mil$/);
  assert.match(saida[2], /mi$/);
  assert.match(saida[3], /bi$/);
  assert.match(saida[4], /tri$/);
  assert.equal(saida[3], "R$ 1,2 bi");
  // O defeito que isto substitui: a escala curta do inglês ("B" para bilhão).
  assert.ok(saida.every((s) => !/[KMBT]$/.test(s)));
  assert.equal(dinheiro({ prefixo: "" })(154061), "154,1 mil");
  assert.equal(f(-2.5e6), "R$ -2,5 mi");
  assert.equal(f(450), "R$ 450");
});

test("percentil tem precisão uniforme no mesmo eixo", () => {
  assert.deepEqual(percentil([0.99, 0.998, 0.999, 0.9991]), ["99,00", "99,80", "99,90", "99,91"]);
  assert.deepEqual(percentil([0.5, 0.9]), ["50,0", "90,0"]);
  assert.equal(percentil(1), "100,00");
});

test("casas decimais equivalem ao accuracy do scales", () => {
  assert.equal(casas(0.01), 2);
  assert.equal(casas(0.001), 3);
  assert.equal(casas(0.1), 1);
  assert.equal(casas(1), 0);
});

test("formato pelo tipo de indicador", () => {
  assert.equal(formatoIndicador("top_1_share")(0.251), "25,1%");
  assert.equal(formatoIndicador("gini_grouped")(0.6039), "0,604");
  assert.equal(formatoIndicador("effective_rate")(0.0742), "7,4%");
});

test("nomes unidos com 'e' antes do último", () => {
  assert.equal(juntarNomes(["Brasil"]), "Brasil");
  assert.equal(juntarNomes(["Brasil", "São Paulo"]), "Brasil e São Paulo");
  assert.equal(juntarNomes(["Brasil", "São Paulo", "Pernambuco"]), "Brasil, São Paulo e Pernambuco");
  assert.equal(juntarNomes([]), "");
});

test("títulos longos são quebrados, não cortados", () => {
  const longo = "Vinte grupos disjuntos do topo, cada um com a mesma largura no eixo. Brasil, ano-calendário mais recente.";
  const quebrado = quebrarTexto(longo, 88);
  assert.ok(quebrado.includes("\n"));
  assert.ok(quebrado.split("\n").every((l) => l.length <= 88));
  assert.equal(quebrarTexto("curto", 88), "curto");
  assert.equal(quebrarTexto(null, 88), null);
  assert.equal(quebrarTexto("", 88), "");
});
