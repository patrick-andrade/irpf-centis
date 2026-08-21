test_that("aba patrimonial deriva o ano-calendário do nome BRxx", {
  skip_if_not_installed("writexl")
  path <- write_wealth_fixture_workbook(sheet = "BR07")
  parsed <- parse_wealth_sheet(path, "BR07", "fixture-wealth")
  expect_equal(unique(parsed$year), 2006L)
  expect_equal(unique(parsed$ranking_id), "WEALTH_DIRECT")
  expect_equal(nrow(parsed), 121L)
  expect_true(0L %in% parsed$bin_code)
})

test_that("grupo de patrimônio zero é remapeado para participações populacionais", {
  skip_if_not_installed("writexl")
  path <- write_wealth_fixture_workbook(sheet = "BR16")
  parsed <- parse_wealth_sheet(path, "BR16", "fixture-wealth")
  expect_equal(unique(parsed$year), 2015L)
  zero_row <- parsed[parsed$bin_code == 0L, ]
  leaf_positive <- parsed[parsed$is_leaf & parsed$bin_code != 0L, ]
  zero_share <- zero_row$contributors / (zero_row$contributors + sum(leaf_positive$contributors))
  expect_equal(zero_row$population_share_lower, 0)
  expect_equal(zero_row$population_share_upper, zero_share)
  first_centile <- parsed[parsed$bin_code == 1L, ]
  expect_equal(first_centile$population_share_lower, zero_share)
  expect_equal(
    first_centile$population_share_upper,
    zero_share + (1 - zero_share) * 0.01
  )
  top_row <- parsed[parsed$bin_code == 120L, ]
  expect_equal(top_row$population_share_upper, 1)
})

test_that("somas patrimoniais são reescaladas de milhões e médias preservadas", {
  skip_if_not_installed("writexl")
  path <- write_wealth_fixture_workbook()
  parsed <- parse_wealth_sheet(path, "BR07", "fixture-wealth")
  centile_10 <- parsed[parsed$bin_code == 10L, ]
  expect_equal(centile_10$wealth_mean, 100)
  expect_equal(centile_10$wealth_sum, 100 * centile_10$contributors)
  expect_equal(
    parse_wealth_workbook(path, "fixture-wealth")$year |> unique(),
    2006L
  )
})

test_that("métricas patrimoniais ficam em domínios plausíveis com o grupo zero", {
  skip_if_not_installed("writexl")
  path <- write_wealth_fixture_workbook()
  parsed <- parse_wealth_sheet(path, "BR07", "fixture-wealth")
  metrics <- calculate_wealth_metrics(parsed)
  expect_equal(nrow(metrics), 1L)
  expect_gte(metrics$gini_grouped, 0)
  expect_lte(metrics$gini_grouped, 1)
  expect_gte(metrics$top_1_share, 0)
  expect_true(is.na(metrics$income_mean_real))
})

# Bins deflacionados com deflator 1: os valores reais coincidem com os nominais
# e as asserções ficam legíveis.
synthetic_wealth_inputs <- function(zero_income_bin = 1L, com_total = TRUE) {
  bins <- synthetic_distribution() |>
    dplyr::mutate(
      rank_sum = ifelse(.data$bin_code == zero_income_bin, 0, .data$rank_sum),
      rank_sum_real = .data$rank_sum,
      joint_returns = ifelse(.data$year == 2024L, .data$contributors * 0.1, NA_real_)
    )
  leafs <- leaf_distribution(bins)
  componente <- function(id, grupo, valor) {
    tibble::tibble(
      year = leafs$year, geo_level = leafs$geo_level, geo_code = leafs$geo_code,
      ranking_id = leafs$ranking_id, bin_code = leafs$bin_code,
      component_id = id, component_group = grupo, field_label = id, unit = "BRL",
      value_nominal = valor, value_real = valor
    )
  }
  partes <- list(
    componente("assets_real_estate", "asset", 40 * leafs$contributors),
    componente("assets_movable", "asset", 10 * leafs$contributors),
    componente("assets_financial", "asset", 30 * leafs$contributors),
    componente("assets_other", "asset", 20 * leafs$contributors),
    componente("debts", "liability", 0.5 * leafs$rank_sum),
    componente("dependents_count", "count", 0.8 * leafs$contributors)
  )
  if (com_total) {
    partes <- c(partes, list(componente("assets_total", "asset", 100 * leafs$contributors)))
  }
  list(bins = bins, components = dplyr::bind_rows(partes))
}

test_that("bens e dívidas por grupo cobrem as folhas disjuntas", {
  entradas <- synthetic_wealth_inputs()
  resultado <- wealth_by_bin(entradas$bins, entradas$components)
  expect_equal(nrow(resultado), 118L)
  expect_equal(sum(resultado$debt_share, na.rm = TRUE), 1)
  expect_equal(sum(resultado$assets_share, na.rm = TRUE), 1)
  # Total de bens é a soma das quatro famílias, e coincide com o total divulgado.
  expect_equal(resultado$assets_sum_real, resultado$assets_total_real)
})

test_that("razão dívida/renda fica NA quando o grupo não declara renda", {
  entradas <- synthetic_wealth_inputs()
  resultado <- wealth_by_bin(entradas$bins, entradas$components)
  sem_renda <- resultado[resultado$bin_code == 1L, ]
  expect_true(is.na(sem_renda$debt_income_ratio))
  expect_false(is.na(sem_renda$debts_real))
  com_renda <- resultado[resultado$bin_code == 50L, ]
  expect_equal(com_renda$debt_income_ratio, 0.5)
})

test_that("ausência do total consolidado não zera a soma das famílias", {
  entradas <- synthetic_wealth_inputs(com_total = FALSE)
  resultado <- wealth_by_bin(entradas$bins, entradas$components)
  expect_true(all(is.na(resultado$assets_total_real)))
  expect_true(all(is.finite(resultado$assets_sum_real)))
})

test_that("contagens de topo são aninhadas e preservam campo não divulgado", {
  entradas <- synthetic_wealth_inputs()
  contagens <- top_group_counts(entradas$bins, entradas$components)
  expect_setequal(contagens$group, c("top_10", "top_1", "top_0_1", "top_0_01"))
  ordenado <- contagens[order(contagens$share_lower), ]
  expect_true(all(diff(ordenado$contributors) <= 0))
  # O corte 0,9999 isola o grupo 120, que no fixture tem uma declaração.
  expect_equal(ordenado$contributors[ordenado$group == "top_0_01"], 1)
  expect_equal(ordenado$contributors[ordenado$group == "top_10"], 1000)
  expect_true(all(is.finite(contagens$dependents)))
})

test_that("declarações conjuntas ausentes propagam NA em vez de zero", {
  entradas <- synthetic_wealth_inputs()
  entradas$bins$joint_returns <- NA_real_
  contagens <- top_group_counts(entradas$bins, entradas$components)
  expect_true(all(is.na(contagens$joint_returns)))
})
