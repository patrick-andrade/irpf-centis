// Servidor estático mínimo para testar o site renderizado (output/site) sob o
// mesmo subcaminho do GitHub Pages (/irpf-centis/). Servir na raiz esconderia
// links que só quebram no subcaminho.
//
// Uso: node scripts/servir.mjs [pasta] [--prefixo /irpf-centis] [--porta 8790]
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const tipos = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8", ".geojson": "application/geo+json; charset=utf-8",
  ".csv": "text/csv; charset=utf-8", ".svg": "image/svg+xml", ".png": "image/png",
  ".pdf": "application/pdf", ".woff2": "font/woff2", ".ttf": "font/ttf", ".txt": "text/plain; charset=utf-8",
  ".ico": "image/x-icon", ".xml": "application/xml"
};

export function servir({ raiz = "output/site", prefixo = "/irpf-centis", porta = 0 } = {}) {
  const base = path.resolve(raiz);
  const servidor = http.createServer((req, res) => {
    const url = new URL(req.url, "http://localhost");
    let caminho = decodeURIComponent(url.pathname);
    if (prefixo && caminho === prefixo) {
      res.writeHead(301, { Location: `${prefixo}/` });
      return res.end();
    }
    if (prefixo) {
      if (!caminho.startsWith(`${prefixo}/`)) {
        res.writeHead(404);
        return res.end("fora do prefixo");
      }
      caminho = caminho.slice(prefixo.length);
    }
    let arquivo = path.join(base, caminho);
    if (!arquivo.startsWith(base)) {
      res.writeHead(403);
      return res.end();
    }
    if (fs.existsSync(arquivo) && fs.statSync(arquivo).isDirectory()) arquivo = path.join(arquivo, "index.html");
    if (!fs.existsSync(arquivo)) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      return res.end("não encontrado");
    }
    res.writeHead(200, { "Content-Type": tipos[path.extname(arquivo).toLowerCase()] ?? "application/octet-stream" });
    fs.createReadStream(arquivo).pipe(res);
  });
  return new Promise((resolver) => {
    servidor.listen(porta, "127.0.0.1", () => resolver(servidor));
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const opcao = (nome, padrao) => {
    const i = args.indexOf(nome);
    return i >= 0 ? args[i + 1] : padrao;
  };
  const raiz = args.find((a, i) => !a.startsWith("--") && !args[i - 1]?.startsWith("--")) ?? "output/site";
  const prefixo = opcao("--prefixo", "/irpf-centis");
  const porta = Number(opcao("--porta", 8790));
  const servidor = await servir({ raiz, prefixo, porta });
  console.log(`Servindo ${raiz} em http://127.0.0.1:${servidor.address().port}${prefixo}/`);
}
