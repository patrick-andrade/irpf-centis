mod_composition_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("missing")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        shiny::selectInput(ns("year"), "Ano", choices = NULL),
        shiny::selectInput(ns("geo"), "Geografia", choices = NULL),
        shiny::selectInput(ns("group"), "Grupo de campos", choices = c("Tributáveis" = "taxable", "Exclusivos" = "exclusive", "Isentos" = "exempt", "Deduções" = "deduction", "Imposto" = "tax"))
      ),
      bslib::card(
        bslib::card_header("Composição declarada"),
        shiny::plotOutput(ns("plot"), height = "440px")
      ),
      bslib::card(
        bslib::card_header("Alíquota efetiva média por posição na distribuição"),
        shiny::p(class = "small text-muted", "Imposto devido dividido pela renda RB4 de cada grupo; média com dados agrupados, sem variação interna aos grupos."),
        shiny::plotOutput(ns("tax_curve"), height = "360px")
      )
    )
  )
}

mod_composition_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    output$missing <- shiny::renderUI(if (nrow(bundle$income_components) == 0L) data_missing_ui())
    if (nrow(bundle$income_components) == 0L) return(invisible(NULL))
    shiny::updateSelectInput(session, "year", choices = sort(unique(bundle$income_components$year)), selected = max(bundle$income_components$year))
    shiny::updateSelectInput(session, "geo", choices = sort(unique(bundle$income_components$geo_code)), selected = "BR")
    output$plot <- shiny::renderPlot({
      shiny::req(input$year, input$geo, input$group)
      d <- bundle$income_components |>
        dplyr::filter(
          .data$year == as.integer(input$year), .data$geo_code == input$geo,
          .data$ranking_id == "RB4", .data$component_group == input$group
        ) |>
        dplyr::group_by(.data$component_id, .data$field_label) |>
        dplyr::summarise(value = sum(.data$value_real, na.rm = TRUE), .groups = "drop") |>
        dplyr::slice_max(.data$value, n = 12, with_ties = FALSE) |>
        dplyr::arrange(.data$value)
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem componentes para a seleção."))
      p <- ggplot2::ggplot(d, ggplot2::aes(.data$value, stats::reorder(.data$field_label, .data$value))) +
        ggplot2::geom_col(fill = "#005A9C") +
        ggplot2::scale_x_continuous(labels = scales::label_number(
          prefix = "R$ ", scale_cut = scales::cut_short_scale()
        )) +
        ggplot2::labs(x = "Valor declarado em R$ de 2024", y = NULL) +
        ggplot2::theme_minimal(base_size = 11)
      p
    })
    output$tax_curve <- shiny::renderPlot({
      shiny::req(input$year, input$geo)
      shiny::validate(shiny::need(nrow(bundle$effective_tax) > 0L, "Alíquotas efetivas não disponíveis."))
      d <- bundle$effective_tax |>
        dplyr::filter(
          .data$year == as.integer(input$year), .data$geo_code == input$geo,
          is.finite(.data$effective_rate)
        ) |>
        dplyr::arrange(.data$share_upper)
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem alíquotas para a seleção."))
      ggplot2::ggplot(d, ggplot2::aes(.data$share_upper, .data$effective_rate)) +
        ggplot2::geom_line(colour = "#005A9C", linewidth = 0.8) +
        ggplot2::geom_point(colour = "#005A9C", size = 1) +
        ggplot2::scale_x_continuous(labels = scales::label_percent()) +
        ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 0.1)) +
        ggplot2::labs(
          x = "Posição na distribuição (limite superior do grupo)",
          y = "Alíquota efetiva média"
        ) +
        ggplot2::theme_minimal(base_size = 11)
    })
  })
}
