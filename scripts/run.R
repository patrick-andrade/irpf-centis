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
    "  build                Executa o pipeline targets (inclui os dados do site)\n",
    "  check                Executa os testes R e, com Node, os testes JS\n",
    "  render               Gera bundle JS e figuras (Node) e renderiza o site\n",
    "  release              Monta o pacote local de publicação\n",
    sep = ""
  )
}

# A camada visual (páginas Explorar e figuras dos relatórios) é JavaScript,
# rodado pelo Node. Sem Node instalado, os passos dele são pulados com aviso:
# o bundle e as figuras versionados continuam valendo.
rodar_npm <- function(...) {
  npm <- Sys.which(if (.Platform$OS.type == "windows") "npm.cmd" else "npm")
  if (!nzchar(npm)) {
    cli::cli_alert_warning("Node/npm não encontrado: pulando npm {paste(c(...), collapse = ' ')}.")
    return(invisible(FALSE))
  }
  # No CI, os testes JS rodam no job próprio (`js`), que instala as
  # dependências; aqui, sem `npm ci`, não há o que rodar.
  if (!dir.exists(project_path("node_modules"))) {
    cli::cli_alert_warning("node_modules ausente (rode npm ci): pulando npm {paste(c(...), collapse = ' ')}.")
    return(invisible(FALSE))
  }
  status <- system2(npm, c(...))
  if (!identical(status, 0L)) stop("npm ", paste(c(...), collapse = " "), " falhou.", call. = FALSE)
  invisible(TRUE)
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
    lint_counts <- vapply(
      "R",
      function(directory) length(lintr::lint_dir(directory)),
      integer(1)
    )
    cat(
      "Lint informativo (não bloqueante): ",
      paste(names(lint_counts), lint_counts, sep = "=", collapse = "; "),
      " apontamentos.\n", sep = ""
    )
  } else {
    cat("Lint não verificado: pacote lintr indisponível.\n")
  }
  rodar_npm("test")
} else if (command == "render") {
  rodar_npm("run", "build")
  rodar_npm("run", "figuras")
  quarto::quarto_render(".")
  cli::cli_alert_success("Site em output/site. Para ver: node scripts/servir.mjs output/site")
} else if (command == "release") {
  path <- create_release_bundle()
  cli::cli_alert_success("Pacote de publicação montado em {path}.")
} else {
  usage()
  if (command != "help") quit(status = 2L)
}
