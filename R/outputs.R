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

sum_known_values <- function(x) {
  if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE)
}

check_release_checklist <- function(path = "internal/release-checklist.md") {
  # O checklist é versionado no repositório privado, fora do Git público.
  full <- project_path(path)
  if (!fs::file_exists(full)) {
    rlang::abort(paste0(
      "Publicação bloqueada: checklist não encontrado em ", path, "."
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
