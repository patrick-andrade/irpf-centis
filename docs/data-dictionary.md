# Dicionário de dados

Os contratos executáveis são definidos em `config/schema/` e validados pelo pipeline.

## `distribution_bins`

Uma linha por ano, geografia, conceito de ordenação e grupo hierárquico. A chave é `year`, `geo_level`, `geo_code`, `ranking_id`, `bin_code`.

Campos principais: limites percentuais, quantidade de contribuintes, declarações conjuntas, limite superior, soma, acumulado, média, posição hierárquica e indicador de grupo disjunto.

## `income_components`

Uma linha por chave distributiva e `component_id`. Contém o valor nominal, o valor real e o grupo semântico do campo: tributável, exclusivo, isento, transferência, dedução, imposto, ativo, passivo ou contagem.

## `effective_tax`

Uma linha por chave distributiva das folhas disjuntas, com o imposto devido, a renda do conceito de ranking e a alíquota efetiva média do grupo (`effective_rate = tax_due / rank_sum`; `NA` quando a renda é nula ou não divulgada). Exportado em `data/processed/effective-tax.parquet` e, no recorte RB4, no bundle do painel.

## `distribution_metrics`

Uma linha por ano, geografia e ranking com os indicadores agrupados. Inclui contagens, totais e médias nominais e em R$ de 2024, o intervalo `gini_lower_bound`/`gini_upper_bound` (Gastwirth), Theil T, Atkinson (ε configurável), participações de topo e base, Palma, P90/P50 e as medidas de polarização.

## `coverage_context`

Uma linha por ano e geografia. Deve identificar claramente numerador, denominador, idade mínima do denominador, fonte e situação de validação.

## `wealth_ranked_national`

Série suplementar nacional em que a ordenação é realizada diretamente pelo patrimônio declarado. Seu esquema específico é mantido separado para evitar confusão com bens observados dentro dos centis de renda.

