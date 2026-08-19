# Changelog

Todas as alterações relevantes deste projeto serão documentadas neste arquivo.

O formato segue *Keep a Changelog* e as versões públicas usarão versionamento baseado no ano da edição dos dados.

## [0.2.0] — 2026-08-19

Rodada de auditoria técnica e primeira publicação estática. Diagnóstico completo em `docs/diagnostico-tecnico.md`.

### Corrigido

- Filtro geográfico inoperante nos gráficos "nacionais" dos relatórios (`plot_metric_evolution`/`plot_top_shares` misturavam as 29 geografias por captura na máscara de dados do `dplyr::filter`).
- Três abas do painel (Rendimentos, Bens e dívidas, Estados) falhavam em silêncio sem dados; agora exibem o cartão padrão de dados ausentes.
- Linha da aba "Evolução" nunca era desenhada (estética `text` fragmentava os grupos do `geom_line`).
- Deflatores IPCA ausentes deixavam todos os valores reais `NA` silenciosamente; o pipeline agora aborta com orientação.
- `quality_gate` passou a bloquear de fato a escrita de `data/processed/` e do bundle do painel no grafo do `targets`.
- Fronteira de ponto flutuante nas participações de topo (top 0,01%) protegida por tolerância numérica.
- `Dockerfile` mínimo e correto (não copia mais 179 MB de dados desnecessários); documentado como seguro de migração.
- ~1.600 avisos de deprecação do tidyselect (`.data$` em `select`/`pull`/`pivot_longer`) eliminados.
- Bundle do painel não transporta mais um `distribution_bins` vazio nem dependência espúria de rebuild.

### Adicionado

- Alíquota efetiva média por grupo da distribuição (`R/taxation.R`, `effective-tax.parquet`), com curvas no relatório e no painel — item previsto no plano v01 e ausente da implementação.
- Limites inferior e superior do Gini com dados agrupados (Gastwirth 1972): colunas `gini_lower_bound`/`gini_upper_bound`.
- Atkinson ε = 1 (média geométrica ponderada), antes retornava `NA`.
- Métricas monetárias em reais de 2024 (`income_total_real`, `income_mean_real`) e rótulos "R$ de 2024" em relatórios e painel.
- Seção "Robustez" do relatório implementada com comparação RTB/RB3/RB4/RB5 (antes era um esboço em tempo futuro).
- Bibliografia acadêmica (Atkinson, Theil, Gastwirth, Wolfson, Esteban–Ray, Palma, Cowell, Blanchet–Fournier–Piketty, DINA/WID, Medeiros–Souza–Castro, Souza, Morgan, Gobetti–Orair) citada no apêndice técnico.
- Suíte de testes ampliada de 11 para ~40 blocos (~150 expectativas): parser XLSX nos dois layouts com fixtures sintéticos, normalização de unidades, série patrimonial, tributação, helpers de relatório (regressão do filtro geográfico) e módulos do painel via `shiny::testServer`.
- Site Quarto (`type: website`) com landing page, navbar e diagnóstico técnico; painel exportado para WebAssembly (shinylive) em `output/site/app`.
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
