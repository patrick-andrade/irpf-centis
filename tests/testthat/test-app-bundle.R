test_that("painel aceita bundle vazio antes do primeiro build", {
  source(project_path("app/R/helpers.R"), encoding = "UTF-8")
  bundle <- load_app_bundle(tempfile(fileext = ".rds"))
  expect_named(bundle, c(
    "metadata", "income_components", "metrics", "effective_tax",
    "theil_decomposition", "wealth_ranked_national", "wealth_metrics",
    "state_polygons", "geographies", "rankings"
  ))
  expect_equal(nrow(bundle$metrics), 0L)
  expect_equal(nrow(bundle$state_polygons), 0L)
})
