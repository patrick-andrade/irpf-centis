mod_assets_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("missing")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        shiny::selectInput(ns("year"), "Ano", choices = NULL),
        shiny::selectInput(ns("geo"), "Geografia", choices = NULL)
      ),
      bslib::card(
        bslib::card_header("Composição dos bens e direitos declarados"),
        shiny::plotOutput(ns("plot"), height = "400px")
      ),
      bslib::card(
        bslib::card_header("Patrimônio médio por posição na distribuição de renda"),
        shiny::plotOutput(ns("concentration"), height = "320px"),
        shiny::p(
          class = "small text-muted",
          paste(
            "O último 1% da distribuição reúne 20 grupos divulgados, que na escala",
            "acima ocupariam 1% da largura. Abaixo, cada um recebe a mesma largura."
          )
        ),
        shiny::plotOutput(ns("concentration_top"), height = "320px")
      ),
      bslib::card(
        bslib::card_header("Desigualdade patrimonial — ordenação direta nacional"),
        shiny::plotOutput(ns("direct_plot"), height = "360px")
      ),
      shiny::uiOutput(ns("rodape")),
      shiny::uiOutput(ns("conceitos"))
    )
  )
}

assets_conceitos_extras <- function() {
  list(
    texto_livre(
      "Bens dentro dos centis de renda",
      paste(
        "Os dois primeiros gráficos observam o patrimônio declarado dentro de",
        "grupos ordenados por renda (RB4). Medem concentração patrimonial ao",
        "longo da distribuição de renda."
      )
    ),
    texto_livre(
      "Ordenação direta nacional",
      paste(
        "O último gráfico ordena as declarações diretamente pelo valor dos bens",
        "e direitos, na série nacional de 2006 a 2021 da Tabela III. É a única",
        "leitura que o projeto chama de desigualdade patrimonial."
      ),
      paste(
        "A série inclui o grupo com patrimônio declarado igual a zero, que",
        "responde por parcela expressiva das declarações e puxa o índice para",
        "perto de 1."
      )
    )
  )
}

mod_assets_server <- function(id, bundle) {
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
          .data$ranking_id == "RB4", .data$component_group == "asset",
          .data$component_id %in% c("assets_real_estate", "assets_movable", "assets_financial", "assets_other")
        ) |>
        dplyr::group_by(.data$component_id, .data$field_label) |>
        dplyr::summarise(value = sum(.data$value_real, na.rm = TRUE), .groups = "drop")
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem dados patrimoniais para a seleção."))
      # Barras horizontais: dispensam rótulo inclinado e o comprimento fica
      # comparável numa linha de base comum.
      ggplot2::ggplot(d, ggplot2::aes(.data$value, stats::reorder(.data$field_label, .data$value))) +
        ggplot2::geom_col(fill = cor_destaque(1), width = 0.72) +
        escala_dinheiro(c(0, d$value), eixo = "x", nome = "Valor declarado em R$ de 2024") +
        ggplot2::labs(y = NULL) +
        tema_irpf(direcao = "x")
    })

    patrimonio <- shiny::reactive({
      slice <- schema_slice(bundle, "wealth_by_bin")
      shiny::req(slice, input$year, input$geo)
      slice |>
        dplyr::filter(
          .data$year == as.integer(input$year), .data$geo_code == input$geo,
          is.finite(.data$assets_sum_real), .data$contributors > 0
        ) |>
        dplyr::mutate(media = .data$assets_sum_real / .data$contributors) |>
        dplyr::arrange(.data$share_upper)
    })

    output$concentration <- shiny::renderPlot({
      shiny::validate(shiny::need(!is.null(schema_slice(bundle, "wealth_by_bin")), "Patrimônio por grupo não disponível."))
      d <- patrimonio() |> dplyr::filter(.data$bin_code <= 99L)
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem patrimônio por grupo para a seleção."))
      ggplot2::ggplot(d, ggplot2::aes(.data$share_upper, .data$media)) +
        ggplot2::annotate(
          "rect", xmin = 0.99, xmax = 1, ymin = -Inf, ymax = Inf,
          fill = cores_irpf$grade, alpha = 0.7
        ) +
        ggplot2::geom_line(colour = cor_destaque(1), linewidth = 0.9) +
        escala_participacao(
          d$share_upper, eixo = "x", ancora = c(0, 1),
          nome = "Posição na distribuição de renda (limite superior do grupo)"
        ) +
        escala_dinheiro(c(0, d$media), eixo = "y", nome = "Patrimônio médio por declaração, R$ de 2024") +
        tema_irpf(direcao = "y")
    })

    # Detalhe do topo em eixo ordinal: é onde o patrimônio médio dispara, e em
    # escala de percentil os 20 grupos ficariam comprimidos em 1% da largura.
    output$concentration_top <- shiny::renderPlot({
      shiny::validate(shiny::need(!is.null(schema_slice(bundle, "wealth_by_bin")), "Patrimônio por grupo não disponível."))
      d <- patrimonio() |>
        dplyr::filter(.data$bin_code %in% codigos_topo) |>
        dplyr::mutate(posicao = eixo_ordinal_topo(.data$share_upper))
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem patrimônio no topo para a seleção."))
      ggplot2::ggplot(d, ggplot2::aes(.data$posicao, .data$media, group = 1)) +
        ggplot2::geom_line(colour = cor_destaque(1), linewidth = 0.9) +
        ggplot2::geom_point(colour = cor_destaque(1), size = 1.8) +
        escala_dinheiro(c(0, d$media), eixo = "y", nome = "Patrimônio médio por declaração, R$ de 2024") +
        ggplot2::labs(x = "Percentil de renda (limite superior de cada grupo)") +
        tema_irpf(direcao = "y") +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 8))
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

    output$rodape <- shiny::renderUI({
      slice <- schema_slice(bundle, "wealth_by_bin")
      observacao <- NULL
      if (!is.null(slice) && !is.null(input$year) && !is.null(input$geo)) {
        d <- slice |>
          dplyr::filter(
            .data$year == as.integer(input$year), .data$geo_code == input$geo,
            .data$share_lower >= 0.99 - 1e-9
          )
        if (nrow(d) > 0L) {
          observacao <- paste0(
            geografia_nome(bundle, input$geo), ", ", input$year, ": o 1% de maior renda ",
            "declara ", rotulo_percentual(0.1)(sum(d$assets_share, na.rm = TRUE)),
            " do patrimônio total do recorte."
          )
        }
      }
      bloco_rodape(
        notas = c(
          paste(
            "Valores de bens declarados seguem regras fiscais de avaliação e não",
            "equivalem necessariamente a preços de mercado."
          ),
          paste(
            "O total consolidado de bens só é divulgado a partir de 2022; a série",
            "usa a soma dos quatro grupos divulgados, conferida contra o total",
            "nos anos em que ele existe."
          )
        ),
        observacoes = observacao,
        fonte = fonte_receita
      )
    })

    output$conceitos <- shiny::renderUI(
      bloco_conceitos(
        bundle,
        rankings = "RB4",
        indicadores = c("assets_sum_real", "wealth_gini_direct"),
        extras = assets_conceitos_extras()
      )
    )
  })
}
