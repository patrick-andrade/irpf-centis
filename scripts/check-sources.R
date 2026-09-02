#!/usr/bin/env Rscript

# Monitor de páginas oficiais: só precisa de acquisition + utils.
# Carregar o restante de R/ puxaria sf/arrow/targets e o renv completo.
options(encoding = "UTF-8", stringsAsFactors = FALSE)
invisible(lapply(c("R/utils.R", "R/acquisition.R"), source, encoding = "UTF-8"))

current <- discover_all_sources(include_wealth = TRUE)
baseline <- read_discovered_sources()
out <- project_path("output/source-monitor")
fs::dir_create(out, recurse = TRUE)
write_csv_atomic(current, fs::path(out, "sources-current.csv"))

changes <- diff_discovered_sources(current, baseline)
write_csv_atomic(changes, fs::path(out, "changes.csv"))

if (nrow(changes) > 0L) {
  message(nrow(changes), " alteração(ões) detectada(s); revisão humana obrigatória.")
  quit(status = 3L)
}
message("Nenhuma alteração detectada.")
