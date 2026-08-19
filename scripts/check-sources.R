#!/usr/bin/env Rscript

options(encoding = "UTF-8", stringsAsFactors = FALSE)
source_files <- sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(source_files, source, encoding = "UTF-8"))

current <- discover_all_sources(include_wealth = TRUE)
baseline <- read_discovered_sources()
out <- project_path("output/source-monitor")
fs::dir_create(out, recurse = TRUE)
write_csv_atomic(current, fs::path(out, "sources-current.csv"))

key <- c("dataset_family", "year", "download_url")
changes <- dplyr::full_join(
  dplyr::mutate(current, current = TRUE),
  dplyr::mutate(baseline, baseline = TRUE),
  by = key,
  suffix = c("_current", "_baseline")
) |>
  dplyr::filter(is.na(.data$current) | is.na(.data$baseline))
write_csv_atomic(changes, fs::path(out, "changes.csv"))

if (nrow(changes) > 0L) {
  message(nrow(changes), " alteração(ões) detectada(s); revisão humana obrigatória.")
  quit(status = 3L)
}
message("Nenhuma alteração detectada.")
