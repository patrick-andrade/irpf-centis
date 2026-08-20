mod_evolution_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("missing")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        shiny::selectInput(ns("geo"), "Geografia", choices = NULL),
        shiny::selectInput(ns("ranking"), "Conceito de renda", choices = NULL),
        shiny::selectInput(ns("metric"), "Indicador", choices = metric_choices)
      ),
      bslib::card(
        bslib::card_header(shiny::textOutput(ns("title"))),
        shiny::plotOutput(ns("plot"), height = "520px")
      )
    )
  )
}

mod_evolution_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    output$missing <- shiny::renderUI(if (!bundle_has_data(bundle)) data_missing_ui())
    if (!bundle_has_data(bundle)) return(invisible(NULL))
    geo_choices <- bundle$geographies |>
      dplyr::filter(.data$geo_code %in% unique(bundle$metrics$geo_code)) |>
      dplyr::transmute(label = paste0(.data$geo_name, " (", .data$geo_code, ")"), value = .data$geo_code)
    shiny::updateSelectInput(session, "geo", choices = stats::setNames(geo_choices$value, geo_choices$label), selected = "BR")
    rankings <- unique(bundle$metrics$ranking_id)
    shiny::updateSelectInput(session, "ranking", choices = stats::setNames(rankings, vapply(rankings, \(x) ranking_label(bundle, x), character(1))), selected = "RB4")

    selected <- shiny::reactive({
      shiny::req(input$geo, input$ranking, input$metric)
      bundle$metrics |>
        dplyr::filter(.data$geo_code == input$geo, .data$ranking_id == input$ranking) |>
        dplyr::arrange(.data$year)
    })
    output$title <- shiny::renderText(paste(names(metric_choices)[match(input$metric, metric_choices)], "—", input$geo))
    output$plot <- shiny::renderPlot({
      d <- selected()
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem dados para a seleção."))
      p <- ggplot2::ggplot(d, ggplot2::aes(.data$year, .data[[input$metric]], group = 1)) +
        ggplot2::geom_line(colour = "#005A9C", linewidth = 1) +
        ggplot2::geom_point(colour = "#F2A900", size = 3) +
        ggplot2::scale_x_continuous(breaks = d$year) +
        ggplot2::labs(x = NULL, y = NULL, caption = "Estimativa com dados agrupados do IRPF") +
        ggplot2::theme_minimal(base_size = 12)
      if (grepl("share$", input$metric)) p <- p + ggplot2::scale_y_continuous(labels = scales::label_percent(decimal.mark = ","))
      p
    })
  })
}
