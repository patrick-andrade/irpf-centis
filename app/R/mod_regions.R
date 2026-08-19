mod_regions_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("missing")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        shiny::selectInput(ns("year"), "Ano", choices = NULL),
        shiny::selectInput(ns("metric"), "Indicador", choices = metric_choices)
      ),
      bslib::card(
        bslib::card_header("Comparação entre UFs"),
        bslib::layout_columns(
          col_widths = c(7, 5),
          shiny::plotOutput(ns("map"), height = "520px"),
          shiny::plotOutput(ns("plot"), height = "520px")
        ),
        shiny::tableOutput(ns("table"))
      )
    )
  )
}

mod_regions_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    output$missing <- shiny::renderUI(if (!bundle_has_data(bundle)) data_missing_ui())
    if (!bundle_has_data(bundle)) return(invisible(NULL))
    shiny::updateSelectInput(session, "year", choices = sort(unique(bundle$metrics$year)), selected = max(bundle$metrics$year))
    selected <- shiny::reactive({
      bundle$metrics |>
        dplyr::filter(.data$year == as.integer(input$year), .data$geo_level == "state", .data$ranking_id == "RB4") |>
        dplyr::transmute(UF = .data$geo_code, Indicador = .data[[input$metric]], Declarantes = .data$contributors) |>
        dplyr::arrange(.data$Indicador)
    })
    output$map <- shiny::renderPlot({
      shiny::validate(shiny::need(nrow(bundle$state_polygons) > 0L, "Malha estadual não disponível."))
      keys <- bundle$geographies |>
        dplyr::filter(.data$geo_level == "state") |>
        dplyr::transmute(codarea = as.character(.data$ibge_code), UF = .data$geo_code)
      poly <- bundle$state_polygons
      poly$UF <- keys$UF[match(poly$codarea, keys$codarea)]
      indicators <- selected()
      poly$Indicador <- indicators$Indicador[match(poly$UF, indicators$UF)]
      ggplot2::ggplot(poly, ggplot2::aes(.data$long, .data$lat, group = .data$piece, fill = .data$Indicador)) +
        ggplot2::geom_polygon(colour = "white", linewidth = 0.2) +
        ggplot2::coord_quickmap() +
        ggplot2::scale_fill_viridis_c(option = "C", na.value = "#D9D9D9") +
        ggplot2::labs(fill = NULL, caption = "Fonte da malha: IBGE. Indicadores calculados dentro de cada UF.") +
        ggplot2::theme_void(base_size = 11) +
        ggplot2::theme(legend.position = "bottom")
    })
    output$plot <- shiny::renderPlot({
      d <- selected()
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem dados estaduais."))
      p <- ggplot2::ggplot(d, ggplot2::aes(.data$Indicador, stats::reorder(.data$UF, .data$Indicador))) +
        ggplot2::geom_col(fill = "#005A9C") +
        ggplot2::labs(x = NULL, y = NULL, caption = "Centis calculados separadamente dentro de cada UF.") +
        ggplot2::theme_minimal(base_size = 11)
      if (grepl("share$", input$metric)) p <- p + ggplot2::scale_x_continuous(labels = scales::label_percent())
      p
    })
    output$table <- shiny::renderTable({
      selected()
    }, striped = TRUE, hover = TRUE)
  })
}
