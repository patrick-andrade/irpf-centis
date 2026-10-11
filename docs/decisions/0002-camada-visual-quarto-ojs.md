# ADR 0002 — Camada visual em Quarto + OJS (Observable Plot)

**Status:** aceito em 2026-10-10.

## Contexto

Até a versão 0.3.0, a camada visual tinha dois sistemas em R. O ggplot desenhava as figuras dos relatórios (HTML e PDF via Typst). O painel interativo era um app Shiny exportado com shinylive, isto é, R rodando em WebAssembly no navegador.

O painel pagava o custo de subir o R no navegador a cada visita. Medido em 2026-10-10 com o Edge 155 headless, num servidor local sem compressão e com mediana de 3 rodadas, a aba Evolução levava 22,1 s até o primeiro gráfico na primeira visita e 20,6 s na segunda, transferindo ~41 MB. No GitHub Pages eram 35–40 s. O cache quase não ajuda, porque o tempo vai em iniciar o runtime e carregar pacotes, não em download.

Os PDFs, por sua vez, recebiam SVG do Cairo, com o texto dos gráficos como contornos de glifo (não selecionável) e ~140 KB por figura.

## Decisão

Uma única camada visual em JavaScript, com Observable Plot, servindo as duas saídas:

- **Páginas Explorar** (`explorar/*.qmd`): páginas do próprio site Quarto, só com células OJS e sem blocos R, de modo que renderizam sem R e não entram no `_freeze`. Uma página por aba do painel antigo, com o estado da visão na URL e na sessão.
- **Figuras dos relatórios** (`reports/figuras/*.svg`): as mesmas funções, renderizadas no Node com jsdom (`scripts/figuras.mjs`) e postas no HTML e no PDF como imagem.
- **Módulo** (`js/`): tokens de cor, formatos pt-BR, domínios ancorados, marcas (faixa de 2018, rótulos diretos, eixo ordinal do topo), gráficos, estado da visão, CSV e componentes de interface nativos. O bundle (`assets/js/irpf-viz.js`) fixa Plot 0.6.17 e d3 7.9.0 pelo `package-lock.json` e é servido pelo próprio site, sem depender do CDN nem do Plot 0.6.11 embutido no runtime OJS do Quarto.
- **Dados** (`explorar/dados/`): preparados e testados em R (`R/site_data.R`), em JSON colunar por página, com os arquivos pesados divididos por geografia. O JavaScript só filtra, formata e desenha.

Bundle, figuras e dados ficam versionados: a publicação continua sendo um replay do render do Quarto, sem R nem Node. O CI regenera bundle e figuras e falha se divergirem do que foi commitado.

## Alternativas consideradas

Protótipos da aba Evolução medidos em 2026-10-10, nas mesmas condições:

| Opção | 1ª visita | 2ª visita | Transferido (sem gzip) | Observações |
|---|---|---|---|---|
| shinylive R (painel até a 0.3.0) | 22,1 s | 20,6 s | 41 MB | R em WebAssembly |
| **Quarto + OJS, bundle local** | **0,30 s** | **0,19 s** | 3,5 MB (≈0,6 MB gzip) | funciona com o CDN bloqueado |
| Quarto + OJS, Plot do CDN | 0,56 s | 0,23 s | 2,8 MB | não desenha sem o CDN |
| marimo 0.25.1 (`export html-wasm`) | 12,8 s | 9,0 s | 23 MB | baixa wheels do PyPI em execução; interface em inglês |
| Shiny for Python 1.8.0 + shinylive 0.8.12 | 11,0 s | 10,0 s | 25 MB | gráfico como imagem (matplotlib) |
| Panel 1.9.4 (`convert --to pyodide-worker`) | 0,7 s estático; interativo em 10,9 s | 4,5 s | 23,5 MB | prévia pré-renderizada sem interação |

Também foram avaliados, sem protótipo:

- **Exigem servidor:** Streamlit com stlite (um mantenedor, Pyodide ~6 MB), Solara, Reflex, NiceGUI e Dash.
- **Mesop:** sem manutenção desde 30/09/2026.
- **Evidence:** virou o Evidence Studio, com SQL no servidor.
- **Observable Framework:** usa o mesmo Plot, mas não gera PDF, não declara `lang` e teve um só lançamento desde abril de 2025.

Nenhuma alternativa em Python resolve o PDF sem reintroduzir um segundo sistema visual (matplotlib/plotnine), e todas pagam a partida do Pyodide.

Para o PDF, também foram considerados manter um gerador estático em R (o ggplot), o que mantém os dois sistemas, e abandonar o PDF, o que perde o produto de citação e impressão sem necessidade. A rota Node + jsdom produz SVG de 5–7 KB que o Typst do Quarto põe no PDF com o texto como texto, em Noto Sans.

## Consequências

- **Desempenho:** as páginas abrem o primeiro gráfico em ~0,5 s, contra ~22 s do painel. O relatório em PDF caiu de 479 KB para 202 KB e o sumário de 171 KB para 87 KB.
- **Saem do projeto** o painel `app/` (um redirecionamento estático em `app/index.html` leva links antigos às páginas Explorar), `R/viz.R`, as funções `plot_*` e, do `renv.lock`, ggplot2, shiny, bsicons, shinylive, httpuv e 17 dependências exclusivas deles. A tag `ultimo-shinylive` marca o último commit com o painel.
- **Duas linguagens:** o projeto passa a ter Node 24 como requisito de desenvolvimento (`.nvmrc`, `package-lock.json`), além do R. O cálculo continua em R; o JavaScript é declarativo, uma função por gráfico.
- **Formatação compartilhada:** números escritos em R (tabelas, textos) e em JavaScript (gráficos) precisam coincidir. `tests/fixtures/formatos-ptbr.json` é gerado em R e conferido pelo `node --test`.
- **Testes:** `node --test` para o módulo (formatos, escalas, estado, CSV, estrutura dos gráficos no jsdom, glifos das figuras contra a Noto Sans). Testes de fumaça com Chrome headless e axe-core sobre o site renderizado sob `/irpf-centis/`.
- **Versões:** Quarto fixado em 1.9.38 no CI e no deploy, porque o runtime OJS e o Typst mudam com ele. Dependabot mensal para npm.
- **Riscos acompanhados:** o runtime OJS do Quarto não muda desde 2024 e o Quarto 2 é uma reescrita. Os blocos OJS são finos e o módulo é ESM puro, portável para uma página HTML comum.
