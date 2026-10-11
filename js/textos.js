// Frases fixas das páginas Explorar, as mesmas do painel antigo.

export const fonteReceita = "Receita Federal do Brasil, tabulações por centis de declarações válidas do IRPF.";

// Uma declaração não é uma pessoa: esta frase acompanha qualquer contagem.
export const notaUnidade = "A unidade divulgada é a declaração válida, que pode reunir titular, " +
  "dependentes e declaração conjunta; contagens de declarações não são contagens de pessoas.";

export const notaIndicesAgrupados = "Os índices são estimados a partir das médias e das quantidades " +
  "dos grupos divulgados; não observam a variação dentro de cada grupo.";

export const notaTopoOrdinal = "O último 1% da distribuição reúne 19 grupos divulgados, que na escala " +
  "acima ocupariam 1% da largura. Abaixo, cada um recebe a mesma largura; o primeiro ponto, até o " +
  "percentil 99,00, é o centil 99, que fica fora do top 1% e serve de referência.";

export const avisoUniverso = "Os dados representam declarações válidas do IRPF, não toda a população brasileira.";

// Variação contra o ano anterior: "+0,006 ponto ante 2023". Quando a
// comparação toca 2018, a ressalva vai junto.
export function variacao(atual, anterior, formatar, unidade, ano) {
  if (!Number.isFinite(atual) || !Number.isFinite(anterior)) return null;
  const delta = atual - anterior;
  const sinal = delta > 0 ? "+" : delta < 0 ? "\u2212" : "=";
  const ressalva = ano === 2018 || ano === 2019 ? " (2018 não comparável)" : "";
  return `${sinal}${formatar(Math.abs(delta))} ${unidade} ante ${ano - 1}${ressalva}`;
}

// Nota de 2018 da Evolução: fala do que o gráfico mostra. As geografias abrem a
// frase, sem preposição ("no Brasil", "em São Paulo" exigiriam concordância).
export function nota2018Evolucao({ escolhidasComSalto, outrasComSalto, nomes, semTopoDisponivel }) {
  if (escolhidasComSalto.length > 0) {
    return `${nomes(escolhidasComSalto)}: 2018 se afasta dos anos vizinhos porque um único ` +
      "grupo do topo destoa no arquivo oficial; o valor é preservado como publicado. " +
      (semTopoDisponivel ? "Marque a série sem o top 0,01% para ver o ano sem ele." : "");
  }
  if (outrasComSalto.length > 0) {
    return "Nas geografias escolhidas, 2018 acompanha os anos vizinhos neste indicador. " +
      `O ano não é comparável nestas: ${nomes(outrasComSalto)}.`;
  }
  return "O ano-calendário 2018 fica sombreado: na fonte oficial, um grupo do topo destoa dos anos vizinhos.";
}

// Topos: "Brasil, 2024: o top 0,01% reúne 4.123 declarações, das quais 512
// conjuntas, e 3.001 dependentes." Ausência de conjuntas não vira zero.
export function fraseContagem(linha, geoNome, contar) {
  let partes = `${contar(linha.contributors)} declarações`;
  if (Number.isFinite(linha.joint_returns)) partes += `, das quais ${contar(linha.joint_returns)} conjuntas`;
  if (Number.isFinite(linha.dependents)) partes += `, e ${contar(linha.dependents)} dependentes`;
  return `${geoNome}, ${linha.year}: o top ${linha.group_label} reúne ${partes}.`;
}
