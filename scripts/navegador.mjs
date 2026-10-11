// Localiza um Chrome ou Edge instalado, para o puppeteer-core não precisar
// baixar navegador. A variável NAVEGADOR tem prioridade.
import fs from "node:fs";

const candidatos = [
  process.env.NAVEGADOR,
  process.env.CHROME_BIN,
  "/usr/bin/google-chrome",
  "/usr/bin/google-chrome-stable",
  "/usr/bin/chromium-browser",
  "/usr/bin/chromium",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
];

export function caminhoNavegador() {
  const achado = candidatos.find((c) => c && fs.existsSync(c));
  if (!achado) throw new Error("Nenhum Chrome/Edge encontrado. Defina NAVEGADOR com o caminho do executável.");
  return achado;
}
