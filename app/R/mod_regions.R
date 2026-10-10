mod_regions_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("missing")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        shiny::selectInput(ns("year"), "Ano", choices = NULL),
        shiny::selectInput(ns("metric"), "Indicador", choices = metric_choices),
        shiny::uiOutput(ns("definicao_indicador")),
        shiny::selectInput(
          ns("ordem"), "Ordenar UFs por",
          choices = c("Valor do indicador" = "valor", "Nome" = "nome", "Região" = "regiao")
        )
      ),
      bslib::card(
        bslib::card_header(
          class = "cabecalho-com-acao",
          "Comparação entre UFs",
          shiny::downloadButton(ns("baixar"), "Baixar dados (CSV)", class = "btn-sm botao-baixar")
        ),
        bslib::layout_columns(
          col_widths = bslib::breakpoints(sm = 12, lg = c(7, 5)),
          shiny::plotOutput(ns("map"), height = "520px"),
          shiny::plotOutput(ns("plot"), height = "520px")
        ),
        shiny::tableOutput(ns("table"))
      ),
      shiny::uiOutput(ns("rodape")),
      shiny::uiOutput(ns("conceitos"))
    )
  )
}

mod_regions_server <- function(id, bundle, estado = NULL, ativo = NULL, inicial = list()) {
  shiny::moduleServer(id, function(input, output, session) {
    output$missing <- shiny::renderUI(if (!bundle_has_data(bundle)) data_missing_ui())
    if (!bundle_has_data(bundle)) return(invisible(NULL))
    anos <- as.character(sort(unique(bundle$metrics$year)))
    shiny::updateSelectInput(session, "year", choices = anos, selected = valor_inicial(estado, "ano", anos, max(anos)))
    if (!is.null(inicial$ind)) shiny::updateSelectInput(session, "metric", selected = inicial$ind)
    if (!is.null(inicial$ordem)) shiny::updateSelectInput(session, "ordem", selected = inicial$ordem)
    sincronizar_estado(session, input, estado, "ano", "year", ativo)

    colunas_uf <- intersect(c("geo_code", "geo_name", "region_name"), names(bundle$geographies))
    nomes_uf <- bundle$geographies[bundle$geographies$geo_level == "state", colunas_uf, drop = FALSE]
    rotulo_metrica <- shiny::reactive(names(metric_choices)[match(input$metric, metric_choices)])

    selected <- shiny::reactive({
      shiny::req(input$year, input$metric)
      d <- bundle$metrics |>
        dplyr::filter(.data$year == as.integer(input$year), .data$geo_level == "state", .data$ranking_id == "RB4") |>
        dplyr::left_join(nomes_uf, by = "geo_code")
      regiao <- if ("region_name" %in% names(d)) d$region_name else rep(NA_character_, nrow(d))
      d <- data.frame(
        UF = d$geo_code,
        # Nome por extenso: "AC" e "RO" não são leitura de público geral.
        `Unidade da Federação` = dplyr::coalesce(d$geo_name, d$geo_code),
        `Região` = dplyr::coalesce(regiao, ""),
        Indicador = d[[input$metric]],
        Declarantes = d$contributors,
        check.names = FALSE
      )
      d <- d[is.finite(d$Indicador), , drop = FALSE]
      # A ordem escolhida vale para as barras e para a tabela.
      ordem <- switch(
        input$ordem %||% "valor",
        nome = order(sem_acento(d$`Unidade da Federação`)),
        regiao = order(sem_acento(d$`Região`), -d$Indicador),
        order(-d$Indicador)
      )
      d[ordem, , drop = FALSE]
    })

    output$definicao_indicador <- shiny::renderUI({
      item <- texto_indicador(bundle, input$metric)
      definicao_curta(if (is.null(item)) NULL else item$resumo)
    })

    output$map <- shiny::renderPlot({
      exigir_largura(session, "map")
      shiny::validate(shiny::need(nrow(bundle$state_polygons) > 0L, "Malha estadual não disponível."))
      keys <- bundle$geographies |>
        dplyr::filter(.data$geo_level == "state") |>
        dplyr::transmute(codarea = as.character(.data$ibge_code), UF = .data$geo_code)
      poly <- bundle$state_polygons
      poly$UF <- keys$UF[match(poly$codarea, keys$codarea)]
      indicators <- selected()
      poly$Indicador <- indicators$Indicador[match(poly$UF, indicators$UF)]
      # Escala em classes: valores estaduais extremos podem dominar uma escala
      # contínua e esconder o contraste entre as demais UFs.
      rotular <- if (grepl("share$", input$metric)) rotulo_percentual(0.1) else rotulo_indice(0.01)
      mapa <- ggplot2::ggplot(poly, ggplot2::aes(.data$long, .data$lat)) +
        ggplot2::geom_polygon(
          ggplot2::aes(group = .data$piece, fill = .data$Indicador),
          colour = "white", linewidth = 0.2
        )
      # Siglas sobre fundo claro: sem elas, o mapa só se lê pela cor, e a cor
      # sozinha não identifica a UF para quem não conhece o contorno.
      rotulos <- schema_slice(bundle, "state_labels")
      if (!is.null(rotulos)) {
        rotulos$UF <- keys$UF[match(as.character(rotulos$codarea), keys$codarea)]
        rotulos <- rotulos[!is.na(rotulos$UF), , drop = FALSE]
        mapa <- mapa + ggplot2::geom_label(
          data = rotulos, ggplot2::aes(.data$long, .data$lat, label = .data$UF),
          inherit.aes = FALSE, size = 2.5, linewidth = 0, label.padding = grid::unit(0.1, "lines"),
          fill = grDevices::adjustcolor("white", alpha.f = 0.75), colour = cores_irpf$tinta
        )
      }
      mapa +
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
    }, alt = function() paste(
      "Mapa das unidades da Federação, com as siglas, por", rotulo_metrica(), "em", input$year,
      ". Os mesmos valores aparecem na tabela abaixo do mapa."
    ))

    output$plot <- shiny::renderPlot({
      exigir_largura(session, "plot")
      d <- selected()
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem dados estaduais."))
      escala_x <- if (grepl("share$", input$metric)) {
        escala_participacao(d$Indicador, eixo = "x", nome = rotulo_metrica())
      } else {
        # Barras codificam comprimento: o zero entra mesmo para índices.
        escala_indice(c(0, d$Indicador), eixo = "x", span_min = 0, nome = rotulo_metrica())
      }
      # A primeira linha da ordem escolhida fica no alto do gráfico.
      d$nome <- factor(d$`Unidade da Federação`, levels = rev(d$`Unidade da Federação`))
      ggplot2::ggplot(d, ggplot2::aes(.data$Indicador, .data$nome)) +
        ggplot2::geom_col(fill = cor_destaque(1), width = 0.72) +
        escala_x +
        ggplot2::labs(y = NULL, caption = "Centis calculados separadamente dentro de cada UF.") +
        tema_irpf(direcao = "x") +
        ggplot2::theme(axis.text.y = ggplot2::element_text(size = 9))
    }, alt = function() paste(
      "Barras horizontais com as unidades da Federação por", rotulo_metrica(), "em", input$year,
      ". Os valores exatos aparecem na tabela abaixo."
    ))

    output$table <- shiny::renderTable(
      {
        d <- selected()
        # renderTable formata com as convenções do inglês e com casas decimais
        # em contagens; aqui os números saem prontos, no padrão do restante do
        # painel.
        d$Indicador <- format_metric(d$Indicador, input$metric)
        d$Declarantes <- rotulo_contagem()(d$Declarantes)
        d$UF <- NULL
        names(d)[names(d) == "Indicador"] <- rotulo_metrica()
        d
      },
      striped = TRUE, hover = TRUE, align = "llrr"
    )

    output$baixar <- shiny::downloadHandler(
      filename = function() paste0("irpf-centis-ufs-", input$metric, "-", input$year, ".csv"),
      content = function(file) {
        d <- selected()
        names(d)[names(d) == "Indicador"] <- rotulo_metrica()
        escrever_csv_ptbr(cbind(Ano = input$year, d), file)
      }
    )

    output$rodape <- shiny::renderUI({
      shiny::req(input$year, input$metric)
      saltos <- if (as.integer(input$year) == 2018L) {
        geografias_salto_2018(bundle$metrics, "RB4", input$metric, geos = unique(nomes_uf$geo_code))
      } else {
        character()
      }
      nota_2018 <- if (length(saltos) > 0L) {
        paste0(
          "Em 2018, ", juntar_nomes(bundle, saltos),
          " destoa", if (length(saltos) > 1L) "m" else "", " dos anos vizinhos por causa de um único ",
          "grupo do topo no arquivo oficial; o mapa desse ano é dominado por esse efeito."
        )
      }
      bloco_rodape(
        notas = c(
          paste(
            "Cada UF é ordenada separadamente pela Receita: o centil 90 de uma UF",
            "não tem o mesmo limite monetário do centil 90 de outra. O mapa compara",
            "indicadores calculados dentro de cada UF, não centis nacionais."
          ),
          nota_2018
        ),
        fonte = c(
          fonte_receita,
          "Malha estadual: IBGE."
        )
      )
    })

    output$conceitos <- shiny::renderUI(
      bloco_conceitos(bundle, rankings = "RB4", indicadores = input$metric)
    )

    shiny::reactive(list(ind = input$metric, ordem = if (!identical(input$ordem, "valor")) input$ordem))
  })
}
