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
