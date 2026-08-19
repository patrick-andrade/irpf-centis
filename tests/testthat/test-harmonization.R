test_that("normalização de unidades multiplica por 1e6 apenas somas até 2021", {
  bins <- dplyr::bind_rows(
    synthetic_distribution(year = 2020L),
    synthetic_distribution(year = 2022L)
  )
  components <- tibble::tibble(
    year = c(2020L, 2020L, 2022L),
    unit = c("BRL", "count", "BRL"),
    value_nominal = c(2, 3, 5)
  )
  original <- bins
  result <- normalize_source_units(bins, components)
  legacy <- result$distribution_bins$year == 2020L
  expect_equal(
    result$distribution_bins$rank_sum[legacy],
    original$rank_sum[original$year == 2020L] * 1e6
  )
  expect_equal(
    result$distribution_bins$rank_cumulative[legacy],
    original$rank_cumulative[original$year == 2020L] * 1e6
  )
  expect_equal(
    result$distribution_bins$rank_sum[!legacy],
    original$rank_sum[original$year == 2022L]
  )
  expect_equal(result$distribution_bins$rank_mean, original$rank_mean)
  expect_equal(result$distribution_bins$rank_upper, original$rank_upper)
  expect_equal(result$income_components$value_nominal, c(2e6, 3, 5))
})

test_that("deflatores ausentes ou inválidos abortam com orientação", {
  expect_error(
    read_ipca_deflators("tmp/deflators-inexistentes.csv"),
    "run.cmd context"
  )
  invalid <- project_path("tmp/deflators-invalidos.csv")
  fs::dir_create(fs::path_dir(invalid), recurse = TRUE)
  readr::write_csv(tibble::tibble(ano = 2024), invalid)
  on.exit(fs::file_delete(invalid), add = TRUE)
  expect_error(read_ipca_deflators("tmp/deflators-invalidos.csv"), "inválido")
})

test_that("aplicar deflatores aborta quando falta ano na série do IPCA", {
  bins <- synthetic_distribution(year = 2022L)
  components <- empty_income_components()
  deflators <- tibble::tibble(year = 2024L, deflator_to_2024 = 1)
  expect_error(apply_deflators(bins, components, deflators), "2022")
})
