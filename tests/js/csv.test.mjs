// CSV para o Excel em português: casos de tests/testthat/test-app-packages.R.
import { test } from "node:test";
import assert from "node:assert/strict";
import { csvPtBr } from "../../js/csv.js";

test("CSV em pt-BR: BOM, ponto e vírgula, vírgula decimal e CRLF", () => {
  const texto = csvPtBr(
    [{ geo: "São Paulo", valor: 0.55 }, { geo: "Brasil", valor: 1234.5 }, { geo: 'Aspas "duplas"', valor: null }],
    [{ id: "geo", rotulo: "Geografia" }, { id: "valor", rotulo: "Valor" }]
  );
  assert.ok(texto.startsWith("﻿"));
  const linhas = texto.slice(1).split("\r\n");
  assert.equal(linhas[0], '"Geografia";"Valor"');
  assert.equal(linhas[1], '"São Paulo";0,55');
  assert.equal(linhas[2], '"Brasil";1234,5');
  assert.equal(linhas[3], '"Aspas ""duplas""";');
  assert.equal(linhas[4], "");
});

test("não finitos saem como célula vazia", () => {
  const texto = csvPtBr([{ a: Number.NaN, b: Infinity }], ["a", "b"]);
  assert.ok(texto.endsWith('"a";"b"\r\n;\r\n'));
});
