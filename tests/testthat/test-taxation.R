synthetic_tax_components <- function(bins) {
  leafs <- leaf_distribution(bins)
  tibble::tibble(
    year = leafs$year, geo_level = leafs$geo_level, geo_code = leafs$geo_code,
    ranking_id = leafs$ranking_id, bin_code = leafs$bin_code,
    component_id = "tax_due", component_group = "tax",
    field_label = "Imposto devido", unit = "BRL",
    value_nominal = 0.2 * leafs$rank_sum,
    source_id = "synthetic", source_file = "fixture.xlsx", source_sheet = "BRIV"
  )
}

test_that("alíquota efetiva é imposto devido sobre a renda do grupo", {
  bins <- synthetic_distribution()
  components <- synthetic_tax_components(bins)
  rates <- effective_tax_rates(bins, components)
  expect_equal(nrow(rates), 118L)
  expect_equal(unique(round(rates$effective_rate, 12)), 0.2)
  zero_income <- bins |>
    dplyr::mutate(rank_sum = ifelse(.data$bin_code == 1L, 0, .data$rank_sum))
  zero_rates <- effective_tax_rates(zero_income, components)
  expect_true(is.na(zero_rates$effective_rate[zero_rates$bin_code == 1L]))
})

test_that("resumo por grupos agrega topo e total coerentemente", {
  bins <- synthetic_distribution()
  components <- synthetic_tax_components(bins) |>
    dplyr::mutate(value_nominal = ifelse(.data$bin_code >= 101L, 0.1 * .data$value_nominal / 0.2, .data$value_nominal))
  rates <- effective_tax_rates(bins, components)
  summary <- effective_tax_summary(rates)
  expect_setequal(unique(summary$group), c("all", "top_10", "top_1", "top_0_1"))
  top1 <- summary[summary$group == "top_1", ]
  top_income <- sum(rates$rank_sum[rates$share_lower >= 0.99 - 1e-9])
  top_tax <- sum(rates$tax_due[rates$share_lower >= 0.99 - 1e-9])
  expect_equal(top1$effective_rate, top_tax / top_income)
  expect_equal(top1$effective_rate, 0.1, tolerance = 1e-12)
  all_rate <- summary[summary$group == "all", ]
  expect_lt(top1$effective_rate, all_rate$effective_rate)
})
