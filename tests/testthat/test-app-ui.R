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
    "assets-year", "assets-geo",
    "debt-year", "debt-geo",
    "regions-year", "regions-metric"
  )
  for (id in filtros) {
    expect_true(
      grepl(id, html, fixed = TRUE),
      label = paste0("filtro '", id, "' presente no HTML inicial")
    )
  }
})

test_that("o painel expõe as abas previstas, inclusive as do menu suspenso", {
  html <- as.character(htmltools::renderTags(app_ui_object())$html)
  abas <- c(
    "Visão geral", "Evolução", "Topos da renda", "Rendimentos e imposto",
    "Patrimônio e dívidas", "Bens", "Dívidas", "Estados e regiões",
    "Metodologia e dados"
  )
  for (aba in abas) {
    expect_true(
      grepl(aba, html, fixed = TRUE),
      label = paste0("aba '", aba, "' presente no HTML inicial")
    )
  }
})

test_that("as abas não são contêineres de preenchimento", {
  # Com `fillable = TRUE` no page_navbar cada aba vira html-fill-container e os
  # plotOutput viram fill items: a altura declarada (520/440/360px) é anulada.
  # Medido no navegador sobre o HTML da UI, as sete saídas de gráfico ficam com
  # altura 0 nesse modo — e o renderPlot aborta com "invalid 'height' argument"
  # — contra a altura declarada quando as abas não preenchem.
  html <- as.character(htmltools::renderTags(app_ui_object())$html)
  panes <- regmatches(html, gregexpr('class="tab-pane[^"]*"', html))[[1]]
  expect_gt(length(panes), 0L)
  expect_false(any(grepl("html-fill-container", panes, fixed = TRUE)))
})

test_that("os gráficos declaram altura explícita", {
  html <- as.character(htmltools::renderTags(app_ui_object())$html)
  saidas <- regmatches(
    html, gregexpr('class="shiny-plot-output[^>]*style="[^"]*"', html)
  )[[1]]
  expect_gte(length(saidas), 11L)
  for (s in saidas) {
    expect_true(
      grepl("height:[ ]?[1-9][0-9]*px", s),
      label = paste0("altura explícita em ", substr(s, 1, 60))
    )
  }
})
