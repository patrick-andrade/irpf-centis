load_app_bundle <- function(path) {
  if (file.exists(path)) return(readRDS(path))
  list(
    metadata = list(created_at = NA_character_, price_base_year = 2024, grouped_estimates = TRUE),
    income_components = tibble::tibble(),
    metrics = tibble::tibble(),
    effective_tax = tibble::tibble(),
    theil_decomposition = tibble::tibble(),
    wealth_ranked_national = tibble::tibble(),
    wealth_metrics = tibble::tibble(),
    state_polygons = tibble::tibble(),
    geographies = tibble::tibble(),
    rankings = tibble::tibble()
  )
}

bundle_has_data <- function(bundle) {
  nrow(bundle$metrics) > 0L
}

data_missing_ui <- function() {
  bslib::card(
    class = "missing-data-card",
    bslib::card_header("Dados processados não disponíveis"),
    shiny::p("Execute run.cmd download, run.cmd context e run.cmd build."),
    shiny::p("O painel não usa dados demonstrativos no modo de publicação.")
  )
}

leaf_codes <- c(1:99, 101:109, 111:120)

ranking_label <- function(bundle, ranking_id) {
  row <- bundle$rankings[bundle$rankings$ranking_id == ranking_id, , drop = FALSE]
  if (nrow(row) == 0L) ranking_id else row$label[[1]]
}

# Wolfson e Palma não são limitados por construção e explodem quando a mediana
# do grupo tende a zero — chegam a 4,5 e a 25 em algumas UFs, o que é artefato
# de fórmula e não desigualdade. Ficam disponíveis, mas rotulados, para que o
# leitor não os compare entre UFs como se fossem medidas estáveis.
metric_choices <- c(
  "Gini agrupado" = "gini_grouped",
  "Theil T agrupado" = "theil_t_grouped",
  "Atkinson (ε = 0,5)" = "atkinson_grouped",
  "Participação do top 1%" = "top_1_share",
  "Participação do top 0,1%" = "top_0_1_share",
  "Wolfson (instável em algumas UFs)" = "wolfson_grouped",
  "Palma (instável em algumas UFs)" = "palma"
)

format_metric <- function(value, metric) {
  if (grepl("share$", metric)) {
    scales::percent(value, accuracy = 0.1, big.mark = ".", decimal.mark = ",")
  } else {
    scales::number(value, accuracy = 0.001, big.mark = ".", decimal.mark = ",")
  }
}
