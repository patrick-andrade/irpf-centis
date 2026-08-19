mod_top_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      shiny::selectInput(ns("year"), "Ano", choices = NULL),
      shiny::selectInput(ns("geo"), "Geografia", choices = NULL)
    ),
    shiny::uiOutput(ns("content"))
  )
}

mod_top_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    if (!bundle_has_data(bundle)) {
      output$content <- shiny::renderUI(data_missing_ui())
      return(invisible(NULL))
    }
    shiny::updateSelectInput(session, "year", choices = sort(unique(bundle$metrics$year)), selected = max(bundle$metrics$year))
    shiny::updateSelectInput(session, "geo", choices = sort(unique(bundle$metrics$geo_code)), selected = "BR")
    row <- shiny::reactive({
      bundle$metrics |>
        dplyr::filter(.data$year == as.integer(input$year), .data$geo_code == input$geo, .data$ranking_id == "RB4")
    })
    output$content <- shiny::renderUI({
      d <- row()
      shiny::validate(shiny::need(nrow(d) == 1L, "Sem dados para a seleção."))
      bslib::layout_columns(
        col_widths = c(3, 3, 3, 3),
        bslib::value_box("Top 10%", scales::percent(d$top_10_share, 0.1)),
        bslib::value_box("Top 1%", scales::percent(d$top_1_share, 0.1)),
        bslib::value_box("Top 0,1%", scales::percent(d$top_0_1_share, 0.1)),
        bslib::value_box("Top 0,01%", scales::percent(d$top_0_01_share, 0.1)),
        bslib::card(
          bslib::card_header("Nota"),
          shiny::p("Os grupos detalhados do topo são disjuntos no cálculo. Os agregados 100 e 110 não são somados novamente.")
        )
      )
    })
  })
}

