// Leitura dos JSON gerados em R (R/site_data.R). As tabelas vêm em formato
// colunar ({ coluna: [valores] }), que é menor; aqui viram listas de objetos.

export function paraLinhas(colunar) {
  if (!colunar) return [];
  if (Array.isArray(colunar)) return colunar;
  const nomes = Object.keys(colunar);
  if (nomes.length === 0) return [];
  const n = colunar[nomes[0]].length;
  const linhas = new Array(n);
  for (let i = 0; i < n; i++) {
    const linha = {};
    for (const nome of nomes) linha[nome] = colunar[nome][i];
    linhas[i] = linha;
  }
  return linhas;
}

export const finito = (x) => typeof x === "number" && Number.isFinite(x);

export function porChave(linhas, chave, valor) {
  return new Map(linhas.map((l) => [l[chave], valor ? l[valor] : l]));
}

export function anosDisponiveis(linhas, campo = "year") {
  return [...new Set(linhas.map((l) => l[campo]).filter(finito))].sort((a, b) => a - b);
}

// Arquivos com nome montado em tempo de execução (um por geografia). O
// FileAttachment do OJS só aceita nome literal; o caminho é relativo à página,
// e funciona sob o subcaminho do GitHub Pages. Os arquivos chegam ao site pela
// lista `resources` do _quarto.yml.
export async function carregarJson(caminho) {
  const resposta = await fetch(caminho);
  if (!resposta.ok) throw new Error(`Não foi possível carregar ${caminho} (${resposta.status})`);
  return resposta.json();
}
