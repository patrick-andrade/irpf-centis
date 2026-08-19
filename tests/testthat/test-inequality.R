test_that("distribuição igual tem desigualdade e polarização nulas", {
  equal <- tibble::tibble(
    rank_mean = rep(10, 100), contributors = rep(1, 100),
    rank_sum = rep(10, 100), share_lower = (0:99) / 100,
    share_upper = (1:100) / 100, rank_upper = rep(10, 100)
  )
  expect_equal(grouped_gini(equal), 0, tolerance = 1e-12)
  expect_equal(grouped_theil_t(equal), 0, tolerance = 1e-12)
  expect_equal(grouped_atkinson(equal, 0.5), 0, tolerance = 1e-12)
  expect_equal(grouped_wolfson(equal), 0, tolerance = 1e-12)
})

test_that("índices agrupados ficam em domínios plausíveis", {
  data <- leaf_distribution(synthetic_distribution())
  metrics <- calculate_distribution_metrics(data)
  expect_gte(metrics$gini_grouped, 0)
  expect_lte(metrics$gini_grouped, 1)
  expect_gte(metrics$theil_t_grouped, 0)
  expect_gte(metrics$atkinson_grouped, 0)
  expect_equal(metrics$top_0_01_share, tail(data$rank_sum, 1) / sum(data$rank_sum))
})

test_that("Gini coincide com implementação independente quando disponível", {
  skip_if_not_installed("ineq")
  values <- c(1, 2, 3, 8)
  data <- tibble::tibble(rank_mean = values, contributors = rep(1, 4))
  expect_equal(grouped_gini(data), ineq::ineq(values, type = "Gini"), tolerance = 1e-12)
})
