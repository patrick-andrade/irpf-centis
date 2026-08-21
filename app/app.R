module_files <- sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(module_files, source, encoding = "UTF-8"))

bundle <- load_app_bundle("data/app-bundle.rds")

ui <- bslib::page_navbar(
  title = "IRPF por centis",
  fillable = FALSE,
  header = shiny::tagList(
    shiny::tags$head(shiny::tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")),
    shiny::tags$div(
      class = "universe-warning",
      role = "note",
      "Os dados representam declarações válidas do IRPF, não toda a população brasileira."
    )
  ),
  # A UI dos módulos entra direto no navbar, e não por uiOutput/renderUI: saídas
  # de abas ocultas ficam suspensas até a aba ser aberta, de modo que os selects
  # ainda não existiriam quando os updateSelectInput da inicialização são
  # enviados — as mensagens se perdiam e cinco das sete abas ficavam com os
  # filtros vazios.
  bslib::nav_panel("Visão geral", mod_overview_ui("overview")),
  bslib::nav_panel("Evolução", mod_evolution_ui("evolution")),
  bslib::nav_panel("Topos da renda", mod_top_ui("top")),
  bslib::nav_panel("Rendimentos e imposto", mod_composition_ui("composition")),
  # nav_menu mantém a navbar com sete entradas e ainda assim declara os dois
  # painéis inline: o conteúdo entra no DOM no carregamento, então os
  # updateSelectInput da inicialização encontram os selects.
  bslib::nav_menu(
    "Patrimônio e dívidas",
    bslib::nav_panel("Bens", mod_assets_ui("assets")),
    bslib::nav_panel("Dívidas", mod_debt_ui("debt"))
  ),
  bslib::nav_panel("Estados e regiões", mod_regions_ui("regions")),
  bslib::nav_panel("Metodologia e dados", mod_methodology_ui("methodology")),
  footer = shiny::tags$footer(
    class = "app-footer",
    "Fonte: Receita Federal do Brasil. Índices de desigualdade e polarização são aproximações com dados agrupados."
  )
)

server <- function(input, output, session) {
  mod_overview_server("overview", bundle)
  mod_evolution_server("evolution", bundle)
  mod_top_server("top", bundle)
  mod_composition_server("composition", bundle)
  mod_assets_server("assets", bundle)
  mod_debt_server("debt", bundle)
  mod_regions_server("regions", bundle)
  mod_methodology_server("methodology", bundle)
}

shiny::shinyApp(ui, server)
