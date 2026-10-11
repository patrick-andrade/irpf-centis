report_metrics_fixture <- function() {
  bundle <- fixture_sintetica()
  bundle$metrics |>
    dplyr::bind_rows(
      bundle$metrics |>
        dplyr::filter(.data$geo_code == "BR") |>
        dplyr::mutate(ranking_id = "RTB", gini_grouped = .data$gini_grouped + 0.02)
    )
}

test_that("tabela estadual usa renda média real com rótulo de 2024", {
  metrics <- report_metrics_fixture()
  table <- latest_metrics_table(metrics)
  expect_true("Renda média (R$ de 2024)" %in% names(table))
  # Nome por extenso: código de UF não é leitura de público geral.
  expect_setequal(table$`Unidade da Federação`, c("São Paulo", "Rio de Janeiro"))
  expect_false("UF" %in% names(table))
})

test_that("achados do sumário usam vírgula decimal e não inventam variação", {
  metrics <- report_metrics_fixture()
  achados <- executive_findings(metrics)
  # "19.8%" e "0.577" eram impressos por sprintf em texto em português.
  expect_false(any(grepl("[0-9][.][0-9]", achados)))
  expect_true(any(grepl("0,550", achados, fixed = TRUE)))
  # O fixture não muda entre os dois anos: a frase não pode dizer "diminuiu".
  expect_true(any(grepl("manteve-se em 20,0%", achados, fixed = TRUE)))
  expect_false(any(grepl("diminuiu", achados)))

  subiu <- metrics
  subiu$top_1_share[subiu$year == 2024] <- 0.25
  expect_true(any(grepl("aumentou de 20,0% para 25,0%", executive_findings(subiu), fixed = TRUE)))
})
