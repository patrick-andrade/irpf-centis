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
      d <- d[is.finite(d[[input$metric]]), , drop = FALSE]
      shiny::validate(shiny::need(nrow(d) > 0L, "Indicador não definido para a seleção."))
      rotulo <- names(metric_choices)[match(input$metric, metric_choices)]

      # Participações partem do zero; índices ganham amplitude mínima para que
      # uma variação pequena não ocupe a altura inteira do painel.
      escala_y <- if (grepl("share$", input$metric)) {
        escala_participacao(d[[input$metric]], nome = rotulo)
      } else {
        escala_indice(d[[input$metric]], nome = rotulo)
      }
      formatar <- if (grepl("share$", input$metric)) {
        rotulo_percentual(0.1)
      } else {
        rotulo_indice(0.001)
      }

      ggplot2::ggplot(d, ggplot2::aes(.data$year, .data[[input$metric]], group = 1)) +
        ggplot2::geom_line(colour = cor_destaque(1), linewidth = 1) +
        ggplot2::geom_point(colour = cor_destaque(1), size = 2.6) +
        rotular_extremos(d, "year", input$metric, formatar = formatar) +
        escala_ano(d$year) +
        escala_y +
        ggplot2::labs(x = NULL, caption = "Estimativa com dados agrupados do IRPF.") +
        tema_irpf(base_size = 13, direcao = "y")
    })
  })
}
