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
      # Barras horizontais: dispensam rótulo inclinado e o comprimento fica
      # comparável numa linha de base comum. Bens e dívidas são categorias
      # qualitativas, então entram na paleta Okabe-Ito, não na rampa ordinal.
      cores <- stats::setNames(cor_destaque(2), c("Bens e direitos", "Dívidas e ônus"))
      d$tipo <- ifelse(d$component_id == "debts", "Dívidas e ônus", "Bens e direitos")
      ggplot2::ggplot(d, ggplot2::aes(.data$value, stats::reorder(.data$field_label, .data$value), fill = .data$tipo)) +
        ggplot2::geom_col(width = 0.72) +
        ggplot2::scale_fill_manual(values = cores, name = NULL) +
        escala_dinheiro(c(0, d$value), eixo = "x", nome = "Valor declarado em R$ de 2024") +
        ggplot2::labs(y = NULL) +
        tema_irpf(direcao = "x")
    })
    output$direct_plot <- shiny::renderPlot({
      shiny::validate(shiny::need(nrow(bundle$wealth_metrics) > 0L, "Série patrimonial direta não disponível."))
      d <- bundle$wealth_metrics
      d <- d[is.finite(d$gini_grouped), , drop = FALSE]
      shiny::validate(shiny::need(nrow(d) > 0L, "Série patrimonial direta não disponível."))
      # Âncora fixa de 0,70 a 1,00: a série inteira cabe em 0,03 de amplitude, e
      # uma escala ajustada ao dado transformaria estabilidade em penhasco.
      ggplot2::ggplot(d, ggplot2::aes(.data$year, .data$gini_grouped)) +
        ggplot2::geom_line(colour = cor_destaque(1), linewidth = 0.9) +
        ggplot2::geom_point(colour = cor_destaque(1), size = 2) +
        rotular_extremos(d, "year", "gini_grouped", formatar = rotulo_indice(0.001)) +
        escala_ano(d$year) +
        escala_indice(d$gini_grouped, ancora = c(0.70, 1.00), nome = "Gini patrimonial agrupado") +
        ggplot2::labs(x = NULL, caption = "Eixo de 0,70 a 1,00: a série varia menos de 0,03 em dezesseis anos.") +
        tema_irpf(direcao = "y") +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
    })
  })
}
