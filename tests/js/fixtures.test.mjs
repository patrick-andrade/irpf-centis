// O JavaScript formata como o R: os casos vêm de tests/fixtures/formatos-ptbr.json,
// gerado por escrever_fixtures_formatos() (R/site_data.R) a partir dos
// formatadores das tabelas e textos dos relatórios.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { indice, percentual, contagem, dinheiro, percentil } from "../../js/formatos.js";

const fixtures = JSON.parse(fs.readFileSync(new URL("../fixtures/formatos-ptbr.json", import.meta.url), "utf8"));

const casos = {
  indice_0_001: indice(0.001),
  indice_0_01: indice(0.01),
  percentual_0_1: percentual(0.1),
  contagem: contagem(),
  dinheiro: dinheiro()
};

for (const [nome, formatar] of Object.entries(casos)) {
  test(`${nome} igual ao R`, () => {
    assert.deepEqual(fixtures[nome].entrada.map(formatar), fixtures[nome].saida);
  });
}

test("percentil igual ao R", () => {
  for (const caso of fixtures.percentil) assert.deepEqual(percentil(caso.entrada), caso.saida);
});
