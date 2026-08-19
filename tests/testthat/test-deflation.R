test_that("deflação preserva nominal e cria valores de 2024", {
  bins <- synthetic_distribution()
  components <- empty_income_components()
  deflator <- tibble::tibble(year = 2024L, deflator_to_2024 = 1)
  result <- apply_deflators(bins, components, deflator)
  expect_equal(result$distribution_bins$rank_sum_real, bins$rank_sum)
  expect_true("value_real" %in% names(result$income_components))
})
