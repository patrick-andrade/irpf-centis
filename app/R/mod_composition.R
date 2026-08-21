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
        shiny::plotOutput(ns("tax_curve"), height = "320px"),
        shiny::p(
          class = "small text-muted",
          paste(
            "O último 1% da distribuição reúne 20 grupos divulgados, que na escala",
            "acima ocupariam 1% da largura. Abaixo, cada um recebe a mesma largura."
          )
        ),
        shiny::plotOutput(ns("tax_curve_top"), height = "320px")
      ),
      shiny::uiOutput(ns("rodape")),
      shiny::uiOutput(ns("conceitos"))
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
      # Barras: o zero é obrigatório, porque o comprimento é a mensagem. A
      # grade útil aqui é a vertical, no eixo do valor.
      ggplot2::ggplot(d, ggplot2::aes(.data$value, stats::reorder(.data$field_label, .data$value))) +
        ggplot2::geom_col(fill = cor_destaque(1), width = 0.72) +
        escala_dinheiro(c(0, d$value), eixo = "x", nome = "Valor declarado em R$ de 2024") +
        ggplot2::labs(y = NULL) +
        tema_irpf(direcao = "x")
    })
    aliquotas <- shiny::reactive({
      shiny::req(input$year, input$geo)
      bundle$effective_tax |>
        dplyr::filter(
          .data$year == as.integer(input$year), .data$geo_code == input$geo,
          is.finite(.data$effective_rate)
        ) |>
        dplyr::arrange(.data$share_upper)
    })

    output$tax_curve <- shiny::renderPlot({
      shiny::validate(shiny::need(nrow(bundle$effective_tax) > 0L, "Alíquotas efetivas não disponíveis."))
      d <- aliquotas() |> dplyr::filter(.data$bin_code <= 99L)
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem alíquotas para a seleção."))
      ggplot2::ggplot(d, ggplot2::aes(.data$share_upper, .data$effective_rate)) +
        ggplot2::annotate(
          "rect", xmin = 0.99, xmax = 1, ymin = -Inf, ymax = Inf,
          fill = cores_irpf$grade, alpha = 0.7
        ) +
        ggplot2::geom_line(colour = cor_destaque(1), linewidth = 0.9) +
        escala_participacao(
          d$share_upper, eixo = "x", ancora = c(0, 1),
          nome = "Posição na distribuição (limite superior do grupo)"
        ) +
        escala_aliquota(d$effective_rate, nome = "Alíquota efetiva média") +
        linha_zero("h") +
        tema_irpf(direcao = "y")
    })

    # Detalhe do topo em eixo ordinal: é onde a alíquota cai, e em escala de
    # percentil os 20 grupos ficariam comprimidos em 1% da largura.
    output$tax_curve_top <- shiny::renderPlot({
      shiny::validate(shiny::need(nrow(bundle$effective_tax) > 0L, "Alíquotas efetivas não disponíveis."))
      d <- aliquotas() |>
        dplyr::filter(.data$bin_code %in% codigos_topo) |>
        dplyr::mutate(posicao = eixo_ordinal_topo(.data$share_upper))
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem alíquotas no topo para a seleção."))
      extremos <- d[c(which.max(d$effective_rate), which.max(d$share_upper)), ]
      ggplot2::ggplot(d, ggplot2::aes(.data$posicao, .data$effective_rate, group = 1)) +
        ggplot2::geom_line(colour = cor_destaque(1), linewidth = 0.9) +
        ggplot2::geom_point(colour = cor_destaque(1), size = 1.8) +
        ggplot2::geom_text(
          data = extremos,
          mapping = ggplot2::aes(label = rotulo_percentual(0.1)(.data$effective_rate)),
          vjust = -1.1, size = 3.2, colour = cores_irpf$tinta
        ) +
        escala_aliquota(d$effective_rate, nome = "Alíquota efetiva média") +
        linha_zero("h") +
        ggplot2::labs(x = "Percentil de renda (limite superior de cada grupo)") +
        tema_irpf(direcao = "y") +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 8))
    })

    output$rodape <- shiny::renderUI(bloco_rodape(
      notas = c(
        paste(
          "Os valores são somas declaradas em cada grupo, em R$ de 2024;",
          "ausência de campo na fonte não é convertida em zero."
        ),
        paste(
          "A alíquota efetiva média divide o imposto devido pela renda ampla",
          "declarada (RB4), e não pela base de cálculo legal."
        )
      ),
      fonte = fonte_receita
    ))

    output$conceitos <- shiny::renderUI(
      bloco_conceitos(
        bundle,
        rankings = "RB4",
        indicadores = "effective_rate",
        extras = list(texto_livre(
          "Grupos de campos",
          paste(
            "Tributáveis, exclusivos, isentos, deduções e imposto são os grupos",
            "semânticos dos campos divulgados pela Receita. Somá-los entre si",
            "duplicaria rendimentos que já entram no conceito de ordenação."
          )
        ))
      )
    )
  })
}
