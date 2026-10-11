// CSV da seleção atual, para abrir no Excel em português: ";" como separador,
// vírgula decimal, CRLF e BOM UTF-8. Sem o BOM, o Excel lê "São Paulo" como
// "SÃ£o Paulo". É o mesmo dialeto do `write.csv2()` que o painel antigo usava.

const BOM = "\uFEFF";

function celula(valor) {
  if (valor === null || valor === undefined || (typeof valor === "number" && !Number.isFinite(valor))) return "";
  if (typeof valor === "number") return String(valor).replace(".", ",");
  if (typeof valor === "boolean") return valor ? "TRUE" : "FALSE";
  return `"${String(valor).replace(/"/g, '""')}"`;
}

// `colunas`: [{ id, rotulo }] ou nomes; as linhas são objetos.
export function csvPtBr(linhas, colunas) {
  const defs = colunas.map((c) => (typeof c === "string" ? { id: c, rotulo: c } : c));
  const cabecalho = defs.map((c) => `"${String(c.rotulo).replace(/"/g, '""')}"`).join(";");
  const corpo = linhas.map((l) => defs.map((c) => celula(l[c.id])).join(";"));
  return `${BOM}${[cabecalho, ...corpo].join("\r\n")}\r\n`;
}

export function baixarTexto(texto, nomeArquivo, tipo = "text/csv;charset=utf-8") {
  const blob = new Blob([texto], { type: tipo });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = nomeArquivo;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function baixarCsv(linhas, colunas, nomeArquivo) {
  baixarTexto(csvPtBr(linhas, colunas), nomeArquivo);
}
