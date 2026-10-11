// Figuras dos relatórios (HTML e PDF) desenhadas pelo mesmo módulo das páginas
// Explorar, no Node com jsdom. Lê os JSON do pipeline (explorar/dados e
// reports/dados) e grava reports/figuras/*.svg, que ficam versionados: o deploy
// só repete o render do Quarto, e o Typst põe estes SVG no PDF com o texto
// como texto.
//
// O resultado precisa ser o mesmo byte a byte no Windows do autor e no Ubuntu
// do CI (o CI regenera e compara): ordem fixa das figuras, coordenadas
// arredondadas, LF e nenhum carimbo de hora.
//
// Uso: npm run figuras
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { JSDOM } from "jsdom";
import { series, curvaPercentil, curvaTopo } from "../js/graficos.js";
import { paraLinhas } from "../js/dados.js";
import { coresOrdinais } from "../js/tokens.js";
import { codigosTopo } from "../js/marcas.js";
import { ultimosPontos } from "../js/marcas.js";

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ler = (...partes) => JSON.parse(fs.readFileSync(path.join(raiz, ...partes), "utf8"));
const destino = path.join(raiz, "reports", "figuras");

const evolucao = ler("explorar", "dados", "evolucao.json");
const topos = ler("explorar", "dados", "topos.json");
const rendimentosBR = ler("explorar", "dados", "rendimentos", "BR.json");
const direto = ler("explorar", "dados", "patrimonio-direto.json");
const aliquotaGrupos = ler("reports", "dados", "aliquota-grupos.json");

const metricas = paraLinhas(evolucao.metricas);
const semTopo = paraLinhas(evolucao.sem_topo);
const br = (base, conceito = "RB4") => base
  .filter((d) => d.geo_code === "BR" && d.ranking_id === conceito)
  .sort((a, b) => a.year - b.year);

// Largura de referência: 560 px ocupam a largura do texto do PDF (A4, margem
// de 1 pol.), o que deixa o texto do gráfico em ~9,5 pt.
const LARGURA = 560;
const ALTURA = 230;

// Séries ordinais rotuladas no fim: a cor segue a ordem pelo valor final, de
// modo que a ordem vertical das linhas e a da rampa coincidem.
function ordemPorValorFinal(dados, z) {
  return ultimosPontos(dados, { x: "ano", y: "valor", z }).sort((a, b) => b.valor - a.valor).map((d) => d[z]);
}

const figuras = [
  {
    arquivo: "f1-gini.svg",
    desenhar: (document) => {
      const d = br(metricas).map((m) => ({ ano: m.year, valor: m.gini_grouped, serie: "Gini", inferior: m.gini_lower_bound, superior: m.gini_upper_bound }));
      return series(d, {
        document, largura: LARGURA, alturaPainel: ALTURA, rotulos: "extremos", rotuloY: "Gini agrupado",
        faixa: { inferior: "inferior", superior: "superior" }, cor: () => "#0072B2",
        titulo: "Gini da renda declarada: 2024 acima de 2017",
        subtitulo: "Gini agrupado da RB4, Brasil; valores inicial e final rotulados.",
        nota: "Estimativa com dados agrupados do IRPF."
      });
    }
  },
  {
    arquivo: "f2-topos.svg",
    desenhar: (document) => {
      const linha = br(paraLinhas(topos.metricas).map((m) => ({ ...m, ranking_id: "RB4" })));
      const grupos = [["Top 10%", "top_10_share"], ["Top 1%", "top_1_share"], ["Top 0,1%", "top_0_1_share"]];
      const d = grupos.flatMap(([rotulo, coluna]) => linha.map((m) => ({ ano: m.year, valor: m[coluna], serie: rotulo })));
      const paleta = new Map(grupos.map(([r], i) => [r, coresOrdinais(grupos.map(([g]) => g))[i]]));
      return series(d, {
        document, largura: LARGURA, alturaPainel: ALTURA, eixo: "participacao", cor: paleta,
        rotuloY: "Participação na renda declarada",
        titulo: "O 1% mais rico ampliou sua fatia da renda declarada",
        subtitulo: "RB4, Brasil. Grupos aninhados: top 10%, top 1% e top 0,1%.",
        nota: "Grupos disjuntos no cálculo; estimativa com dados agrupados do IRPF."
      });
    }
  },
  {
    arquivo: "f3-aliquota-curva.svg",
    desenhar: (document) => {
      const a = paraLinhas(rendimentosBR.aliquota);
      const ano = Math.max(...a.map((d) => d.year));
      const d = a.filter((x) => x.year === ano && x.bin_code <= 99 && Number.isFinite(x.effective_rate))
        .sort((x, y) => x.share_upper - y.share_upper);
      return curvaPercentil(d, {
        document, largura: LARGURA, alturaPainel: ALTURA, y: "effective_rate", rotuloY: "Alíquota efetiva média",
        anotacaoTopo: "topo detalhado\nno gráfico seguinte",
        titulo: "Alíquota efetiva cresce até o percentil 90",
        subtitulo: `Imposto devido / renda RB4 do grupo, Brasil, ${ano}.`,
        nota: "Imposto devido dividido pela renda RB4 do grupo; média de cada grupo."
      });
    }
  },
  {
    arquivo: "f4-aliquota-topo.svg",
    desenhar: (document) => {
      const a = paraLinhas(rendimentosBR.aliquota);
      const ano = Math.max(...a.map((d) => d.year));
      const d = a.filter((x) => x.year === ano && codigosTopo.includes(x.bin_code) && Number.isFinite(x.effective_rate))
        .sort((x, y) => x.share_upper - y.share_upper);
      return curvaTopo(d, {
        document, largura: LARGURA, alturaPainel: ALTURA, y: "effective_rate", rotuloY: "Alíquota efetiva média",
        rotularPicoUltimo: true,
        titulo: "No topo, a alíquota efetiva recua",
        subtitulo: `Vinte grupos disjuntos em eixo ordinal, Brasil, ${ano}.`,
        nota: "Vinte grupos disjuntos com a mesma largura no eixo: os dez décimos do top 1% e os dez do top 0,1%."
      });
    }
  },
  {
    arquivo: "f5-aliquota-grupos.svg",
    desenhar: (document) => {
      const rotulos = { all: "Todos os declarantes", top_10: "Top 10%", top_1: "Top 1%", top_0_1: "Top 0,1%" };
      const niveis = Object.values(rotulos);
      const d = paraLinhas(aliquotaGrupos.aliquota_grupos)
        .map((x) => ({ ano: x.year, valor: x.effective_rate, serie: rotulos[x.group] }))
        .sort((a, b) => niveis.indexOf(a.serie) - niveis.indexOf(b.serie) || a.ano - b.ano);
      // "Todos os declarantes" é referência, não parte do aninhamento: cinza.
      const paleta = new Map(niveis.map((n, i) => [n, coresOrdinais(niveis, { contexto: [niveis[0]] })[i]]));
      return series(d, {
        document, largura: LARGURA, alturaPainel: ALTURA, eixo: "aliquota", cor: paleta,
        rotuloY: "Alíquota efetiva média",
        titulo: "Alíquota do topo cai; a geral fica estável",
        subtitulo: "Imposto devido / renda RB4 por grupo, Brasil.",
        nota: "Imposto devido dividido pela renda RB4 do grupo; dados agrupados."
      });
    }
  },
  {
    arquivo: "f6-gini-patrimonial.svg",
    desenhar: (document) => {
      const d = paraLinhas(direto.gini_direto).map((x) => ({ ano: x.year, valor: x.gini_grouped, serie: "Gini" }));
      // Âncora fixa de 0,70 a 1,00: a série inteira cabe em 0,03 de amplitude, e
      // uma escala ajustada ao dado transformaria estabilidade em penhasco. A
      // série patrimonial vem de outro estudo e não carrega a ressalva de 2018.
      return series(d, {
        document, largura: LARGURA, alturaPainel: ALTURA, rotulos: "extremos", ressalva2018: false,
        eixoOpcoes: { ancora: [0.7, 1] }, rotuloY: "Gini patrimonial agrupado", cor: () => "#0072B2", girarAnos: true,
        titulo: "Gini patrimonial alto e quase estável",
        subtitulo: "Bens e direitos, Brasil; ordenação direta. Eixo de 0,70 a 1,00.",
        nota: "Estimativa com dados agrupados do IRPF."
      });
    }
  },
  ...[
    ["f7-conceitos-gini.svg", "gini_grouped", "indice", "Gini agrupado",
      "Conceito de renda muda o nível do Gini",
      "RTB, RB3 e RB4, Brasil. Conceitos aninhados: a RTB está contida na RB3, e a RB3 na RB4."],
    ["f8-conceitos-top1.svg", "top_1_share", "participacao", "Participação do top 1%",
      "Renda mais ampla amplia a fatia do topo",
      "Participação do top 1% sob RTB, RB3 e RB4, Brasil."]
  ].map(([arquivo, coluna, eixo, rotuloY, titulo, subtitulo]) => ({
    arquivo,
    desenhar: (document) => {
      const d = ["RTB", "RB3", "RB4"].flatMap((c) => br(metricas, c).map((m) => ({ ano: m.year, valor: m[coluna], serie: c })));
      const ordem = ordemPorValorFinal(d, "serie");
      const paleta = new Map(ordem.map((n, i) => [n, coresOrdinais(ordem)[i]]));
      return series(d, {
        document, largura: LARGURA, alturaPainel: ALTURA, eixo, cor: paleta, rotuloY, titulo, subtitulo,
        nota: "RTB, RB3 e RB4 são definições sucessivamente mais amplas de renda declarada; ver Metodologia. Estimativa com dados agrupados."
      });
    }
  })),
  {
    arquivo: "f9-sensibilidade-topo.svg",
    desenhar: (document) => {
      const niveis = ["Todos os grupos", "Sem o top 0,01%"];
      const d = [
        ...br(metricas).map((m) => ({ ano: m.year, valor: m.gini_grouped, serie: niveis[0] })),
        ...br(semTopo).map((m) => ({ ano: m.year, valor: m.gini_grouped, serie: niveis[1] }))
      ];
      const paleta = new Map(niveis.map((n, i) => [n, coresOrdinais(niveis)[i]]));
      return series(d, {
        document, largura: LARGURA, alturaPainel: ALTURA, cor: paleta, rotuloY: "Gini agrupado",
        titulo: "O grupo do top 0,01% altera a série do Gini",
        subtitulo: "RB4 com todos os grupos e sem o grupo 120, Brasil.",
        nota: "O grupo 120 reúne 0,01% das declarações. Valores de 2018 conferidos contra o arquivo oficial; ver Limitações."
      });
    }
  }
];

// Arredonda coordenadas a duas casas: elimina diferenças de último dígito entre
// plataformas sem mudar nada que se veja.
const ATRIBUTOS_NUMERICOS = ["d", "x", "y", "x1", "x2", "y1", "y2", "cx", "cy", "r", "width", "height", "transform", "points", "dx", "dy"];
function arredondar(no) {
  for (const atributo of ATRIBUTOS_NUMERICOS) {
    const valor = no.getAttribute?.(atributo);
    if (valor) no.setAttribute(atributo, valor.replace(/-?\d+\.\d{3,}/g, (n) => String(Number(Number(n).toFixed(2)))));
  }
  for (const filho of no.children ?? []) arredondar(filho);
}

function serializar(svg) {
  svg.setAttributeNS("http://www.w3.org/2000/xmlns/", "xmlns", "http://www.w3.org/2000/svg");
  svg.setAttributeNS("http://www.w3.org/2000/xmlns/", "xmlns:xlink", "http://www.w3.org/1999/xlink");
  arredondar(svg);
  return `${svg.outerHTML.replace(/\r\n/g, "\n")}\n`;
}

fs.mkdirSync(destino, { recursive: true });
const gerados = [];
for (const figura of figuras) {
  const { document } = new JSDOM("<!doctype html><html lang='pt-BR'></html>").window;
  const svg = figura.desenhar(document);
  const texto = serializar(svg);
  fs.writeFileSync(path.join(destino, figura.arquivo), texto, "utf8");
  gerados.push(`${figura.arquivo} (${(Buffer.byteLength(texto) / 1024).toFixed(1)} KB)`);
}
// Remove figuras que deixaram de existir na lista.
const esperados = new Set(figuras.map((f) => f.arquivo));
for (const nome of fs.readdirSync(destino)) {
  if (nome.endsWith(".svg") && !esperados.has(nome)) fs.rmSync(path.join(destino, nome));
}
console.log(`reports/figuras: ${gerados.join(", ")}`);
