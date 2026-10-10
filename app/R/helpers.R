load_app_bundle <- function(path) {
  if (file.exists(path)) return(readRDS(path))
  list(
    metadata = list(created_at = NA_character_, price_base_year = 2024, grouped_estimates = TRUE),
    income_components = tibble::tibble(),
    metrics = tibble::tibble(),
    effective_tax = tibble::tibble(),
    wealth_by_bin = tibble::tibble(),
    top_group_counts = tibble::tibble(),
    wealth_metrics = tibble::tibble(),
    metrics_sem_topo = tibble::tibble(),
    state_polygons = tibble::tibble(),
    state_labels = tibble::tibble(),
    geographies = tibble::tibble(),
    rankings = tibble::tibble(),
    indicators = tibble::tibble(),
    references = tibble::tibble()
  )
}

bundle_has_data <- function(bundle) {
  nrow(bundle$metrics) > 0L
}

component_totals <- function(data) {
  data |>
    dplyr::group_by(.data$component_id, .data$field_label) |>
    dplyr::summarise(
      value = if (all(is.na(.data$value_real))) NA_real_ else sum(.data$value_real, na.rm = TRUE),
      .groups = "drop"
    )
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

geografia_nome <- function(bundle, geo_code) {
  row <- bundle$geographies[bundle$geographies$geo_code == geo_code, , drop = FALSE]
  if (nrow(row) == 0L) geo_code else row$geo_name[[1]]
}

# "Brasil, São Paulo e Pernambuco": nomes por extenso, com "e" antes do último.
juntar_nomes <- function(bundle, codigos) {
  nomes <- vapply(codigos, function(codigo) geografia_nome(bundle, codigo), character(1), USE.NAMES = FALSE)
  if (length(nomes) <= 1L) return(paste(nomes, collapse = ""))
  paste(paste(utils::head(nomes, -1L), collapse = ", "), "e", utils::tail(nomes, 1L))
}

# Chave de ordenação sem acentos. Na colação C, que é a do R no navegador,
# "Paraíba" vem depois de "Paraná" e de "Pernambuco"; `iconv(..., "ASCII//TRANSLIT")`
# não é confiável no WebAssembly, `chartr()` é.
sem_acento <- function(x) {
  tolower(chartr(
    "áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ",
    "aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC",
    x
  ))
}

# Escolhas do seletor de geografia, iguais em todas as abas: Brasil primeiro,
# UFs pelo nome, Exterior por último. O `sort()` dos códigos punha "BR" entre BA
# e CE e deixava "EX" sem explicação.
escolhas_geografia <- function(bundle, codigos) {
  codigos <- unique(stats::na.omit(as.character(codigos)))
  if (length(codigos) == 0L) return(character())
  nomes <- vapply(codigos, function(codigo) geografia_nome(bundle, codigo), character(1))
  nivel <- ifelse(codigos == "BR", 0L, ifelse(codigos == "EX", 2L, 1L))
  ordem <- order(nivel, sem_acento(nomes))
  stats::setNames(codigos[ordem], unname(nomes[ordem]))
}

# Wolfson pode ficar instável quando a mediana é pequena; Palma, quando a
# participação da base é pequena. A interpretação entre UFs pede cautela.
metric_choices <- c(
  "Gini agrupado" = "gini_grouped",
  "Theil T agrupado" = "theil_t_grouped",
  "Atkinson (ε = 0,5)" = "atkinson_grouped",
  "Participação do top 1%" = "top_1_share",
  "Participação do top 0,1%" = "top_0_1_share",
  "Wolfson (instável em algumas UFs)" = "wolfson_grouped",
  "Palma (instável em algumas UFs)" = "palma"
)

# CSV da seleção atual, para abrir no Excel em português: ";" como separador,
# vírgula decimal e BOM UTF-8 — sem o BOM, o Excel lê "São Paulo" como
# "SÃ£o Paulo". Só base R: no navegador cada pacote pesa na primeira visita.
escrever_csv_ptbr <- function(dados, arquivo) {
  linhas <- utils::capture.output(
    utils::write.csv2(as.data.frame(dados), row.names = FALSE, na = "")
  )
  texto <- paste0(paste(enc2utf8(linhas), collapse = "\r\n"), "\r\n")
  con <- file(arquivo, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(c(as.raw(c(0xEF, 0xBB, 0xBF)), charToRaw(texto)), con)
  invisible(arquivo)
}

format_metric <- function(value, metric) {
  if (grepl("share$", metric)) {
    scales::percent(value, accuracy = 0.1, big.mark = ".", decimal.mark = ",")
  } else {
    scales::number(value, accuracy = 0.001, big.mark = ".", decimal.mark = ",")
  }
}
