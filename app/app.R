module_files <- sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(module_files, source, encoding = "UTF-8"))

bundle <- load_app_bundle("data/app-bundle.rds")

ui <- bslib::page_navbar(
  title = "IRPF por centis",
  fillable = TRUE,
  header = shiny::tagList(
    shiny::tags$head(shiny::tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")),
    shiny::tags$div(
      class = "universe-warning",
      role = "note",
      "Os dados representam declarações válidas do IRPF, não toda a população brasileira."
    )
  ),
  bslib::nav_panel("Visão geral", shiny::uiOutput("overview_panel")),
  bslib::nav_panel("Evolução", shiny::uiOutput("evolution_panel")),
  bslib::nav_panel("Topos da renda", shiny::uiOutput("top_panel")),
  bslib::nav_panel("Rendimentos e imposto", shiny::uiOutput("composition_panel")),
  bslib::nav_panel("Bens e dívidas", shiny::uiOutput("wealth_panel")),
  bslib::nav_panel("Estados e regiões", shiny::uiOutput("regions_panel")),
  bslib::nav_panel("Metodologia e dados", shiny::uiOutput("methodology_panel")),
  footer = shiny::tags$footer(
    class = "app-footer",
    "Fonte: Receita Federal do Brasil. Índices de desigualdade e polarização são aproximações com dados agrupados."
  )
)

server <- function(input, output, session) {
  output$overview_panel <- shiny::renderUI(mod_overview_ui("overview"))
  output$evolution_panel <- shiny::renderUI(mod_evolution_ui("evolution"))
  output$top_panel <- shiny::renderUI(mod_top_ui("top"))
  output$composition_panel <- shiny::renderUI(mod_composition_ui("composition"))
  output$wealth_panel <- shiny::renderUI(mod_wealth_ui("wealth"))
  output$regions_panel <- shiny::renderUI(mod_regions_ui("regions"))
  output$methodology_panel <- shiny::renderUI(mod_methodology_ui("methodology"))
  mod_overview_server("overview", bundle)
  mod_evolution_server("evolution", bundle)
  mod_top_server("top", bundle)
  mod_composition_server("composition", bundle)
  mod_wealth_server("wealth", bundle)
  mod_regions_server("regions", bundle)
  mod_methodology_server("methodology", bundle)
}

shiny::shinyApp(ui, server)
