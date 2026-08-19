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
