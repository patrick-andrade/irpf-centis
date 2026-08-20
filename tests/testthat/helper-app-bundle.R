# Bundle sintético mínimo com o contrato atual do painel, para testes de
# módulo via shiny::testServer sem depender do pipeline.
synthetic_app_bundle <- function() {
  metrics <- tidyr::expand_grid(
    year = 2023:2024,
    geo_code = c("BR", "SP", "RJ")
  ) |>
    dplyr::mutate(
      geo_level = ifelse(.data$geo_code == "BR", "national", "state"),
      ranking_id = "RB4",
      contributors = 1000 + 10 * .data$year %% 100,
      income_mean = 50000,
      income_mean_real = 52000,
      gini_grouped = 0.55 + 0.01 * (.data$geo_code == "SP"),
      gini_lower_bound = 0.55,
      gini_upper_bound = 0.6,
      theil_t_grouped = 0.6,
      atkinson_grouped = 0.25,
      wolfson_grouped = 0.4,
      top_10_share = 0.5,
      top_1_share = 0.2,
      top_0_1_share = 0.1,
      top_0_01_share = 0.05,
      palma = 3.2
    )

  income_components <- tidyr::expand_grid(
    year = 2023:2024,
    geo_code = c("BR", "SP"),
    component = c("other_taxable", "tax_due", "assets_real_estate", "debts")
  ) |>
    dplyr::mutate(
      geo_level = ifelse(.data$geo_code == "BR", "national", "state"),
      ranking_id = "RB4",
      component_id = .data$component,
      component_group = dplyr::case_when(
        .data$component == "other_taxable" ~ "taxable",
        .data$component == "tax_due" ~ "tax",
        .data$component == "assets_real_estate" ~ "asset",
        .data$component == "debts" ~ "liability"
      ),
      field_label = .data$component,
      unit = "BRL",
      value_nominal = 1e6,
      value_real = 1.1e6
    ) |>
    dplyr::select(-"component")

  # Inclui os grupos disjuntos do topo (99, 101-109, 111-120) além dos centis
  # baixos: sem eles o painel de detalhe do topo não teria o que desenhar, e é
  # justamente ali que está a queda da alíquota que o estudo quer comunicar.
  codigos_fixture <- c(1L, 50L, 90L, 95L, 99L, 101:109, 111:120)
  limites <- purrr::map_dfr(codigos_fixture, bin_attributes)
  effective_tax <- tidyr::expand_grid(
    year = 2023:2024,
    geo_code = c("BR", "SP"),
    bin_code = codigos_fixture
  ) |>
    dplyr::left_join(
      dplyr::mutate(limites, bin_code = codigos_fixture) |>
        dplyr::select("bin_code", "share_lower", "share_upper"),
      by = "bin_code"
    ) |>
    dplyr::mutate(
      geo_level = ifelse(.data$geo_code == "BR", "national", "state"),
      ranking_id = "RB4",
      contributors = 100,
      rank_sum = 100 * .data$bin_code,
      # Alíquota sobe até o percentil 99 e cai no topo, como na série real.
      effective_rate = ifelse(
        .data$bin_code <= 99L,
        0.10 * .data$share_upper,
        0.10 * (1 - (.data$bin_code - 99L) / 25)
      ),
      tax_due = .data$effective_rate * .data$rank_sum
    )

  square <- function(codarea, offset) {
    tibble::tibble(
      codarea = codarea,
      piece = paste0(codarea, "-1-1"),
      long = c(0, 1, 1, 0) + offset,
      lat = c(0, 0, 1, 1)
    )
  }

  list(
    metadata = list(created_at = "fixture", price_base_year = 2024, grouped_estimates = TRUE),
    income_components = income_components,
    metrics = metrics,
    effective_tax = effective_tax,
    theil_decomposition = tibble::tibble(),
    wealth_ranked_national = tibble::tibble(),
    wealth_metrics = tibble::tibble(
      year = 2006:2008, geo_code = "BR", ranking_id = "WEALTH_DIRECT",
      gini_grouped = c(0.8, 0.81, 0.82)
    ),
    state_polygons = dplyr::bind_rows(square("35", 0), square("33", 2)),
    geographies = tibble::tibble(
      geo_level = c("national", "state", "state"),
      geo_code = c("BR", "SP", "RJ"),
      geo_name = c("Brasil", "São Paulo", "Rio de Janeiro"),
      ibge_code = c(NA_integer_, 35L, 33L)
    ),
    rankings = tibble::tibble(
      ranking_id = "RB4", roman = "IV", label = "Rendimento bruto 4"
    )
  )
}

load_app_module_env <- function(root = test_project_root) {
  env <- new.env(parent = globalenv())
  files <- sort(list.files(file.path(root, "app", "R"), pattern = "\\.R$", full.names = TRUE))
  invisible(lapply(files, source, local = env, encoding = "UTF-8"))
  env
}
