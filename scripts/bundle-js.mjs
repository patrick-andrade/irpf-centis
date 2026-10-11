// Gera assets/js/irpf-viz.js, o bundle que as páginas Explorar importam.
// O arquivo fica versionado: o deploy só repete o render do Quarto, sem Node.
// O CI roda este script e falha se o resultado divergir do que está no git.
import { build } from "esbuild";
import { fileURLToPath } from "node:url";
import path from "node:path";

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const resultado = await build({
  entryPoints: [path.join(raiz, "js/index.js")],
  outfile: path.join(raiz, "assets/js/irpf-viz.js"),
  bundle: true,
  format: "esm",
  // O Quarto analisa os módulos importados pelas células OJS como ES2020 para
  // achar dependências; sintaxe mais nova faria o arquivo ser ignorado.
  target: "es2020",
  minify: true,
  legalComments: "eof",
  charset: "utf8",
  metafile: true,
  banner: { js: "// Gerado por scripts/bundle-js.mjs a partir de js/. Não edite à mão." }
});

const bytes = Object.values(resultado.metafile.outputs)[0].bytes;
console.log(`assets/js/irpf-viz.js: ${(bytes / 1024).toFixed(0)} KB`);
