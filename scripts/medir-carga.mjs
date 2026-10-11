// Tempo até o primeiro gráfico de cada página Explorar, em navegador headless.
// Cada rodada fria usa um perfil novo (cache vazio); a quente repete a visita
// no mesmo perfil. A sonda roda antes de qualquer script da página e marca o
// instante em que o seletor aparece, procurando também em shadow DOM e iframes.
//
// Uso:
//   node scripts/medir-carga.mjs                 # serve output/site e mede
//   node scripts/medir-carga.mjs --base https://patrick-andrade.github.io/irpf-centis
//   node scripts/medir-carga.mjs --rodadas 5 --paginas evolucao,topos
import puppeteer from "puppeteer-core";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { servir } from "./servir.mjs";
import { caminhoNavegador } from "./navegador.mjs";

const args = process.argv.slice(2);
const opcao = (nome, padrao) => {
  const i = args.indexOf(nome);
  return i >= 0 ? args[i + 1] : padrao;
};

const paginas = {
  "visao-geral": ["explorar/", ".caixa-valor-numero"],
  evolucao: ["explorar/evolucao.html", "svg[class^=plot]"],
  topos: ["explorar/topos.html", "svg[class^=plot]"],
  rendimentos: ["explorar/rendimentos.html", "svg[class^=plot]"],
  bens: ["explorar/bens.html", "svg[class^=plot]"],
  dividas: ["explorar/dividas.html", "svg[class^=plot]"],
  estados: ["explorar/estados.html", "svg[class^=plot]"]
};

function sonda(seletor) {
  if (window !== window.top) return;
  const busca = (raiz) => {
    try {
      const achado = raiz.querySelector(seletor);
      if (achado) return achado;
      for (const n of raiz.querySelectorAll("*")) {
        if (n.shadowRoot) { const s = busca(n.shadowRoot); if (s) return s; }
        if (n.tagName === "IFRAME") { try { const d = n.contentDocument; if (d) { const f = busca(d); if (f) return f; } } catch { /* outra origem */ } }
      }
    } catch { /* documento ainda carregando */ }
    return null;
  };
  const t = setInterval(() => { if (busca(document)) { window.__primeiroGrafico = performance.now(); clearInterval(t); } }, 20);
}

async function visita(navegador, url, seletor) {
  const pagina = await navegador.newPage();
  await pagina.setViewport({ width: 1366, height: 900 });
  await pagina.evaluateOnNewDocument(sonda, seletor);
  await pagina.goto(url, { waitUntil: "domcontentloaded", timeout: 120000 });
  await pagina.waitForFunction(() => window.__primeiroGrafico, { timeout: 120000, polling: 50 });
  const ms = await pagina.evaluate(() => Math.round(window.__primeiroGrafico));
  await pagina.close();
  return ms;
}

const mediana = (v) => {
  const o = v.filter(Number.isFinite).sort((a, b) => a - b);
  return o.length ? o[Math.floor(o.length / 2)] : null;
};

const rodadas = Number(opcao("--rodadas", 3));
const escolhidas = (opcao("--paginas", Object.keys(paginas).join(","))).split(",");
let base = opcao("--base", null);
let servidor = null;
if (!base) {
  servidor = await servir({ raiz: opcao("--pasta", "output/site"), prefixo: "/irpf-centis" });
  base = `http://127.0.0.1:${servidor.address().port}/irpf-centis`;
}

const resultados = [];
for (const id of escolhidas) {
  const [caminho, seletor] = paginas[id];
  const url = `${base}/${caminho}`;
  const frias = [];
  const quentes = [];
  for (let i = 0; i < rodadas; i++) {
    const perfil = fs.mkdtempSync(path.join(os.tmpdir(), "irpf-medir-"));
    const navegador = await puppeteer.launch({
      executablePath: caminhoNavegador(), headless: true, userDataDir: perfil,
      args: ["--no-first-run", "--no-default-browser-check", "--disable-extensions"]
    });
    try {
      frias.push(await visita(navegador, url, seletor));
      quentes.push(await visita(navegador, url, seletor));
    } finally {
      await navegador.close();
      fs.rmSync(perfil, { recursive: true, force: true });
    }
  }
  resultados.push({ pagina: id, fria_ms: mediana(frias), quente_ms: mediana(quentes), frias, quentes });
}
servidor?.close();

console.table(resultados.map(({ pagina, fria_ms, quente_ms }) => ({ pagina, fria_ms, quente_ms })));
console.log(JSON.stringify({ base, rodadas, resultados }));
