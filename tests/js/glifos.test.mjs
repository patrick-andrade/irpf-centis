// Todo caractere de texto das figuras dos relatórios precisa existir na Noto
// Sans que o Typst usa (styles/fonts). Um glifo ausente ("↑", "⊂") faz o Typst
// trocar a fonte do texto inteiro por outra, e o PDF sai com Arial no meio.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import opentype from "opentype.js";

const raiz = new URL("../../", import.meta.url);
const pastaFiguras = new URL("reports/figuras/", raiz);

function carregarFonte(nome) {
  const b = fs.readFileSync(new URL(`styles/fonts/${nome}`, raiz));
  return opentype.parse(b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength));
}

const fontes = [carregarFonte("NotoSans-Regular.ttf"), carregarFonte("NotoSans-Bold.ttf")];

function textoDasFiguras() {
  const arquivos = fs.readdirSync(pastaFiguras).filter((f) => f.endsWith(".svg")).sort();
  return arquivos.map((arquivo) => {
    const svg = fs.readFileSync(new URL(arquivo, pastaFiguras), "utf8");
    const textos = [...svg.matchAll(/<(?:text|tspan)[^>]*>([^<]*)</g)].map((m) => m[1]);
    const decodificado = textos.join(" ")
      .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"').replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)));
    return { arquivo, texto: decodificado };
  });
}

test("há figuras para conferir", () => {
  assert.ok(fs.readdirSync(pastaFiguras).filter((f) => f.endsWith(".svg")).length >= 9);
});

test("todo caractere das figuras existe na Noto Sans", () => {
  const faltando = new Map();
  for (const { arquivo, texto } of textoDasFiguras()) {
    for (const c of new Set(texto)) {
      if (/\s/.test(c)) continue;
      if (fontes.some((f) => f.charToGlyphIndex(c) > 0)) continue;
      faltando.set(c, [...(faltando.get(c) ?? []), path.basename(arquivo)]);
    }
  }
  assert.deepEqual(Object.fromEntries(faltando), {});
});
