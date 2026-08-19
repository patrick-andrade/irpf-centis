mod_wealth_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("missing")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        shiny::selectInput(ns("year"), "Ano", choices = NULL),
        shiny::selectInput(ns("geo"), "Geografia", choices = NULL)
      ),
      bslib::card(
        bslib::card_header("Bens e dívidas dos declarantes (ordenação RB4)"),
        shiny::p(class = "small text-muted", "Totais dos componentes patrimoniais declarados; concentração patrimonial ao longo da distribuição de renda, não uma ordenação direta por patrimônio."),
        shiny::plotOutput(ns("plot"), height = "440px")
      ),
      bslib::card(
        bslib::card_header("Desigualdade patrimonial — ordenação direta nacional"),
        shiny::p(class = "small text-muted", "Série 2006–2021 da Tabela III, incluindo o grupo com patrimônio declarado igual a zero."),
        shiny::plotOutput(ns("direct_plot"), height = "360px")
      )
    )
  )
}

mod_wealth_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    has_inputs <- nrow(bundle$income_components) > 0L || nrow(bundle$wealth_metrics) > 0L
    output$missing <- shiny::renderUI(if (!has_inputs) data_missing_ui())
    if (!has_inputs) return(invisible(NULL))
    if (nrow(bundle$income_components) > 0L) {
      shiny::updateSelectInput(session, "year", choices = sort(unique(bundle$income_components$year)), selected = max(bundle$income_components$year))
      shiny::updateSelectInput(session, "geo", choices = sort(unique(bundle$income_components$geo_code)), selected = "BR")
    }
    output$plot <- shiny::renderPlot({
      shiny::validate(shiny::need(nrow(bundle$income_components) > 0L, "Componentes patrimoniais não disponíveis."))
      shiny::req(input$year, input$geo)
      d <- bundle$income_components |>
        dplyr::filter(
          .data$year == as.integer(input$year), .data$geo_code == input$geo,
          .data$ranking_id == "RB4", .data$component_group %in% c("asset", "liability"),
          .data$component_id %in% c("assets_real_estate", "assets_movable", "assets_financial", "assets_other", "debts")
        ) |>
        dplyr::group_by(.data$component_id, .data$field_label) |>
        dplyr::summarise(value = sum(.data$value_real, na.rm = TRUE), .groups = "drop")
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem dados patrimoniais para a seleção."))
      p <- ggplot2::ggplot(d, ggplot2::aes(stats::reorder(.data$field_label, .data$value), .data$value, fill = .data$component_id == "debts")) +
        ggplot2::geom_col(show.legend = FALSE) +
        ggplot2::scale_fill_manual(values = c(`FALSE` = "#005A9C", `TRUE` = "#A51C30")) +
        ggplot2::scale_y_continuous(labels = scales::label_number(
          prefix = "R$ ", scale_cut = scales::cut_short_scale()
        )) +
        ggplot2::labs(x = NULL, y = "Valor declarado em R$ de 2024") +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 25, hjust = 1))
      p
    })
    output$direct_plot <- shiny::renderPlot({
      shiny::validate(shiny::need(nrow(bundle$wealth_metrics) > 0L, "Série patrimonial direta não disponível."))
      d <- bundle$wealth_metrics
      p <- ggplot2::ggplot(d, ggplot2::aes(.data$year, .data$gini_grouped)) +
        ggplot2::geom_line(colour = "#6A1B9A", linewidth = 0.9) +
        ggplot2::geom_point(colour = "#6A1B9A", size = 2) +
        ggplot2::scale_x_continuous(breaks = d$year) +
        ggplot2::labs(x = NULL, y = "Gini patrimonial agrupado") +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
      p
    })
  })
}
