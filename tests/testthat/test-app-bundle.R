test_that("painel aceita bundle vazio antes do primeiro build", {
  source(project_path("app/R/helpers.R"), encoding = "UTF-8")
  bundle <- load_app_bundle(tempfile(fileext = ".rds"))
  expect_named(bundle, c(
    "metadata", "income_components", "metrics", "effective_tax",
    "wealth_by_bin", "top_group_counts",
    "theil_decomposition", "wealth_ranked_national", "wealth_metrics",
    "state_polygons", "geographies", "rankings", "indicators", "references"
  ))
  expect_equal(nrow(bundle$metrics), 0L)
  expect_equal(nrow(bundle$state_polygons), 0L)
})

test_that("agregação do bundle preserva ausência integral sem perder valores conhecidos", {
  expect_true(is.na(sum_known_values(c(NA_real_, NA_real_))))
  expect_equal(sum_known_values(c(2, NA_real_, 3)), 5)
  expect_equal(sum_known_values(c(0, NA_real_)), 0)
})

test_that("agregação exibida no painel também preserva ausência", {
  app <- load_app_module_env()
  components <- tibble::tibble(
    component_id = c("ausente", "ausente", "parcial", "parcial", "zero"),
    field_label = c("Ausente", "Ausente", "Parcial", "Parcial", "Zero"),
    value_real = c(NA_real_, NA_real_, 2, NA_real_, 0)
  )
  totals <- app$component_totals(components)
  expect_true(is.na(totals$value[totals$component_id == "ausente"]))
  expect_equal(totals$value[totals$component_id == "parcial"], 2)
  expect_equal(totals$value[totals$component_id == "zero"], 0)
})
