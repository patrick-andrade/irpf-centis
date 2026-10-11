// Link da visão: casos de tests/testthat/test-app-estado.R.
import { test } from "node:test";
import assert from "node:assert/strict";
import { lerEstado, montarQuery, valorInicial, hrefComEstado, paginas } from "../../js/estado.js";

const vocabulario = {
  anos: [2023, 2024], geos: ["BR", "SP", "RJ"], indicadores: ["gini_grouped", "top_1_share"],
  conceitos: ["RB4", "RTB"], grupos: ["taxable", "tax"]
};

test("query válida é lida por inteiro", () => {
  const e = lerEstado("?aba=evolucao&ano=2024&geo=SP&comparar=RJ,XX&ind=top_1_share&conceito=RTB&grupo=tax&sem_topo=1&ordem=nome", vocabulario);
  assert.equal(e.aba, "evolucao");
  assert.equal(e.ano, "2024");
  assert.equal(e.geo, "SP");
  assert.deepEqual(e.comparar, ["RJ"]);
  assert.equal(e.ind, "top_1_share");
  assert.equal(e.conceito, "RTB");
  assert.equal(e.grupo, "tax");
  assert.equal(e.sem_topo, true);
  assert.equal(e.ordem, "nome");
});

test("valores inválidos caem no padrão em vez de quebrar a abertura", () => {
  const e = lerEstado("?aba=nada&ano=1999&geo=ZZ&comparar=XX&ind=foo&sem_topo=sim&ordem=x", vocabulario);
  assert.equal(e.aba, null);
  assert.equal(e.ano, null);
  assert.equal(e.geo, null);
  assert.equal(e.comparar, null);
  assert.equal(e.ind, null);
  assert.equal(e.sem_topo, false);
  assert.equal(e.ordem, null);
  assert.equal(lerEstado("", vocabulario).aba, null);
});

test("comparar aceita no máximo duas geografias, sem repetição", () => {
  const e = lerEstado("?comparar=RJ,RJ,SP,BR", vocabulario);
  assert.deepEqual(e.comparar, ["RJ", "SP"]);
});

test("montarQuery reproduz o formato do painel antigo", () => {
  assert.equal(
    montarQuery({ aba: "evolucao", geo: "SP", comparar: ["RJ", "MG"], sem_topo: true }),
    "?aba=evolucao&geo=SP&comparar=RJ,MG&sem_topo=1"
  );
  assert.equal(montarQuery({ aba: null, geo: "", sem_topo: false, comparar: [] }), "");
});

test("valor inicial: URL, depois sessão, depois padrão", () => {
  assert.equal(valorInicial("SP", "geo", ["BR", "SP"], "BR", { geo: "BR" }), "SP");
  assert.equal(valorInicial(null, "geo", ["BR", "SP"], "BR", { geo: "SP" }), "SP");
  assert.equal(valorInicial(null, "geo", ["BR", "SP"], "BR", { geo: "ZZ" }), "BR");
  assert.equal(valorInicial("2024", "ano", [2023, 2024], 2024, {}), "2024");
});

test("subnavegação leva só o que cada página usa", () => {
  const porId = (id) => paginas.find((p) => p.id === id);
  assert.equal(hrefComEstado(porId("evolucao"), { geo: "SP", ano: 2023 }), "evolucao.html?geo=SP");
  assert.equal(hrefComEstado(porId("estados"), { geo: "SP", ano: 2023 }), "estados.html?ano=2023");
  assert.equal(hrefComEstado(porId("topos"), { geo: "SP", ano: 2023 }), "topos.html?geo=SP&ano=2023");
  assert.equal(hrefComEstado(porId("visao-geral"), { geo: "SP" }), "index.html");
});
