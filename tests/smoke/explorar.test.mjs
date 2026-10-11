// Testes de fumaça das páginas Explorar num navegador de verdade (Chrome ou
// Edge headless via puppeteer-core), sobre o site renderizado em output/site e
// servido sob o mesmo subcaminho do GitHub Pages. Pegam o que os testes de
// unidade não veem: erro em tempo de execução, arquivo que não foi copiado,
// layout que esconde o gráfico, regressão de acessibilidade.
//
// Pré-requisito: `quarto render` (ou o site já renderizado em output/site).
// Uso: npm run smoke   (NAVEGADOR=<executável> para escolher o navegador)
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import puppeteer from "puppeteer-core";
import { servir } from "../../scripts/servir.mjs";
import { caminhoNavegador } from "../../scripts/navegador.mjs";

const require = createRequire(import.meta.url);
const axeFonte = fs.readFileSync(require.resolve("axe-core/axe.min.js"), "utf8");
const pasta = process.env.SITE ?? "output/site";
const LIMITE_MS = Number(process.env.LIMITE_PRIMEIRO_GRAFICO_MS ?? 3000);

let servidor;
let navegador;
let base;

before(async () => {
  assert.ok(fs.existsSync(path.join(pasta, "explorar", "evolucao.html")), `site não renderizado em ${pasta}`);
  servidor = await servir({ raiz: pasta, prefixo: "/irpf-centis" });
  base = `http://127.0.0.1:${servidor.address().port}/irpf-centis`;
  navegador = await puppeteer.launch({
    executablePath: caminhoNavegador(), headless: true,
    args: ["--no-first-run", "--no-default-browser-check", "--no-sandbox"]
  });
});

after(async () => {
  await navegador?.close();
  servidor?.close();
});

// Abre a página e registra erros de console, exceções e respostas 4xx/5xx da
// própria origem. Pedidos ao CDN do runtime OJS do Quarto (marked, highlight)
// não contam: a página não depende deles.
async function abrir(caminho, { bloquearCdn = false } = {}) {
  const pagina = await navegador.newPage();
  await pagina.setViewport({ width: 1280, height: 900 });
  const problemas = [];
  pagina.on("pageerror", (e) => problemas.push(`exceção: ${e.message}`));
  pagina.on("console", (m) => {
    if (m.type() === "error" && !/Failed to load resource/.test(m.text())) problemas.push(`console: ${m.text()}`);
  });
  pagina.on("response", (r) => {
    const url = r.url();
    if (url.startsWith(base) && r.status() >= 400 && !url.endsWith("favicon.ico")) problemas.push(`${r.status()} ${url}`);
  });
  if (bloquearCdn) {
    await pagina.setRequestInterception(true);
    pagina.on("request", (r) => (r.url().includes("cdn.jsdelivr.net") ? r.abort() : r.continue()));
  }
  const inicio = Date.now();
  await pagina.goto(`${base}/${caminho}`, { waitUntil: "domcontentloaded" });
  return { pagina, problemas, inicio };
}

async function esperarGrafico(pagina, seletor = "svg[class^=plot]") {
  await pagina.waitForSelector(seletor, { timeout: 15000 });
}

// Erros de OJS aparecem na página, não no console. Conta só os visíveis: com o
// CDN bloqueado, o runtime do Quarto falha ao buscar o `marked` numa célula
// oculta, sem efeito sobre a página.
async function errosOjs(pagina) {
  return pagina.$$eval(".observablehq--error", (els) => els
    .filter((e) => e.getBoundingClientRect().height > 0)
    .map((e) => e.textContent.slice(0, 200)));
}

async function escolher(pagina, rotulo, valor) {
  await pagina.evaluate((rotulo, valor) => {
    const label = [...document.querySelectorAll("label")].find((l) => l.textContent.trim() === rotulo);
    const select = document.getElementById(label.getAttribute("for"));
    select.value = String(valor);
    select.dispatchEvent(new Event("change", { bubbles: true }));
  }, rotulo, valor);
}

async function axe(pagina) {
  await pagina.evaluate(axeFonte);
  const resultado = await pagina.evaluate(async () => {
    // A barra de navegação e o rodapé são do tema do Quarto; o alvo aqui é o conteúdo.
    const r = await window.axe.run(document.querySelector("main") ?? document, {
      runOnly: { type: "tag", values: ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"] }
    });
    return r.violations.filter((v) => ["serious", "critical"].includes(v.impact))
      .map((v) => `${v.id}: ${v.nodes.slice(0, 3).map((n) => n.target.join(" ")).join(" | ")}`);
  });
  return resultado;
}

async function leitura(pagina) {
  return pagina.$eval(".leitura-ponto", (e) => e.textContent.trim());
}

test("Evolução: abre, desenha rápido e sem erros", async () => {
  const { pagina, problemas, inicio } = await abrir("explorar/evolucao.html?geo=BR&comparar=SP,PE&sem_topo=1");
  await esperarGrafico(pagina);
  const ms = Date.now() - inicio;
  assert.ok(ms < LIMITE_MS, `primeiro gráfico em ${ms} ms (limite ${LIMITE_MS})`);
  assert.deepEqual(await errosOjs(pagina), []);
  const titulo = await pagina.$eval("#titulo-evolucao", (e) => e.textContent);
  assert.match(titulo, /Brasil, São Paulo e Pernambuco/);
  // Série sem o top 0,01%: legenda de linhas aparece.
  assert.ok(await pagina.$(".legenda-linhas"));
  assert.deepEqual(problemas, []);
  await pagina.close();
});

test("Evolução: filtro muda a URL; leitura por ponteiro e por teclado", async () => {
  const { pagina } = await abrir("explorar/evolucao.html");
  await esperarGrafico(pagina);
  await escolher(pagina, "Geografia", "SP");
  await escolher(pagina, "Indicador", "top_1_share");
  await pagina.waitForFunction(() => location.search.includes("geo=SP") && location.search.includes("ind=top_1_share"));
  assert.match(await pagina.$eval("#titulo-evolucao", (e) => e.textContent), /Participação do top 1% — São Paulo/);

  await escolher(pagina, "Ler os valores do ano", 2018);
  await pagina.waitForFunction(() => document.querySelector(".leitura-ponto").textContent.includes("2018"));
  assert.match(await leitura(pagina), /^2018 · São Paulo: \d+,\d% · 2018 não é comparável$/);
  await escolher(pagina, "Ler os valores do ano", "");

  // O ponteiro do Plot só pega pontos a até 40 px: passa sobre um ponto da série.
  // hover() rola até o ponto antes de mover o mouse.
  await (await pagina.$("svg[class^=plot] circle")).hover();
  await pagina.waitForFunction(() => /^\d{4} · /.test(document.querySelector(".leitura-ponto").textContent.trim()));
  await pagina.close();
});

test("Evolução: link da visão é lido na abertura", async () => {
  const { pagina } = await abrir("explorar/evolucao.html?geo=PE&ind=palma&conceito=RTB");
  await esperarGrafico(pagina);
  const titulo = await pagina.$eval("#titulo-evolucao", (e) => e.textContent);
  assert.match(titulo, /Palma .* — Pernambuco/);
  await pagina.close();
});

test("Evolução: tabela e CSV em pt-BR", async () => {
  const { pagina } = await abrir("explorar/evolucao.html?geo=BR");
  await esperarGrafico(pagina);
  const aba = await pagina.$$eval("a.nav-link", (as) => as.findIndex((a) => a.textContent.trim() === "Tabela"));
  await (await pagina.$$("a.nav-link"))[aba].click();
  await pagina.waitForSelector(".tabela-explorar caption", { visible: true });
  // Captura o arquivo gerado em vez de baixá-lo.
  await pagina.evaluate(() => {
    window.__blobs = [];
    const original = URL.createObjectURL;
    URL.createObjectURL = (blob) => { window.__blobs.push(blob); return original(blob); };
  });
  await pagina.evaluate(() => [...document.querySelectorAll("button")].find((b) => b.textContent.includes("CSV")).click());
  const texto = await pagina.evaluate(async () => {
    const bytes = new Uint8Array(await window.__blobs[0].arrayBuffer());
    return { bom: bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf, texto: new TextDecoder().decode(bytes) };
  });
  assert.ok(texto.bom, "CSV sem BOM");
  // O TextDecoder descarta o BOM, já conferido acima nos bytes.
  assert.match(texto.texto, /^"Ano";"Geografia";"Serie";"Conceito";"Indicador";"Valor"\r\n2017;"Brasil";"Todos os grupos";/);
  assert.match(texto.texto, /;0,\d+\r\n/);
  await pagina.close();
});

test("Evolução: funciona sem o CDN", async () => {
  const { pagina } = await abrir("explorar/evolucao.html", { bloquearCdn: true });
  await esperarGrafico(pagina);
  assert.deepEqual(await errosOjs(pagina), []);
  await pagina.close();
});

test("Evolução: sem violações graves de acessibilidade (axe)", async () => {
  const { pagina } = await abrir("explorar/evolucao.html?geo=BR&comparar=SP");
  await esperarGrafico(pagina);
  assert.deepEqual(await axe(pagina), []);
  await pagina.close();
});

test("Relatórios: figuras SVG do módulo JS carregam, com texto alternativo", async () => {
  for (const [caminho, minimo] of [["reports/report.html", 9], ["reports/executive-summary.html", 3]]) {
    const { pagina, problemas } = await abrir(caminho);
    await pagina.waitForSelector("img[src*='figuras/']");
    const imagens = await pagina.$$eval("img[src*='figuras/']", (imgs) => Promise.all(imgs.map(async (img) => {
      if (!img.complete) await new Promise((r) => { img.onload = r; img.onerror = r; });
      return { src: img.getAttribute("src"), alt: img.getAttribute("alt") ?? "", largura: img.naturalWidth };
    })));
    assert.ok(imagens.length >= minimo, `${caminho}: ${imagens.length} figuras`);
    for (const img of imagens) {
      assert.ok(img.largura > 0, `${img.src} não carregou`);
      assert.ok(img.alt.length > 40, `${img.src} sem texto alternativo`);
    }
    assert.deepEqual(problemas, []);
    await pagina.close();
  }
});

// Checagens comuns a cada página Explorar: abre com o estado do link, desenha
// dentro do limite, sem erro nem 404, e sem violação grave de acessibilidade.
const paginas = [
  { caminho: "explorar/topos.html?geo=SP&ano=2023", titulo: "#titulo-topos", espera: /São Paulo/ },
  { caminho: "explorar/estados.html?ano=2018&ind=top_1_share", titulo: "#titulo-estados", espera: /Participação do top 1%, 2018/ }
];

for (const p of paginas) {
  test(`${p.caminho.split("?")[0]}: abre com o estado do link, rápido, sem erros e acessível`, async () => {
    const { pagina, problemas, inicio } = await abrir(p.caminho);
    await esperarGrafico(pagina);
    const ms = Date.now() - inicio;
    assert.ok(ms < LIMITE_MS, `primeiro gráfico em ${ms} ms`);
    assert.deepEqual(await errosOjs(pagina), []);
    assert.match(await pagina.$eval(p.titulo, (e) => e.textContent), p.espera);
    assert.deepEqual(await axe(pagina), []);
    assert.deepEqual(problemas, []);
    await pagina.close();
  });
}

test("Topos: caixas com variação e frases de contagem", async () => {
  const { pagina } = await abrir("explorar/topos.html?geo=BR&ano=2019");
  await esperarGrafico(pagina);
  const variacoes = await pagina.$$eval(".caixa-valor-variacao", (es) => es.map((e) => e.textContent));
  assert.equal(variacoes.length, 4);
  assert.ok(variacoes.every((v) => v.endsWith("ante 2018 (2018 não comparável)")), variacoes.join(" | "));
  const rodape = await pagina.$eval(".bloco-rodape", (e) => e.textContent);
  assert.match(rodape, /Brasil, 2019: o top 0,01% reúne [\d.]+ declarações/);
  await pagina.close();
});

test("Estados: mapa com 27 UFs e ordem por nome na URL e na tabela", async () => {
  const { pagina } = await abrir("explorar/estados.html");
  await esperarGrafico(pagina);
  await escolher(pagina, "Ordenar UFs por", "nome");
  await pagina.waitForFunction(() => location.search.includes("ordem=nome"));
  const primeira = await pagina.$eval(".tabela-explorar tbody tr th", (e) => e.textContent);
  assert.equal(primeira, "Acre");
  const ufs = await pagina.$$eval("svg[class^=plot] text", (ts) => ts.map((t) => t.textContent).filter((t) => /^[A-Z]{2}$/.test(t)));
  assert.equal(new Set(ufs).size, 27);
  await pagina.close();
});
