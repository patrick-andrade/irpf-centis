# Changelog

Todas as alterações relevantes deste projeto serão documentadas neste arquivo.

O formato segue *Keep a Changelog* e as versões públicas usarão versionamento baseado no ano da edição dos dados.

## [Não publicado]

Revisão de visualização e comunicação, com duas correções de dados encontradas
pelo caminho.

### Corrigido

- **Campos deslocados em 2017–2021.** Nos arquivos monolíticos, o cabeçalho traz um rótulo a mais que as colunas de dados: "Rendimentos recebidos de Pessoa Física/Exterior — Aluguéis" aparece repetido em duas colunas vizinhas e a última coluna rotulada ("Quantidade de Dependentes") não tem dados. A partir da duplicata, cada coluna de dados recebia o rótulo da coluna seguinte. O efeito publicado: "Imposto Devido" lia os valores de "Imóveis", e a alíquota efetiva média de 2017–2021 saía entre 97% e 123% no relatório, com máximo de 270.697.056% nos dados curados. Corrigido em `read_receita_sheet()`, que detecta o rótulo órfão e realinha. As alíquotas nacionais passam a 5,96%, 6,02%, 6,03% e 5,71% em 2017, 2019, 2020 e 2021, coerentes com 5,84%, 5,62% e 5,79% em 2022–2024. `distribution_bins` não era afetado — Gini, participações de topo e demais indicadores de desigualdade estavam corretos.
- **Campos de bens e direitos sem mapeamento em 2017–2022.** A anotação de unidade (`[R$ milhões]`, `[R$]`) entrava no texto do cabeçalho e derrubava os padrões ancorados de `fields.csv`, que só funcionavam no layout de 2024 por reconhecimento posicional. `assets_real_estate`, `assets_movable`, `assets_financial`, `assets_other` e `assets_total` ficavam como `unmapped_*` em seis dos oito anos, deixando a aba "Bens e dívidas" e a seção patrimonial do relatório sem dados fora de 2023–2024. A unidade passa a ser descartada antes da resolução do campo.
- Alíquota efetiva só é publicada quando o conceito de renda do ranking contém a renda tributada. Em RB5, RB9 e RB10 um grupo pode ter renda do conceito próxima de zero e ainda dever imposto sobre rendimentos fora dele; a razão agora fica `NA` em vez de produzir milhares por cento. `tax_due` e `rank_sum` seguem íntegros.
- Sufixos monetários do painel em português: `scales::cut_short_scale()` escrevia "R$ 500B", que em português não é quinhentos bilhões.
- Mapa por UF em escala de classes com limites declarados, no lugar da escala contínua — com Wolfson variando de 0,35 a 4,50 entre estados, a escala contínua colapsava o contraste das outras 26 UFs para acomodar uma.
- UFs identificadas por nome no relatório e no painel, não por sigla.

### Adicionado

- `R/viz.R`: camada de visualização compartilhada entre relatórios e painel — tema, escalas com domínio declarado, paleta acessível e anotação. Sincronizada para `app/R/viz.R` por `sync_app_viz()`, com teste que falha se as duas divergirem e teste que barra pacote fora do conjunto disponível em WebAssembly.
- Escalas com faixa declarada em vez de ajuste automático ao dado. Índices ganham amplitude mínima (0,15 para Gini de renda) e âncoras redondas; participações e alíquotas partem sempre do zero; primeira e última quebra coincidem com os limites do eixo. O Gini patrimonial passa a usar âncora fixa de 0,70 a 1,00: em dezesseis anos a série varia menos de 0,03, e a escala anterior transformava essa estabilidade em penhasco. Segue Correll, Bertini & Franconeri (CHI 2020), que mediram que indicar o truncamento não desfaz o exagero percebido.
- Detalhe do topo da distribuição em eixo ordinal de largura igual, no relatório e no painel. Os 20 grupos disjuntos do topo ocupavam 2% da largura em escala de percentil, comprimindo num penhasco de dois pixels o achado mais noticiável do estudo: em 2024 a alíquota efetiva sobe até 9,9% no percentil 90 e cai para 0,86% no 0,01% mais rico.
- Gráfico de sensibilidade ao grupo 120, com a série calculada com e sem o top 0,01%.
- Portões de plausibilidade dos indicadores derivados (`R/validation.R`): alíquota efetiva fora de [0, 1] e Gini/Atkinson fora de [0, 1] reprovam a construção; cobertura da alíquota, Wolfson > 1, Palma > 50 e saltos anuais de Gini viram avisos registrados em `quality-checks.csv`. Um segundo alvo `derived_quality_gate` barra a escrita dos produtos.
- Títulos-mensagem e texto alternativo (`fig-alt`) em todas as figuras dos relatórios.
- Rótulos diretos no fim das linhas, com separação automática, no lugar de legendas em ordem alfabética que não coincidiam com a ordem vertical das séries.
- Variação contra o ano anterior nos cartões da visão geral do painel.

### Alterado

- Rampa sequencial para séries aninhadas (RTB ⊂ RB3 ⊂ RB4; Top 10% ⊃ Top 1% ⊃ Top 0,1%), que a paleta qualitativa anterior desordenava, e Okabe-Ito para categorias sem ordem. O mesmo `#F2A900` era "RB3" num gráfico e "ponto de destaque" em outro; `#005A9C` e `#6A1B9A` convergem sob deuteranopia e eram justamente os extremos da comparação de conceitos.
- Grades menores removidas e grade maior restrita ao eixo da medida.
- RB5 sai da comparação de conceitos do relatório: com o top 1% acima de 65%, comprimia a variação de RTB, RB3 e RB4.
- Wolfson e Palma rotulados como instáveis no seletor do painel; a visão geral mostra a participação do top 0,1% no lugar do Wolfson.
- Ano-calendário 2018 documentado como não comparável em `docs/limitations.md`, após conferência célula a célula contra o arquivo oficial: o grupo 120 traz soma de R$ 948,3 bilhões e média de R$ 298,1 milhões por declaração, contra R$ 115,5 bilhões e R$ 37,9 milhões em 2017. Os valores são os publicados pela Receita e foram preservados.

## [0.2.0] — 2026-08-20

Rodada de revisão técnica e primeira publicação estática.

### Corrigido

- Filtro geográfico inoperante nos gráficos "nacionais" dos relatórios (`plot_metric_evolution`/`plot_top_shares` misturavam as 29 geografias por captura na máscara de dados do `dplyr::filter`).
- Três abas do painel (Rendimentos, Bens e dívidas, Estados) falhavam em silêncio sem dados; agora exibem o cartão padrão de dados ausentes.
- Linha da aba "Evolução" nunca era desenhada (estética `text` fragmentava os grupos do `geom_line`).
- Cinco das sete abas do painel abriam com os filtros vazios no navegador: a UI de cada aba era montada por `renderUI` e as saídas de abas ocultas ficam suspensas, então os `updateSelectInput` da inicialização chegavam antes de os selects existirem e se perdiam. A UI dos módulos passa a entrar direto no navbar, com teste de regressão sobre o HTML inicial do painel.
- Todos os gráficos do painel abriam com altura zero e o `renderPlot` abortava com `invalid 'height' argument`: com `fillable = TRUE` no `page_navbar` cada aba vira contêiner de preenchimento e anula a altura declarada dos `plotOutput`. Medido no navegador sobre o HTML da UI: as sete saídas ficam com altura 0 nesse modo e com a altura declarada (520/440/360px) sem ele.
- Tabela de UFs do painel formatada em português; saía com `0.48` e `105148.00`.
- Deflatores IPCA ausentes deixavam todos os valores reais `NA` silenciosamente; o pipeline agora aborta com orientação.
- `quality_gate` passou a bloquear de fato a escrita de `data/processed/` e do bundle do painel no grafo do `targets`.
- Fronteira de ponto flutuante nas participações de topo (top 0,01%) protegida por tolerância numérica.
- `Dockerfile` mínimo e correto (não copia mais 179 MB de dados desnecessários); documentado como seguro de migração.
- ~1.600 avisos de deprecação do tidyselect (`.data$` em `select`/`pull`/`pivot_longer`) eliminados.
- Bundle do painel não transporta mais um `distribution_bins` vazio nem dependência espúria de rebuild.
- Formatação numérica em português nos relatórios e no painel: `scales` usava as convenções do inglês e imprimia `R$ 154,061` (lido como cento e cinquenta e quatro reais) onde o valor é `R$ 154.061`; milhar passa a usar ponto e decimal, vírgula, também nos eixos dos gráficos e nos cartões do painel.

### Adicionado

- Alíquota efetiva média por grupo da distribuição (`R/taxation.R`, `effective-tax.parquet`), com curvas no relatório e no painel — item previsto no plano v01 e ausente da implementação.
- Limites inferior e superior do Gini com dados agrupados (Gastwirth 1972): colunas `gini_lower_bound`/`gini_upper_bound`.
- Atkinson ε = 1 (média geométrica ponderada), antes retornava `NA`.
- Métricas monetárias em reais de 2024 (`income_total_real`, `income_mean_real`) e rótulos "R$ de 2024" em relatórios e painel.
- Seção "Robustez" do relatório implementada com comparação RTB/RB3/RB4/RB5 (antes era um esboço em tempo futuro).
- Bibliografia acadêmica (Atkinson, Theil, Gastwirth, Wolfson, Esteban–Ray, Palma, Cowell, Blanchet–Fournier–Piketty, DINA/WID, Medeiros–Souza–Castro, Souza, Morgan, Gobetti–Orair) citada no apêndice técnico.
- Suíte de testes ampliada de 11 para ~40 blocos (~150 expectativas): parser XLSX nos dois layouts com fixtures sintéticos, normalização de unidades, série patrimonial, tributação, helpers de relatório (regressão do filtro geográfico) e módulos do painel via `shiny::testServer`.
- Site Quarto (`type: website`) com landing page e navbar; painel exportado para WebAssembly (shinylive) em `output/site/app`.
- Workflow `deploy-pages.yml`: publicação automática no GitHub Pages a partir do `_freeze/` committed, sem dados no CI.
- Comando `run.cmd site` (render + export do painel).

### Alterado

- Contrato do bundle do painel: `state_geometry` (sf) → `state_polygons` (tibble achatado); mapa por `geom_polygon` — o painel ficou 100% livre de `sf` e compatível com webR.
- Métricas calculadas sobre o contrato deflacionado (índices adimensionais inalterados).
- Metadados públicos: autoria real, licenças MIT + CC BY 4.0, `CITATION.cff` com repositório e site, `public_repository: true`.
- `DESCRIPTION` enxugado (removidos leaflet, plotly, gt, reactable, shinyvalidate, shinytest2, styler, rsconnect, glue não usados); adicionados `shinylive` e `writexl`; `renv.lock` re-snapshotado.

### Removido

- Código morto: `validate_manifest_files`, `empty_wealth_ranked_national`, `source_project_files`; perfil `_quarto-ci.yml`.

## [Não publicado]

### Adicionado

- Plano imutável da versão 01.
- Fundação do projeto R, Quarto, targets e Shiny.
- Contratos normalizados, aquisição auditável e validações hierárquicas.
- Indicadores agrupados de desigualdade, concentração e polarização.
- Estrutura dos três produtos de divulgação.
- Manifesto real de 53 fontes oficiais e cache bruto 2017–2024, com SHA-256.

### Corrigido

- Parser do layout monolítico para recuperar os 20 estratos hierárquicos do topo e mapear campos pelo cabeçalho.

### Conhecido

- Divergências monetárias internas nos detalhamentos RTB subnacionais de 2017–2021 são preservadas e exportadas como avisos; as contagens reconciliam.

### Segurança

- Dados brutos, credenciais, bibliotecas e artefatos locais excluídos do Git.
- Publicação condicionada a revisão humana.
