#!/usr/bin/env Rscript

options(encoding = "UTF-8", stringsAsFactors = FALSE)
source_files <- sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(source_files, source, encoding = "UTF-8"))

manifest <- read_source_manifest()
cases <- manifest |>
  dplyr::filter(
    .data$dataset_family == "receita_expanded",
    .data$extension == "xlsx",
    (.data$year == 2017L & .data$layout == "expanded_monolithic") |
      (.data$year == 2024L & .data$layout == "expanded_national")
  ) |>
  dplyr::arrange(.data$year)

if (nrow(cases) != 2L) rlang::abort("Casos esperados de 2017 e 2024 não encontrados no manifesto.")
summary <- purrr::map_dfr(seq_len(nrow(cases)), function(i) {
  parsed <- parse_receita_workbook(
    project_path(cases$local_path[[i]]), cases$year[[i]], cases$source_id[[i]]
  )
  parsed$distribution_bins |>
    dplyr::summarise(
      year = dplyr::first(.data$year),
      files = dplyr::n_distinct(.data$source_file),
      sheets = dplyr::n_distinct(.data$source_sheet),
      geographies = dplyr::n_distinct(.data$geo_code),
      rankings = dplyr::n_distinct(.data$ranking_id),
      records = dplyr::n()
    )
})

write_csv_atomic(summary, project_path("output/smoke-parse.csv"))
print(summary)
