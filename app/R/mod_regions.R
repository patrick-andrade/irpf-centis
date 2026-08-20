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
    nomes_uf <- bundle$geographies |>
      dplyr::filter(.data$geo_level == "state") |>
      dplyr::select("geo_code", "geo_name")

    selected <- shiny::reactive({
      bundle$metrics |>
        dplyr::filter(.data$year == as.integer(input$year), .data$geo_level == "state", .data$ranking_id == "RB4") |>
        dplyr::left_join(nomes_uf, by = "geo_code") |>
        dplyr::transmute(
          UF = .data$geo_code,
          # Nome por extenso: "AC" e "RO" não são leitura de público geral.
          `Unidade da Federação` = dplyr::coalesce(.data$geo_name, .data$geo_code),
          Indicador = .data[[input$metric]],
          Declarantes = .data$contributors
        ) |>
        dplyr::filter(is.finite(.data$Indicador)) |>
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
      # Escala em classes, não contínua: com um outlier estadual — Wolfson chega
      # a 4,5 em algumas UFs — a escala contínua colapsaria o contraste das
      # outras 26 para acomodar uma só, e a legenda contínua não declara limite
      # de classe nenhum.
      rotular <- if (grepl("share$", input$metric)) rotulo_percentual(0.1) else rotulo_indice(0.01)
      ggplot2::ggplot(poly, ggplot2::aes(.data$long, .data$lat, group = .data$piece, fill = .data$Indicador)) +
        ggplot2::geom_polygon(colour = "white", linewidth = 0.2) +
        ggplot2::coord_quickmap() +
        escala_mapa_classes(indicators$Indicador, nome = NULL, rotular = rotular) +
        ggplot2::labs(caption = "Fonte da malha: IBGE. Indicadores calculados dentro de cada UF.") +
        ggplot2::theme_void(base_size = 11) +
        ggplot2::theme(
          legend.position = "bottom",
          plot.background = ggplot2::element_rect(fill = cores_irpf$fundo, colour = NA),
          plot.caption = ggplot2::element_text(
            size = 8.5, colour = cores_irpf$texto_suave, hjust = 0
          )
        )
    })
    output$plot <- shiny::renderPlot({
      d <- selected()
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem dados estaduais."))
      rotulo <- names(metric_choices)[match(input$metric, metric_choices)]
      escala_x <- if (grepl("share$", input$metric)) {
        escala_participacao(d$Indicador, eixo = "x", nome = rotulo)
      } else {
        # Barras codificam comprimento: o zero entra mesmo para índices.
        escala_indice(c(0, d$Indicador), eixo = "x", span_min = 0, nome = rotulo)
      }
      ggplot2::ggplot(d, ggplot2::aes(.data$Indicador, stats::reorder(.data$`Unidade da Federação`, .data$Indicador))) +
        ggplot2::geom_col(fill = cor_destaque(1), width = 0.72) +
        escala_x +
        ggplot2::labs(y = NULL, caption = "Centis calculados separadamente dentro de cada UF.") +
        tema_irpf(direcao = "x") +
        ggplot2::theme(axis.text.y = ggplot2::element_text(size = 8.5))
    })
    output$table <- shiny::renderTable(
      {
        d <- selected()
        # renderTable formata com as convenções do inglês e com casas decimais
        # em contagens; aqui os números saem prontos, no padrão do restante do
        # painel.
        d$Indicador <- format_metric(d$Indicador, input$metric)
        d$Declarantes <- rotulo_contagem()(d$Declarantes)
        d$UF <- NULL
        names(d)[names(d) == "Indicador"] <-
          names(metric_choices)[match(input$metric, metric_choices)]
        d
      },
      striped = TRUE, hover = TRUE, align = "lrr"
    )
  })
}
