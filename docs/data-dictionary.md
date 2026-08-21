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


## `wealth_by_bin`

Uma linha por ano, geografia e grupo disjunto de RB4, com bens e dívidas observados dentro dos grupos ordenados por renda. Contém a soma das quatro famílias de bens (`assets_sum_real`), o total consolidado quando divulgado (`assets_total_real`, de 2022 em diante), as dívidas e ônus, a participação de cada grupo nos estoques do recorte (`assets_share`, `debt_share`) e a razão dívida/renda (`debt_income_ratio` = `debts_real / rank_sum_real`; `NA` quando a renda do grupo é nula). Exportado em `data/processed/wealth-by-bin.parquet`; o bundle do painel recebe um recorte de colunas.

## `top_group_counts`

Uma linha por ano, geografia, ranking e grupo de topo (`top_10`, `top_1`, `top_0_1`, `top_0_01`). Soma as folhas disjuntas acima do limiar e registra `contributors`, `joint_returns` e `dependents`. `joint_returns` é `NA` nos anos em que a fonte não divulga o campo. Exportado em `data/processed/top-group-counts.parquet`.

## Contratos de glossário

`config/schema/indicators.csv` define cada indicador exibido: rótulo, definição, leitura, faixa, a nota metodológica de cálculo com dados agrupados e as chaves bibliográficas. `config/schema/references.csv` projeta `reports/references.bib` num formato que o painel consegue renderizar sem pandoc; `test-glossary.R` falha se os dois divergirem.
