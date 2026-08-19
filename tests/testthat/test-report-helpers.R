report_metrics_fixture <- function() {
  bundle <- synthetic_app_bundle()
  bundle$metrics |>
    dplyr::bind_rows(
      bundle$metrics |>
        dplyr::filter(.data$geo_code == "BR") |>
        dplyr::mutate(ranking_id = "RTB", gini_grouped = .data$gini_grouped + 0.02)
    )
}

test_that("gráficos nacionais filtram de fato a geografia e o ranking (regressão B1)", {
  metrics <- report_metrics_fixture()
  evolution <- plot_metric_evolution(metrics, "gini_grouped", "Gini")
  expect_setequal(unique(evolution$data$geo_code), "BR")
  expect_setequal(unique(evolution$data$ranking_id), "RB4")
  expect_equal(nrow(evolution$data), 2L)

  shares <- plot_top_shares(metrics)
  expect_equal(nrow(shares$data), 2L * 3L)
  expect_setequal(unique(shares$data$group), c("Top 10%", "Top 1%", "Top 0,1%"))

  state <- plot_metric_evolution(metrics, "gini_grouped", "Gini", geo_code = "SP")
  expect_setequal(unique(state$data$geo_code), "SP")
})

test_that("comparação entre rankings traz apenas os conceitos pedidos", {
  metrics <- report_metrics_fixture()
  comparison <- plot_ranking_comparison(metrics, "gini_grouped", "Gini")
  expect_setequal(unique(comparison$data$ranking_id), c("RB4", "RTB"))
  expect_setequal(unique(comparison$data$geo_code), "BR")
})

test_that("curva e evolução da alíquota efetiva usam os filtros esperados", {
  bundle <- synthetic_app_bundle()
  curve <- plot_effective_rate_curve(bundle$effective_tax, year = 2024)
  expect_setequal(unique(curve$data$geo_code), "BR")
  expect_equal(nrow(curve$data), 5L)
  top_curve <- plot_effective_rate_curve(bundle$effective_tax, year = 2024, min_share = 0.5)
  expect_true(all(top_curve$data$share_lower >= 0.5))
  summary <- effective_tax_summary(bundle$effective_tax)
  evolution <- plot_effective_rate_evolution(summary)
  expect_setequal(unique(evolution$data$geo_code), "BR")
  expect_true(all(c("Todos os declarantes", "Top 10%") %in% evolution$data$group_label))
})

test_that("tabela estadual usa renda média real com rótulo de 2024", {
  metrics <- report_metrics_fixture()
  table <- latest_metrics_table(metrics)
  expect_true("Renda média (R$ de 2024)" %in% names(table))
  expect_setequal(table$UF, c("SP", "RJ"))
})
