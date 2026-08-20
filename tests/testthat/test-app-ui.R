app_ui_object <- function(root = test_project_root) {
  env <- new.env(parent = globalenv())
  old <- setwd(file.path(root, "app"))
  on.exit(setwd(old), add = TRUE)
  sys.source("app.R", envir = env)
  env$ui
}

test_that("os filtros de todas as abas entram no HTML inicial do painel", {
  # Regressão de um defeito que só aparecia no navegador: com a UI das abas
  # atrás de uiOutput/renderUI, as saídas das abas ocultas ficam suspensas até
  # a aba ser aberta, de modo que os updateSelectInput disparados na
  # inicialização do servidor chegam antes de os selects existirem. As
  # mensagens se perdem e cinco das sete abas ficam com os filtros vazios para
  # sempre. shiny::testServer não enxerga isso porque não passa pelo cliente.
  html <- as.character(htmltools::renderTags(app_ui_object())$html)
  filtros <- c(
    "evolution-geo", "evolution-ranking", "evolution-metric",
    "top-year", "top-geo",
    "composition-year", "composition-geo", "composition-group",
    "wealth-year", "wealth-geo",
    "regions-year", "regions-metric"
  )
  for (id in filtros) {
    expect_true(
      grepl(id, html, fixed = TRUE),
      label = paste0("filtro '", id, "' presente no HTML inicial")
    )
  }
})

test_that("o painel expõe as sete abas previstas", {
  html <- as.character(htmltools::renderTags(app_ui_object())$html)
  abas <- c(
    "Visão geral", "Evolução", "Topos da renda", "Rendimentos e imposto",
    "Bens e dívidas", "Estados e regiões", "Metodologia e dados"
  )
  for (aba in abas) {
    expect_true(
      grepl(aba, html, fixed = TRUE),
      label = paste0("aba '", aba, "' presente no HTML inicial")
    )
  }
})
