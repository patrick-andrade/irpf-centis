app_env <- load_app_module_env()

empty_bundle <- app_env$load_app_bundle(tempfile(fileext = ".rds"))
filled_bundle <- synthetic_app_bundle()

expect_missing_card <- function(server_fun, bundle) {
  shiny::testServer(server_fun, args = list(bundle = bundle), {
    html <- as.character(output$missing$html)
    expect_match(html, "Dados processados não disponíveis")
  })
}

test_that("abas renderizam o cartão de dados ausentes com bundle vazio", {
  expect_missing_card(app_env$mod_composition_server, empty_bundle)
  expect_missing_card(app_env$mod_wealth_server, empty_bundle)
  expect_missing_card(app_env$mod_regions_server, empty_bundle)
  expect_missing_card(app_env$mod_evolution_server, empty_bundle)
})

test_that("composição renderiza gráficos e alíquota efetiva com dados", {
  shiny::testServer(app_env$mod_composition_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", geo = "BR", group = "taxable")
    expect_no_error(output$plot)
    expect_no_error(output$tax_curve)
  })
})

test_that("aba patrimonial renderiza componentes e série direta", {
  shiny::testServer(app_env$mod_wealth_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", geo = "BR")
    expect_no_error(output$plot)
    expect_no_error(output$direct_plot)
  })
})

test_that("aba de estados desenha mapa por polígonos, ranking e tabela", {
  shiny::testServer(app_env$mod_regions_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", metric = "gini_grouped")
    expect_no_error(output$map)
    expect_no_error(output$plot)
    expect_no_error(output$table)
  })
})

test_that("evolução responde à seleção de geografia e indicador", {
  shiny::testServer(app_env$mod_evolution_server, args = list(bundle = filled_bundle), {
    session$setInputs(geo = "SP", ranking = "RB4", metric = "top_1_share")
    expect_no_error(output$plot)
    expect_match(output$title, "SP")
  })
})
