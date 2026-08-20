expected_layouts <- yaml::read_yaml(
  file.path(test_project_root, "tests", "fixtures", "layouts.yml")
)$layouts

test_that("resolve_field_ids mapeia por regex, marca não mapeados e desduplica", {
  headers <- c(
    "Centil", "Quantidade de Contribuintes", "Coluna Misteriosa",
    "Imposto Devido", "Imposto Devido"
  )
  ids <- resolve_field_ids(headers)
  expect_equal(ids, c("centile", "contributors", "unmapped_3", "tax_due", "tax_due__duplicate_1"))
})

test_that("parser lê o layout dividido (2022-2024) com códigos diretos", {
  skip_if_not_installed("writexl")
  path <- write_fixture_workbook("split", sheet = "BRV")
  parsed <- read_receita_sheet(path, "BRV", 2024L, "fixture-split")
  bins <- parsed$distribution_bins
  expect_equal(nrow(bins), expected_layouts$expanded_split_2024$bins_per_sheet)
  expect_equal(nrow(leaf_distribution(bins)), expected_layouts$analytical_leaf_view$bins_per_distribution)
  expect_equal(unique(bins$geo_code), "BR")
  expect_equal(unique(bins$ranking_id), "RB4")
  expect_equal(unique(bins$year), 2024L)
  expect_setequal(bins$bin_code, 1:120)
  reference <- fixture_bin_values()
  expect_equal(
    bins$rank_sum[order(bins$bin_code)],
    reference$rank_sum[order(reference$code)]
  )
  components <- parsed$income_components
  expect_setequal(unique(components$component_id), c("tax_due", "dividends"))
  expect_equal(nrow(components), 2L * 120L)
  expect_equal(
    unique(components$component_group[components$component_id == "tax_due"]),
    "tax"
  )
})

test_that("parser lê o layout monolítico (2017-2021) com hierarquia em três colunas", {
  skip_if_not_installed("writexl")
  path <- write_fixture_workbook("monolithic", sheet = "SPV")
  parsed <- read_receita_sheet(path, "SPV", 2017L, "fixture-monolithic")
  bins <- parsed$distribution_bins
  expect_equal(nrow(bins), expected_layouts$expanded_monolithic_2017$bins_per_sheet)
  expect_setequal(bins$bin_code, 1:120)
  expect_equal(unique(bins$geo_code), "SP")
  expect_equal(unique(bins$geo_level), "state")
  reference <- fixture_bin_values()
  expect_equal(
    bins$contributors[order(bins$bin_code)],
    reference$contributors[order(reference$code)]
  )
  checks <- run_quality_checks(bins)
  expect_equal(checks$status[checks$check == "hierarchical_contributors"], "pass")
  expect_equal(checks$status[checks$check == "hierarchical_amounts"], "pass")
  expect_equal(checks$status[checks$check == "leaf_bin_count"], "pass")
})

test_that("workbook ignora abas não distributivas e aborta sem nenhuma aba válida", {
  skip_if_not_installed("writexl")
  junk <- data.frame(c1 = c("Notas metodológicas", "Sem dados"), stringsAsFactors = FALSE)
  path <- write_fixture_workbook("split", sheet = "BRV", extra_sheets = list(Capa = junk))
  parsed <- parse_receita_workbook(path, 2024L, "fixture-split")
  expect_equal(nrow(parsed$distribution_bins), 120L)
  only_junk <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(list(Capa = junk), only_junk, col_names = FALSE)
  expect_error(parse_receita_workbook(only_junk, 2024L, "x"), "Nenhuma aba distributiva")
})

test_that("detect_phantom_header só acusa rótulo órfão com duplicata vizinha", {
  headers <- c("Centil", "Soma", "Soma", "Imposto Devido", "Bens")
  # Última coluna sem dados e uma duplicata vizinha: assinatura de 2017-2021.
  expect_equal(
    detect_phantom_header(headers, c(TRUE, TRUE, TRUE, TRUE, FALSE)),
    3L
  )
  # Todas as colunas com dados: layout limpo, nada a realinhar.
  expect_true(is.na(detect_phantom_header(headers, rep(TRUE, 5))))
  # Órfã sem duplicata: ambíguo, não se mexe.
  expect_true(is.na(detect_phantom_header(
    c("Centil", "Soma", "Imposto Devido", "Bens"), c(TRUE, TRUE, TRUE, FALSE)
  )))
})

test_that("parser realinha o cabeçalho fantasma de 2017-2021", {
  skip_if_not_installed("writexl")
  path <- write_phantom_fixture_workbook("BRV")
  parsed <- read_receita_sheet(path, "BRV", 2018L, "fixture-phantom")
  reference <- fixture_bin_values()
  bins <- parsed$distribution_bins[order(parsed$distribution_bins$bin_code), ]
  ordered <- reference[order(reference$code), ]

  # Sem o realinhamento, rank_sum receberia os valores de rank_cumulative.
  expect_equal(bins$rank_sum, ordered$rank_sum)
  expect_equal(bins$rank_cumulative, ordered$rank_cumulative)
  expect_equal(bins$rank_mean, ordered$rank_mean)

  components <- parsed$income_components
  tax <- components[components$component_id == "tax_due", ]
  tax <- tax[order(tax$bin_code), ]
  expect_equal(tax$value_nominal, ordered$tax_due)
  expect_false(any(grepl("^unmapped", components$component_id)))
})

test_that("cabeçalho descarta a anotação de unidade antes de resolver o campo", {
  skip_if_not_installed("writexl")
  path <- write_phantom_fixture_workbook("BRV", units = TRUE)
  parsed <- read_receita_sheet(path, "BRV", 2018L, "fixture-units")
  components <- parsed$income_components
  expect_setequal(unique(components$component_id), c("tax_due", "dividends"))
  tax <- components[components$component_id == "tax_due", ]
  expect_equal(
    tax$value_nominal[order(tax$bin_code)],
    fixture_bin_values()$tax_due[order(fixture_bin_values()$code)]
  )
})

test_that("layout dividido não sofre realinhamento", {
  skip_if_not_installed("writexl")
  path <- write_fixture_workbook("split", sheet = "BRV")
  parsed <- read_receita_sheet(path, "BRV", 2024L, "fixture-split")
  reference <- fixture_bin_values()
  bins <- parsed$distribution_bins[order(parsed$distribution_bins$bin_code), ]
  expect_equal(bins$rank_sum, reference$rank_sum[order(reference$code)])
})
