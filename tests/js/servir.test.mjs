// O servidor de teste não pode servir nada fora da pasta do site, nem uma
// pasta irmã cujo nome começa igual.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { servir } from "../../scripts/servir.mjs";

let raiz;
let servidor;
let base;

before(async () => {
  raiz = fs.mkdtempSync(path.join(os.tmpdir(), "irpf-servir-"));
  fs.mkdirSync(path.join(raiz, "site"));
  fs.mkdirSync(path.join(raiz, "site-segredo"));
  fs.writeFileSync(path.join(raiz, "site", "index.html"), "ok");
  fs.writeFileSync(path.join(raiz, "site-segredo", "segredo.txt"), "não");
  servidor = await servir({ raiz: path.join(raiz, "site"), prefixo: "/irpf-centis" });
  base = `http://127.0.0.1:${servidor.address().port}`;
});

after(() => {
  servidor?.close();
  fs.rmSync(raiz, { recursive: true, force: true });
});

test("serve o site sob o prefixo", async () => {
  const r = await fetch(`${base}/irpf-centis/`);
  assert.equal(r.status, 200);
  assert.equal(await r.text(), "ok");
});

test("recusa pasta irmã e subida de diretório", async () => {
  for (const caminho of ["/irpf-centis/..%2Fsite-segredo/segredo.txt", "/irpf-centis/%2E%2E/site-segredo/segredo.txt"]) {
    const r = await fetch(`${base}${caminho}`);
    assert.notEqual(r.status, 200, caminho);
    assert.notEqual(await r.text(), "não", caminho);
  }
});
