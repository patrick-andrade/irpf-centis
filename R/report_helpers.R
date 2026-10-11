# Formatação numérica em português: milhar com ponto, decimal com vírgula.
# `scales` usa as convenções do inglês por padrão, o que faria "R$ 154,061"
# ser lido como cento e cinquenta e quatro reais em vez de cento e cinquenta
# e quatro mil.
fmt_brl <- function(x, accuracy = 1) {
  scales::label_currency(
    prefix = "R$ ", accuracy = accuracy,
    big.mark = ".", decimal.mark = ","
  )(x)
}

fmt_count <- function(x) {
  scales::label_number(accuracy = 1, big.mark = ".", decimal.mark = ",")(x)
}

fmt_index <- function(x, accuracy = 0.001) {
  scales::number(x, accuracy = accuracy, big.mark = ".", decimal.mark = ",")
}

fmt_share <- function(x, accuracy = 0.1) {
  scales::percent(x, accuracy = accuracy, big.mark = ".", decimal.mark = ",")
}

read_processed_or_empty <- function(file, type = c("parquet", "csv")) {
  type <- match.arg(type)
  path <- project_path("data/processed", file)
  if (!fs::file_exists(path)) return(tibble::tibble())
  if (type == "parquet") arrow::read_parquet(path) else readr::read_csv(path, show_col_types = FALSE)
}

load_report_data <- function() {
  list(
    bins = read_processed_or_empty("distribution-bins.parquet"),
    components = read_processed_or_empty("income-components.parquet"),
    metrics = read_processed_or_empty("distribution-metrics.parquet"),
    effective_tax = read_processed_or_empty("effective-tax.parquet"),
    decomposition = read_processed_or_empty("theil-decomposition-uf.parquet"),
    wealth = read_processed_or_empty("wealth-ranked-national.parquet"),
    wealth_metrics = read_processed_or_empty("wealth-metrics.parquet"),
    checks = read_processed_or_empty("quality-checks.csv", "csv")
  )
}

report_has_data <- function(data) {
  nrow(data$bins) > 0L && nrow(data$metrics) > 0L
}

data_unavailable_callout <- function() {
  cat("\n::: {.callout-warning}\n## Dados processados ainda não disponíveis\nExecute `run.cmd download`, `run.cmd context` e `run.cmd build`. A publicação externa permanece bloqueada enquanto o checklist não estiver concluído.\n:::\n")
}

latest_metrics_table <- function(metrics, ranking = "RB4") {
  if (nrow(metrics) == 0L) return(tibble::tibble())
  latest <- max(metrics$year, na.rm = TRUE)
  # Nomes por extenso: "AC" e "RO" não são leitura de público geral, e o
  # dicionário de geografias já traz o nome ao lado do código.
  nomes <- read_schema("geographies") |>
    dplyr::select("geo_code", "geo_name")
  metrics |>
    dplyr::filter(.data$year == latest, .data$ranking_id == .env$ranking, .data$geo_level == "state") |>
    dplyr::left_join(nomes, by = "geo_code") |>
    dplyr::mutate(geo_name = dplyr::coalesce(.data$geo_name, .data$geo_code)) |>
    dplyr::select(
      `Unidade da Federação` = "geo_name", Declarantes = "contributors",
      `Renda média (R$ de 2024)` = "income_mean_real", `Gini agrupado` = "gini_grouped",
      `Top 1%` = "top_1_share"
    ) |>
    dplyr::arrange(dplyr::desc(.data$`Gini agrupado`))
}

executive_findings <- function(metrics) {
  national <- metrics |>
    dplyr::filter(.data$geo_code == "BR", .data$ranking_id == "RB4") |>
    dplyr::arrange(.data$year)
  if (nrow(national) < 2L) return(character())
  first <- national[1, ]
  last <- national[nrow(national), ]
  # `sprintf("%.3f")` escreve "0.577" mesmo em texto em português; os números
  # passam pelos mesmos formatadores das tabelas. A comparação é feita sobre o
  # valor exibido: se os dois arredondam igual, a frase não pode dizer que mudou.
  trajetoria <- function(a, b, formatar) {
    de <- formatar(a)
    para <- formatar(b)
    if (identical(de, para)) return(paste("manteve-se em", de))
    paste(if (b > a) "aumentou" else "diminuiu", "de", de, "para", para)
  }
  c(
    sprintf("A participação do top 1%% %s entre %d e %d.", trajetoria(first$top_1_share, last$top_1_share, fmt_share), first$year, last$year),
    sprintf("O Gini agrupado da RB4 %s no período.", trajetoria(first$gini_grouped, last$gini_grouped, fmt_index)),
    sprintf("A medida de polarização de Wolfson %s.", trajetoria(first$wolfson_grouped, last$wolfson_grouped, fmt_index)),
    sprintf("Em %d, o top 0,1%% concentrou %s da RB4 declarada.", last$year, fmt_share(last$top_0_1_share)),
    "As diferenças estaduais são relativas às distribuições internas de cada UF; os limites monetários de um mesmo centil variam entre estados."
  )
}
