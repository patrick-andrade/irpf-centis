#!/usr/bin/env Rscript

options(encoding = "UTF-8", stringsAsFactors = FALSE, scipen = 999)

args <- commandArgs(trailingOnly = TRUE)
source_files <- sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(source_files, source, encoding = "UTF-8"))
command <- if (length(args) > 0L) tolower(args[[1]]) else "help"
extra <- if (length(args) > 1L) args[-1] else character()

usage <- function() {
  cat(
    "Uso: run.cmd <comando> [argumentos]\n\n",
    "  discover             Descobre fontes oficiais e grava o inventário\n",
    "  download [ano]       Baixa fontes e atualiza o manifesto\n",
    "  context              Atualiza deflatores IPCA e malha estadual IBGE\n",
    "  build                Executa o pipeline targets\n",
    "  check                Executa testes e validações\n",
    "  render               Renderiza o site Quarto\n",
    "  site                 Renderiza o site e exporta o painel (shinylive)\n",
    "  app                  Inicia o painel Shiny\n",
    "  release              Monta pacote local após o checklist\n",
    sep = ""
  )
}

if (command == "discover") {
  discovered <- discover_all_sources(include_wealth = TRUE)
  write_csv_atomic(discovered, project_path("data/metadata/sources-discovered.csv"))
  cli::cli_alert_success("{nrow(discovered)} fontes descobertas.")
} else if (command == "download") {
  discovered <- read_discovered_sources()
  if (nrow(discovered) == 0L) {
    discovered <- discover_all_sources(include_wealth = TRUE)
    write_csv_atomic(discovered, project_path("data/metadata/sources-discovered.csv"))
  }
  years <- if (length(extra) > 0L) as.integer(extra) else NULL
  manifest <- download_sources(discovered, years = years)
  cli::cli_alert_success("Manifesto atualizado com {nrow(manifest)} fontes.")
} else if (command == "context") {
  annual <- fetch_ipca_annual()
  geometry <- fetch_ibge_state_geometry()
  cli::cli_alert_success("IPCA atualizado para {nrow(annual)} anos e malha estadual gravada em {geometry}.")
} else if (command == "build") {
  targets::tar_make(callr_function = NULL)
} else if (command == "check") {
  testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)
  if (requireNamespace("lintr", quietly = TRUE)) {
    invisible(lapply(c("R", "app/R"), lintr::lint_dir))
  }
} else if (command == "render") {
  quarto::quarto_render(".")
} else if (command == "site") {
  quarto::quarto_render(".")
  source("scripts/export-app.R")
  cli::cli_alert_success("Site completo em output/site (relatórios + painel).")
} else if (command == "app") {
  shiny::runApp("app", launch.browser = interactive())
} else if (command == "release") {
  path <- create_release_bundle()
  cli::cli_alert_success("Pacote de publicação montado em {path}.")
} else {
  usage()
  if (command != "help") quit(status = 2L)
}
