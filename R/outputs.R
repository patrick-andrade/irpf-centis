write_processed_outputs <- function(distribution_bins, income_components, metrics, effective_tax, wealth_bins, top_counts, theil_decomposition, quality_checks, hierarchy_reconciliation, wealth_ranked_national, wealth_metrics, coverage_context) {
  out <- project_path("data/processed")
  fs::dir_create(out, recurse = TRUE)
  paths <- c(
    distribution_bins = fs::path(out, "distribution-bins.parquet"),
    income_components = fs::path(out, "income-components.parquet"),
    metrics = fs::path(out, "distribution-metrics.parquet"),
    effective_tax = fs::path(out, "effective-tax.parquet"),
    wealth_bins = fs::path(out, "wealth-by-bin.parquet"),
    top_counts = fs::path(out, "top-group-counts.parquet"),
    theil_decomposition = fs::path(out, "theil-decomposition-uf.parquet"),
    quality_checks = fs::path(out, "quality-checks.csv"),
    hierarchy_reconciliation = fs::path(out, "hierarchy-reconciliation.csv"),
    wealth_ranked_national = fs::path(out, "wealth-ranked-national.parquet"),
    wealth_metrics = fs::path(out, "wealth-metrics.parquet"),
    coverage_context = fs::path(out, "coverage-context.csv")
  )
  arrow::write_parquet(distribution_bins, paths[["distribution_bins"]])
  arrow::write_parquet(income_components, paths[["income_components"]])
  arrow::write_parquet(metrics, paths[["metrics"]])
  arrow::write_parquet(effective_tax, paths[["effective_tax"]])
  arrow::write_parquet(wealth_bins, paths[["wealth_bins"]])
  arrow::write_parquet(top_counts, paths[["top_counts"]])
  arrow::write_parquet(theil_decomposition, paths[["theil_decomposition"]])
  readr::write_csv(quality_checks, paths[["quality_checks"]])
  readr::write_csv(hierarchy_reconciliation, paths[["hierarchy_reconciliation"]])
  arrow::write_parquet(wealth_ranked_national, paths[["wealth_ranked_national"]])
  arrow::write_parquet(wealth_metrics, paths[["wealth_metrics"]])
  readr::write_csv(coverage_context, paths[["coverage_context"]])
  unname(paths)
}

write_app_bundle <- function(income_components, metrics, effective_tax, wealth_bins, top_counts, theil_decomposition, wealth_ranked_national, wealth_metrics, state_polygons) {
  path <- project_path("app/data/app-bundle.rds")
  fs::dir_create(fs::path_dir(path), recurse = TRUE)
  bundle <- list(
    metadata = list(
      created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
      price_base_year = 2024,
      grouped_estimates = TRUE
    ),
    income_components = income_components |>
      dplyr::filter(
        .data$ranking_id == "RB4",
        .data$bin_code %in% c(1:99, 101:109, 111:120)
      ) |>
      dplyr::group_by(
        .data$year, .data$geo_level, .data$geo_code, .data$ranking_id,
        .data$component_id, .data$component_group, .data$field_label, .data$unit
      ) |>
      dplyr::summarise(
        value_nominal = sum(.data$value_nominal, na.rm = TRUE),
        value_real = sum(.data$value_real, na.rm = TRUE),
        .groups = "drop"
      ),
    metrics = metrics,
    effective_tax = effective_tax |>
      dplyr::filter(.data$ranking_id == "RB4") |>
      dplyr::select(
        "year", "geo_level", "geo_code", "ranking_id", "bin_code",
        "share_lower", "share_upper", "contributors", "tax_due",
        "rank_sum", "effective_rate"
      ),
    # O painel roda no navegador e paga cada coluna em tempo de primeira carga.
    # Entram só as colunas que alguma aba desenha, mais `rank_sum_real`, que
    # deixa o leitor conferir a razão dívida/renda no CSV baixado. As quatro
    # famílias de bens ficam de fora porque a composição já vem agregada em
    # `income_components`, e `assets_total_real` só existe de 2022 em diante,
    # servindo à conferência do pipeline. A tabela completa continua em
    # `data/processed/wealth-by-bin.parquet`.
    wealth_by_bin = wealth_bins |>
      dplyr::transmute(
        year = as.integer(.data$year), .data$geo_code,
        bin_code = as.integer(.data$bin_code),
        .data$share_lower, .data$share_upper,
        contributors = as.integer(.data$contributors),
        .data$rank_sum_real, .data$assets_sum_real, .data$assets_share,
        .data$debts_real, .data$debt_share, .data$debt_income_ratio
      ),
    top_group_counts = top_counts,
    theil_decomposition = theil_decomposition,
    wealth_ranked_national = wealth_ranked_national,
    wealth_metrics = wealth_metrics,
    state_polygons = state_polygons,
    geographies = read_schema("geographies"),
    rankings = read_schema("rankings"),
    indicators = read_schema("indicators"),
    references = read_schema("references")
  )
  # gzip aumenta moderadamente o arquivo, mas reduz o tempo de primeira carga
  # em relação a xz e mantém o bundle portátil em hospedagem estática.
  saveRDS(bundle, path, compress = "gzip")
  path
}

# O painel roda isolado no navegador: `app/app.R` carrega apenas `app/R/*.R`, e
# o shinylive empacota só o diretório `app`. Por isso a camada de visualização
# precisa existir também lá dentro. A cópia é gerada, não editada à mão, e
# `test-viz-sync.R` falha se as duas divergirem.
sync_app_viz <- function(origem = "R/viz.R", destino = "app/R/viz.R") {
  fonte <- project_path(origem)
  alvo <- project_path(destino)
  conteudo <- readLines(fonte, encoding = "UTF-8", warn = FALSE)
  cabecalho <- c(
    "# GERADO AUTOMATICAMENTE — não edite este arquivo.",
    paste0("# Cópia de ", origem, ", sincronizada por sync_app_viz()."),
    ""
  )
  writeLines(c(cabecalho, conteudo), alvo, useBytes = TRUE)
  alvo
}

app_viz_em_sincronia <- function(origem = "R/viz.R", destino = "app/R/viz.R") {
  alvo <- project_path(destino)
  if (!fs::file_exists(alvo)) return(FALSE)
  atual <- readLines(alvo, encoding = "UTF-8", warn = FALSE)
  esperado <- readLines(project_path(origem), encoding = "UTF-8", warn = FALSE)
  identical(utils::tail(atual, length(esperado)), esperado)
}

check_release_checklist <- function(path = "internal/release-checklist.md") {
  # O checklist é documentação interna e não faz parte do repositório público
  # (ver internal/README.md); por isso a publicação só pode ser montada na
  # máquina de quem mantém o projeto.
  full <- project_path(path)
  if (!fs::file_exists(full)) {
    rlang::abort(paste0(
      "Publicação bloqueada: checklist não encontrado em ", path,
      ". Ele é documentação interna e não vem no clone público."
    ))
  }
  lines <- readLines(full, encoding = "UTF-8", warn = FALSE)
  pending <- grep("^- \\[ \\]", lines, value = TRUE)
  if (length(pending) > 0L) {
    rlang::abort(paste0(
      "Publicação bloqueada: ", length(pending),
      " itens pendentes em ", path, "."
    ))
  }
  invisible(TRUE)
}

create_release_bundle <- function() {
  check_release_checklist()
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  release_dir <- project_path("output", paste0("release-", stamp))
  fs::dir_create(release_dir, recurse = TRUE)
  required <- c(
    "README.md", "CHANGELOG.md", "CITATION.cff", "docs/methodology.md",
    "docs/limitations.md", "docs/data-dictionary.md"
  )
  purrr::walk(required, function(file) {
    destination <- fs::path(release_dir, file)
    fs::dir_create(fs::path_dir(destination), recurse = TRUE)
    fs::file_copy(project_path(file), destination, overwrite = TRUE)
  })
  if (fs::dir_exists(project_path("output/site"))) {
    fs::dir_copy(project_path("output/site"), fs::path(release_dir, "site"), overwrite = TRUE)
  }
  release_dir
}
