# Contrato de dados das páginas Explorar e das figuras dos relatórios. O
# JavaScript só filtra e desenha; o que é cálculo, julgamento ou texto com
# número é conferido aqui.

entradas_site_sinteticas <- function() {
  b <- fixture_sintetica()
  # A fixture vem agregada como no antigo painel; o pipeline entrega por grupo.
  componentes <- dplyr::bind_rows(
    dplyr::mutate(b$income_components, bin_code = 50L),
    dplyr::mutate(b$income_components, bin_code = 101L),
    # Grupo agregado (100) não pode ser somado de novo.
    dplyr::mutate(b$income_components, bin_code = 100L, value_real = 9e9)
  )
  # Campo sem valor divulgado em nenhum grupo: continua ausente, não zero.
  componentes$value_real[componentes$component_id == "tax_due" & componentes$geo_code == "SP"] <- NA_real_
  list(
    income_components = componentes,
    metrics = b$metrics,
    effective_tax = b$effective_tax,
    wealth_bins = b$wealth_by_bin,
    top_counts = b$top_group_counts,
    wealth_metrics = b$wealth_metrics,
    metrics_sem_topo = b$metrics_sem_topo,
    state_polygons = b$state_polygons,
    state_labels = b$state_labels
  )
}

gerar_site_sintetico <- function() {
  e <- entradas_site_sinteticas()
  destino <- withr::local_tempdir(.local_envir = parent.frame())
  caminhos <- write_site_data(
    e$income_components, e$metrics, e$effective_tax, e$wealth_bins, e$top_counts,
    e$wealth_metrics, e$metrics_sem_topo, e$state_polygons, e$state_labels,
    destino = destino
  )
  list(destino = destino, caminhos = caminhos)
}

ler_json <- function(...) jsonlite::read_json(file.path(...), simplifyVector = FALSE)

test_that("escreve todos os arquivos das páginas, com LF e sem carimbo de hora", {
  site <- gerar_site_sintetico()
  esperados <- c(
    "comum.json", "glossario.json", "evolucao.json", "topos.json", "estados.json",
    "ufs.geojson", "visao-geral.json", "patrimonio-direto.json",
    "rendimentos/BR.json", "rendimentos/SP.json", "patrimonio/BR.json", "patrimonio/SP.json",
    "csv/irpf-centis-indicadores.csv", "csv/irpf-centis-bens-e-dividas-por-grupo.csv",
    "csv/irpf-centis-contagens-do-topo.csv", "csv/irpf-centis-conceitos-e-indicadores.csv"
  )
  expect_true(all(file.exists(file.path(site$destino, esperados))))
  for (arquivo in file.path(site$destino, esperados)) {
    bytes <- readBin(arquivo, "raw", file.size(arquivo))
    expect_false(any(bytes == as.raw(0x0d)), label = paste("CR em", basename(arquivo)))
  }
  comum <- ler_json(site$destino, "comum.json")
  expect_equal(comum$schema_version, 1L)
  expect_null(comum$created_at)
})

test_that("tabelas saem colunares, sempre como listas, mesmo com um valor", {
  site <- gerar_site_sintetico()
  direto <- ler_json(site$destino, "patrimonio-direto.json")
  expect_type(direto$gini_direto$year, "list")
  # Uma coluna de um valor só não pode virar escalar.
  e <- entradas_site_sinteticas()
  e$wealth_metrics <- e$wealth_metrics[1, ]
  destino <- withr::local_tempdir()
  write_site_data(
    e$income_components, e$metrics, e$effective_tax, e$wealth_bins, e$top_counts,
    e$wealth_metrics, e$metrics_sem_topo, e$state_polygons, e$state_labels, destino = destino
  )
  um <- jsonlite::fromJSON(file.path(destino, "patrimonio-direto.json"), simplifyVector = FALSE)
  expect_length(um$gini_direto$year, 1L)
  expect_type(um$gini_direto$year, "list")
})

test_that("precisão: inteiros exatos, dinheiro ao real, proporções com seis casas", {
  expect_equal(arredondar_site(data.frame(year = 2024.0))$year, 2024L)
  expect_type(arredondar_site(data.frame(contributors = 41676499))$contributors, "integer")
  expect_equal(arredondar_site(data.frame(value_real = 1234.56))$value_real, 1235)
  expect_equal(arredondar_site(data.frame(top_1_share = 0.25123456789))$top_1_share, 0.251235)
  expect_true(is.na(arredondar_site(data.frame(palma = Inf))$palma))
  expect_true(is.na(arredondar_site(data.frame(palma = NaN))$palma))
})

test_that("ausência não vira zero e agregados não são somados de novo", {
  site <- gerar_site_sintetico()
  sp <- jsonlite::fromJSON(file.path(site$destino, "rendimentos", "SP.json"))
  comp <- as.data.frame(sp$componentes)
  expect_true(all(is.na(comp$value_real[comp$component_id == "tax_due"])))
  br <- as.data.frame(jsonlite::fromJSON(file.path(site$destino, "rendimentos", "BR.json"))$componentes)
  # Grupos 50 e 101 somam 2,2 milhões; o agregado 100 (9 bilhões) fica fora.
  expect_equal(unique(br$value_real[br$component_id == "other_taxable"]), 2.2e6)
  # Bens vão para o arquivo de patrimônio, não para o de rendimentos.
  expect_false("assets_real_estate" %in% br$component_id)
})

test_that("soma por campo preserva ausência integral sem perder valores conhecidos", {
  expect_true(is.na(sum_known_values(c(NA_real_, NA_real_))))
  expect_equal(sum_known_values(c(2, NA_real_, 3)), 5)
  expect_equal(sum_known_values(c(0, NA_real_)), 0)
  componentes <- tibble::tibble(
    component_id = c("ausente", "ausente", "parcial", "parcial", "zero"),
    field_label = c("Ausente", "Ausente", "Parcial", "Parcial", "Zero"),
    value_real = c(NA_real_, NA_real_, 2, NA_real_, 0)
  )
  totais <- component_totals(componentes)
  expect_true(is.na(totais$value[totais$component_id == "ausente"]))
  expect_equal(totais$value[totais$component_id == "parcial"], 2)
  expect_equal(totais$value[totais$component_id == "zero"], 0)
})

test_that("médias por declaração só onde há declarações", {
  site <- gerar_site_sintetico()
  g <- as.data.frame(jsonlite::fromJSON(file.path(site$destino, "patrimonio", "BR.json"))$grupos)
  expect_equal(g$patrimonio_medio, round(g$assets_sum_real / g$contributors))
  # Renda nula no primeiro centil: razão dívida/renda ausente, não zero.
  expect_true(is.na(g$debt_income_ratio[g$bin_code == 1L][1]))
})

test_that("salto de 2018 é identificado por geografia", {
  metrics <- data.frame(
    year = rep(2017:2019, 2), geo_code = rep(c("PE", "RS"), each = 3), ranking_id = "RB4",
    gini_grouped = c(0.563, 0.865, 0.562, 0.55, 0.552, 0.551)
  )
  expect_equal(geografias_salto_2018(metrics, "RB4", "gini_grouped"), "PE")
  expect_equal(geografias_salto_2018(metrics, "RB4", "gini_grouped", geos = "RS"), character())
  expect_equal(geografias_salto_2018(metrics, "RB4", "nao_existe"), character())
  saltos <- saltos_2018_por_conceito(metrics, c("gini_grouped", "palma"))
  expect_equal(as.character(saltos$RB4$gini_grouped), "PE")
  # Lista vazia continua lista no JSON (o JavaScript faz `includes`).
  expect_match(jsonlite::toJSON(saltos, auto_unbox = TRUE), '"palma":[]', fixed = TRUE)
})

test_that("geografias: Brasil primeiro, UFs pelo nome sem acento, Exterior por último", {
  g <- ordenar_geografias(read_schema("geographies"), c("PR", "EX", "PB", "BR", "PA", "AC"))
  expect_equal(g$geo_code, c("BR", "AC", "PA", "PB", "PR", "EX"))
  expect_equal(g$geo_name, c("Brasil", "Acre", "Pará", "Paraíba", "Paraná", "Exterior"))
})

test_that("malha: anel exterior em sentido horário para o d3", {
  # O quadrado da fixture vem em sentido anti-horário (área positiva).
  quadrado <- tibble::tibble(codarea = "35", piece = "1-1-1", long = c(0, 1, 1, 0, 0), lat = c(0, 0, 1, 1, 0))
  expect_gt(area_assinada(quadrado$long, quadrado$lat), 0)
  malha <- malha_ufs_geojson(quadrado, read_schema("geographies"))
  anel <- malha$features[[1]]$geometry$coordinates[[1]][[1]]
  expect_lt(area_assinada(anel[, 1], anel[, 2]), 0)
  expect_equal(malha$features[[1]]$properties$uf, "SP")
})

test_that("visão geral: cartões redigidos e variação com ressalva de 2018", {
  site <- gerar_site_sintetico()
  v <- ler_json(site$destino, "visao-geral.json")
  expect_equal(v$ano, 2024L)
  chaves <- vapply(v$perguntas, `[[`, character(1), "chave")
  expect_true(all(c("topos", "evolucao", "rendimentos", "estados", "bens") %in% chaves))
  expect_match(v$perguntas[[which(chaves == "topos")]]$resposta, "20,0%", fixed = TRUE)
  expect_match(v$perguntas[[which(chaves == "estados")]]$resposta, "Rio de Janeiro", fixed = TRUE)
  expect_equal(texto_variacao(0.25, 0.27, function(x) fmt_index(100 * x, 0.1), "p.p.", 2024), "−2,0 p.p. ante 2023")
  expect_equal(texto_variacao(0.6, 0.55, function(x) fmt_index(x, 0.001), "ponto", 2019), "+0,050 ponto ante 2018 (2018 não comparável)")
  expect_true(is.na(texto_variacao(0.6, NA, identity, "ponto", 2024)))
})

test_that("seletor de indicadores sai do contrato, na ordem do painel", {
  seletor <- indicadores_do_seletor()
  expect_equal(seletor$id, c(
    "gini_grouped", "theil_t_grouped", "atkinson_grouped", "top_1_share",
    "top_0_1_share", "wolfson_grouped", "palma"
  ))
  expect_true(all(nzchar(seletor$rotulo)))
})

test_that("figuras: alíquota por grupo agregado, Brasil, RB4", {
  e <- entradas_site_sinteticas()
  destino <- withr::local_tempdir()
  caminho <- write_report_figure_data(e$effective_tax, destino = destino)
  r <- jsonlite::fromJSON(caminho)
  expect_setequal(unique(r$aliquota_grupos$group), c("all", "top_10", "top_1", "top_0_1"))
})

test_that("fixtures de formatação compartilhadas com o JavaScript estão em dia", {
  versionado <- jsonlite::read_json(
    file.path(test_project_root, "tests", "fixtures", "formatos-ptbr.json"), simplifyVector = TRUE
  )
  atual <- jsonlite::fromJSON(jsonlite::toJSON(fixtures_formatos(), digits = NA), simplifyVector = TRUE)
  expect_equal(versionado, atual)
})

# Os arquivos publicados (gerados pelo pipeline e versionados): orçamento de
# bytes por página e malha na orientação certa.
dados_publicados <- file.path(test_project_root, "explorar", "dados")

test_that("dados publicados cabem no orçamento de cada página", {
  skip_if_not(file.exists(file.path(dados_publicados, "evolucao.json")), "dados do site não gerados")
  gzip_kb <- function(caminho) {
    length(memCompress(readBin(caminho, "raw", file.size(caminho)), "gzip")) / 1024
  }
  for (arquivo in c("evolucao.json", "topos.json", "estados.json", "ufs.geojson", "comum.json", "glossario.json")) {
    expect_lte(gzip_kb(file.path(dados_publicados, arquivo)), 200, label = arquivo)
  }
  for (pasta in c("rendimentos", "patrimonio")) {
    maior <- max(vapply(list.files(file.path(dados_publicados, pasta), full.names = TRUE), gzip_kb, numeric(1)))
    expect_lte(maior, 100, label = pasta)
  }
})

test_that("malha publicada tem todos os exteriores em sentido horário", {
  skip_if_not(file.exists(file.path(dados_publicados, "ufs.geojson")), "dados do site não gerados")
  malha <- jsonlite::read_json(file.path(dados_publicados, "ufs.geojson"), simplifyVector = FALSE)
  expect_length(malha$features, 27L)
  for (f in malha$features) {
    for (poligono in f$geometry$coordinates) {
      exterior <- do.call(rbind, lapply(poligono[[1]], unlist))
      expect_lt(area_assinada(exterior[, 1], exterior[, 2]), 0)
    }
  }
})
