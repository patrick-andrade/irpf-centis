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

write_app_bundle <- function(income_components, metrics, effective_tax, wealth_bins, top_counts, wealth_metrics, state_polygons, metrics_sem_topo, state_labels) {
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
        value_nominal = sum_known_values(.data$value_nominal),
        value_real = sum_known_values(.data$value_real),
        .groups = "drop"
      ),
    metrics = metrics,
    # Só o que a curva de alíquota desenha; imposto e renda por grupo seguem
    # em `data/processed/effective-tax.parquet`.
    effective_tax = effective_tax |>
      dplyr::filter(.data$ranking_id == "RB4") |>
      dplyr::select("year", "geo_code", "bin_code", "share_upper", "effective_rate"),
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
    # A decomposição de Theil e a série patrimonial bruta não eram lidas por
    # nenhuma aba e somavam ~450 KB à primeira carga; a série patrimonial entra
    # já resumida em `wealth_metrics`.
    wealth_metrics = wealth_metrics,
    # Variante sem o grupo 120 (top 0,01%), só com os indicadores que a aba
    # Evolução oferece: é a série que a ressalva de 2018 manda comparar.
    metrics_sem_topo = metrics_sem_topo |>
      dplyr::select(
        "year", "geo_code", "ranking_id", "gini_grouped", "gini_lower_bound",
        "gini_upper_bound", "theil_t_grouped", "atkinson_grouped", "top_10_share",
        "top_1_share", "top_0_1_share", "wolfson_grouped", "palma"
      ),
    state_polygons = state_polygons,
    state_labels = state_labels,
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

# Página que abre o painel exportado pelo shinylive. O modelo padrão é genérico
# e em inglês — <html lang="en">, título "Shiny app" — e deixa o leitor de 30 a
# 40 segundos diante de um ícone girando enquanto o R é baixado. Os trechos
# abaixo entram pelo `template_params` de shinylive::export(); o idioma não tem
# parâmetro e é trocado por ajustar_index_painel().
#
# Só base R aqui e nas duas funções seguintes: o job de publicação chama
# scripts/export-app.R sem instalar as dependências do pipeline.
parametros_index_painel <- function(site_url = "https://patrick-andrade.github.io/irpf-centis") {
  descricao <- paste(
    "Painel interativo da distribuição de renda, imposto e patrimônio entre",
    "declarações do IRPF, por centil, ano e unidade da Federação."
  )
  list(
    title = "Painel interativo — IRPF por centis",
    include_in_head = paste(
      sprintf('<meta name="description" content="%s">', descricao),
      '<meta property="og:title" content="Painel interativo — IRPF por centis">',
      sprintf('<meta property="og:description" content="%s">', descricao),
      sprintf('<meta property="og:url" content="%s/app/">', site_url),
      "<style>",
      ".carregando-painel { position: fixed; left: 50%; top: calc(50% + 70px);",
      "  transform: translateX(-50%); width: min(34rem, calc(100vw - 2rem));",
      "  z-index: 10; text-align: center; color: #101d40; line-height: 1.5;",
      "  font-family: 'Segoe UI', Arial, sans-serif; font-size: .95rem; }",
      ".carregando-painel strong { display: block; font-size: 1.05rem; margin-bottom: .3rem; }",
      ".carregando-painel p { color: #586179; margin: 0 0 .5rem; }",
      ".carregando-painel a { color: #0757cf; }",
      "</style>",
      sep = "\n"
    ),
    include_before_body = paste0(
      '<div id="carregando-painel" class="carregando-painel" role="status" aria-live="polite">',
      "<strong>Carregando o painel…</strong>",
      "<p>O R roda aqui no seu navegador, sem servidor. Na primeira visita o ",
      "navegador baixa o ambiente de análise, o que leva de 30 a 40 segundos; ",
      "nas seguintes, é mais rápido.</p>",
      sprintf('<p><a href="%s/reports/executive-summary.html">', site_url),
      "Enquanto isso, leia o sumário executivo</a></p>",
      "</div>"
    ),
    # O aviso sai quando o iframe do app termina de carregar a interface, e não
    # no primeiro iframe criado: o shinylive cria o iframe vazio antes de o R
    # estar pronto. O prazo final evita que o aviso cubra uma mensagem de erro.
    include_after_body = paste(
      "<script>",
      "(function () {",
      "  var aviso = document.getElementById('carregando-painel');",
      "  var raiz = document.getElementById('root');",
      "  if (!aviso || !raiz) return;",
      "  function remover() { if (aviso.parentNode) aviso.parentNode.removeChild(aviso); }",
      "  new MutationObserver(function () {",
      "    var iframe = raiz.querySelector('iframe');",
      "    if (!iframe || iframe.dataset.vigiado) return;",
      "    iframe.dataset.vigiado = '1';",
      "    iframe.addEventListener('load', function () {",
      "      if (iframe.getAttribute('src')) remover();",
      "    });",
      "  }).observe(raiz, { childList: true, subtree: true });",
      "  setTimeout(remover, 120000);",
      "})();",
      "</script>",
      sep = "\n"
    )
  )
}

ajustar_index_painel <- function(caminho) {
  html <- readLines(caminho, encoding = "UTF-8", warn = FALSE)
  alvo <- grep('<html lang="en">', html, fixed = TRUE)
  if (length(alvo) != 1L) {
    stop(
      "O modelo do shinylive mudou: <html lang=\"en\"> não encontrado em ",
      caminho, ". Revise ajustar_index_painel().",
      call. = FALSE
    )
  }
  html[alvo] <- sub('<html lang="en">', '<html lang="pt-BR">', html[alvo], fixed = TRUE)
  writeLines(enc2utf8(html), caminho, useBytes = TRUE)
  invisible(caminho)
}

# O shinylive só empacota no site os pacotes instalados na máquina que exporta;
# os que faltam ele baixa do repositório wasm em tempo de execução, sem versão
# fixa. Foi o que aconteceu no deploy até 2026-09: só tibble e dependências
# iam no site. Falhar aqui é melhor que publicar um painel que depende disso.
conferir_pacotes_painel <- function(destino,
                                    pacotes = c("ggplot2", "dplyr", "scales", "bsicons", "viridisLite")) {
  pasta <- file.path(destino, "shinylive", "webr", "packages")
  faltando <- pacotes[!dir.exists(file.path(pasta, pacotes))]
  if (length(faltando) > 0L) {
    stop(
      "Pacotes do painel ausentes do export em ", pasta, ": ",
      paste(faltando, collapse = ", "),
      ". Instale-os antes de rodar shinylive::export().",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

# O shinylive não exporta os pacotes instalados: baixa os binários WebAssembly
# na versão que o repositório do webR servir no dia e só avisa quando ela
# diverge da instalada. Fixar as versões no runner, portanto, não fixa o que vai
# ao site. Esta conferência compara o que foi exportado com o renv.lock, que é o
# que o CI testou, e recusa divergência de versão maior ou menor; a tabela das
# versões publicadas fica no próprio site. jsonlite vem com o shiny.
conferir_versoes_painel <- function(destino, lockfile = "renv.lock") {
  pasta <- file.path(destino, "shinylive", "webr", "packages")
  metadados <- readRDS(file.path(pasta, "metadata.rds"))
  testadas <- jsonlite::read_json(lockfile)$Packages
  versoes <- do.call(rbind, lapply(names(metadados), function(pacote) {
    data.frame(
      pacote = pacote,
      exportada = as.character(metadados[[pacote]]$version %||% NA_character_),
      testada = as.character(testadas[[pacote]]$Version %||% NA_character_)
    )
  }))
  # Pacotes da base do R (grid, stats, utils) não constam do lockfile.
  comparaveis <- versoes[!is.na(versoes$exportada) & !is.na(versoes$testada), , drop = FALSE]
  maior_menor <- function(v) {
    vapply(v, function(x) paste(unlist(package_version(x))[1:2], collapse = "."), character(1))
  }
  divergentes <- comparaveis[maior_menor(comparaveis$exportada) != maior_menor(comparaveis$testada), , drop = FALSE]
  utils::write.csv(versoes, file.path(destino, "versoes-pacotes.csv"), row.names = FALSE)
  if (nrow(divergentes) > 0L) {
    stop(
      "Versões WebAssembly diferentes das testadas no CI: ",
      paste0(divergentes$pacote, " ", divergentes$exportada, " (renv.lock: ", divergentes$testada, ")", collapse = "; "),
      ". Atualize o renv.lock e rode os testes antes de publicar.",
      call. = FALSE
    )
  }
  invisible(versoes)
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
