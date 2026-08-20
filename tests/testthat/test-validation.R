# Portões de plausibilidade dos indicadores derivados. Existem porque a
# alíquota efetiva de 2017-2021 chegou a ser publicada acima de 100%.

metrics_fixture <- function(...) {
  base <- tibble::tibble(
    year = 2017:2024, geo_level = "national", geo_code = "BR", ranking_id = "RB4",
    gini_grouped = seq(0.58, 0.61, length.out = 8),
    atkinson_grouped = 0.25, wolfson_grouped = 0.4, palma = 3.2
  )
  overrides <- list(...)
  for (name in names(overrides)) base[[name]] <- overrides[[name]]
  base
}

tax_fixture <- function(rates) tibble::tibble(effective_rate = rates)

faixa_de <- function(checks) checks[checks$check == "effective_rate_range", ]

test_that("alíquota efetiva fora de [0, 1] reprova o portão", {
  ok <- faixa_de(validate_effective_rate_range(tax_fixture(c(0, 0.05, 0.1, Inf))))
  expect_equal(ok$status, "pass")

  bad <- faixa_de(validate_effective_rate_range(tax_fixture(c(0.05, 1.23, 2706.9))))
  expect_equal(bad$status, "fail")
  expect_match(bad$detail, "2 grupo")
})

test_that("Gini e Atkinson fora de [0, 1] reprovam; Wolfson alto apenas avisa", {
  ok <- run_derived_quality_checks(metrics_fixture(), tax_fixture(c(0.05, 0.1)))
  expect_equal(ok$status[ok$check == "bounded_index_range"], "pass")
  expect_equal(ok$status[ok$check == "unstable_index_values"], "pass")

  broken <- validate_index_ranges(metrics_fixture(gini_grouped = c(rep(0.6, 7), 1.4)))
  expect_equal(broken$status[broken$check == "bounded_index_range"], "fail")

  unstable <- validate_index_ranges(metrics_fixture(
    wolfson_grouped = c(rep(0.4, 7), 4.5), palma = c(rep(3.2, 7), 2064)
  ))
  expect_equal(unstable$status[unstable$check == "unstable_index_values"], "warn")
  expect_match(unstable$detail[unstable$check == "unstable_index_values"], "^2 ")
})

test_that("salto anual de Gini vira aviso, não falha", {
  ok <- validate_year_over_year(metrics_fixture())
  expect_equal(ok$status, "pass")

  # O perfil de 2018 na série real: sobe ~0,09 e volta.
  spike <- validate_year_over_year(metrics_fixture(
    gini_grouped = c(0.577, 0.666, 0.584, 0.596, 0.611, 0.602, 0.618, 0.604)
  ))
  expect_equal(spike$status, "warn")
  expect_match(spike$detail, "RB4/2018")
  expect_match(spike$detail, "RB4/2019")
})

test_that("assert_quality barra falha e deixa passar aviso", {
  checks <- run_derived_quality_checks(metrics_fixture(), tax_fixture(c(0.05, 0.1)))
  expect_silent(assert_quality(checks))
  expect_error(
    assert_quality(validate_effective_rate_range(tax_fixture(c(1.23)))),
    "effective_rate_range"
  )
})

test_that("sem indicadores derivados o portão reprova", {
  empty <- run_derived_quality_checks(metrics_fixture()[0, ], tax_fixture(numeric()))
  expect_equal(empty$status, "fail")
})

test_that("razão não interpretável é suprimida e contada, não publicada", {
  bins <- tibble::tibble(
    year = 2024L, geo_level = "national", geo_code = "BR", ranking_id = "RB5",
    bin_code = c(1L, 2L, 3L), is_leaf = TRUE,
    share_lower = c(0, 0.01, 0.02), share_upper = c(0.01, 0.02, 0.03),
    contributors = 100, rank_sum = c(1000, 0, 5), rank_cumulative = 1
  )
  components <- tibble::tibble(
    year = 2024L, geo_level = "national", geo_code = "BR", ranking_id = "RB5",
    bin_code = c(1L, 2L, 3L), component_id = "tax_due",
    value_nominal = c(50, 10, 900)
  )
  rates <- effective_tax_rates(bins, components)

  # Denominador bom: razão normal. Renda nula e imposto acima da renda: NA.
  expect_equal(rates$effective_rate[rates$bin_code == 1L], 0.05)
  expect_true(is.na(rates$effective_rate[rates$bin_code == 2L]))
  expect_true(is.na(rates$effective_rate[rates$bin_code == 3L]))
  # Os valores de origem seguem intactos na tabela.
  expect_equal(rates$tax_due[rates$bin_code == 3L], 900)
  expect_equal(rates$rank_sum[rates$bin_code == 3L], 5)

  checks <- validate_effective_rate_range(rates)
  expect_equal(checks$status[checks$check == "effective_rate_range"], "pass")
  expect_equal(checks$status[checks$check == "effective_rate_coverage"], "warn")
  expect_match(checks$detail[checks$check == "effective_rate_coverage"], "^2 de 3")
})
