test_that("Atkinson com epsilon = 1 usa a média geométrica ponderada", {
  data <- tibble::tibble(rank_mean = c(1, 2, 4), contributors = c(1, 1, 1))
  expected <- 1 - exp(mean(log(c(1, 2, 4)))) / mean(c(1, 2, 4))
  expect_equal(grouped_atkinson(data, 1), expected, tolerance = 1e-12)
  equal <- tibble::tibble(rank_mean = rep(7, 5), contributors = rep(2, 5))
  expect_equal(grouped_atkinson(equal, 1), 0, tolerance = 1e-12)
  with_zero <- tibble::tibble(rank_mean = c(0, 10), contributors = c(1, 1))
  expect_equal(grouped_atkinson(with_zero, 1), 1)
  expect_true(is.na(grouped_atkinson(data, -0.5)))
})

test_that("participações de topo e base batem com contas manuais no sintético", {
  data <- leaf_distribution(synthetic_distribution())
  total <- sum(data$rank_sum)
  expect_equal(total, 99 * 100 + 9 * 20 + 10 * 3)
  expect_equal(income_share_bottom(data, 0.40), (40 * 100) / total)
  top10_expected <- (9 * 100 + 9 * 20 + 10 * 3) / total
  expect_equal(income_share_top(data, 0.10), top10_expected)
  metrics <- calculate_distribution_metrics(data)
  expect_equal(metrics$palma, top10_expected / ((40 * 100) / total))
  expect_equal(metrics$p90_p50, 1)
})

test_that("fronteira do top 0,01% tolera ruído de ponto flutuante", {
  data <- tibble::tibble(
    share_lower = c(0, 1 - 1e-4 - 1e-12),
    share_upper = c(1 - 1e-4, 1),
    rank_sum = c(9999, 1)
  )
  expect_equal(income_share_top(data, 0.0001), 1 / 10000)
})

test_that("Esteban-Ray reproduz valor conhecido de dois pontos", {
  data <- tibble::tibble(rank_mean = c(0, 2), contributors = c(1, 1))
  expect_equal(grouped_esteban_ray(data, 1.0), 0.5, tolerance = 1e-12)
  expect_true(is.na(grouped_esteban_ray(data, 2)))
})

test_that("decomposição de Theil por UF fecha com o Theil agrupado empilhado", {
  sp <- synthetic_distribution(geo_code = "SP")
  rj <- synthetic_distribution(geo_code = "RJ") |>
    dplyr::mutate(
      rank_sum = .data$rank_sum * 2,
      rank_mean = .data$rank_mean * 2,
      rank_upper = .data$rank_upper * 2,
      rank_cumulative = .data$rank_cumulative * 2
    )
  bins <- dplyr::bind_rows(sp, rj)
  decomposition <- theil_decomposition_uf(bins, "RB4")
  expect_equal(nrow(decomposition), 1L)
  expect_gt(decomposition$theil_between_uf, 0)
  pooled <- grouped_theil_t(leaf_distribution(bins))
  expect_equal(
    decomposition$theil_within_uf + decomposition$theil_between_uf,
    pooled,
    tolerance = 1e-9
  )
})

test_that("limites de Gastwirth cercam o Gini agrupado", {
  single <- tibble::tibble(
    rank_mean = 100, contributors = 10, rank_sum = 1000,
    rank_upper = 200, share_lower = 0, share_upper = 1
  )
  bounds <- grouped_gini_bounds(single)
  expect_equal(bounds$gini_lower_bound, 0)
  expect_equal(bounds$gini_upper_bound, 0.5)

  open_top <- tibble::tibble(
    rank_mean = c(5, 20), contributors = c(1, 1), rank_sum = c(5, 20),
    rank_upper = c(10, NA), share_lower = c(0, 0.5), share_upper = c(0.5, 1)
  )
  open_bounds <- grouped_gini_bounds(open_top)
  lower <- grouped_gini(open_top)
  expect_equal(open_bounds$gini_lower_bound, lower)
  pop_share <- c(0.5, 0.5)
  income_share <- c(5, 20) / 25
  gmax <- c((5 - 0) * (10 - 5) / (5 * 10), 1 - 10 / 20)
  expect_equal(
    open_bounds$gini_upper_bound,
    lower + sum(pop_share * income_share * gmax),
    tolerance = 1e-12
  )

  synthetic <- leaf_distribution(synthetic_distribution())
  metrics <- calculate_distribution_metrics(synthetic)
  expect_equal(metrics$gini_lower_bound, metrics$gini_grouped)
  expect_gte(metrics$gini_upper_bound, metrics$gini_lower_bound)
  expect_lte(metrics$gini_upper_bound, 1)
})
