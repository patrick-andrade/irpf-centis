mod_debt_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("missing")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        shiny::selectInput(ns("year"), "Ano", choices = NULL),
        shiny::selectInput(ns("geo"), "Geografia", choices = NULL)
      ),
      bslib::card(
        bslib::card_header("Dívida média declarada por posição na distribuição de renda"),
        shiny::plotOutput(ns("mean_debt"), height = "320px"),
        shiny::p(
          class = "small text-muted",
          paste(
            "O último 1% da distribuição reúne 20 grupos divulgados, que na escala",
            "acima ocupariam 1% da largura. Abaixo, cada um recebe a mesma largura."
          )
        ),
        shiny::plotOutput(ns("mean_debt_top"), height = "320px")
      ),
      bslib::card(
        bslib::card_header("Razão dívida/renda por posição na distribuição de renda"),
        shiny::plotOutput(ns("ratio"), height = "320px"),
        shiny::plotOutput(ns("ratio_top"), height = "320px")
      ),
      shiny::uiOutput(ns("rodape")),
      shiny::uiOutput(ns("conceitos"))
    )
  )
}

debt_conceitos_extras <- function() {
  list(
    texto_livre(
      "Estoque contra fluxo",
      paste(
        "Dívidas e ônus são um saldo declarado no encerramento do ano; a renda",
        "é um fluxo de doze meses. A razão entre os dois mede alavancagem",
        "declarada, não capacidade de pagamento nem inadimplência."
      )
    ),
    texto_livre(
      "Ordenação por renda",
      paste(
        "Os grupos são ordenados pela renda (RB4), não pelo endividamento. A",
        "aba mostra como a dívida declarada se distribui ao longo da renda, e",
        "não uma distribuição de devedores."
      )
    ),
    texto_livre(
      "Grupos sem razão definida",
      paste(
        "Onde a renda declarada do grupo é nula — o que ocorre no primeiro",
        "centil de várias geografias — a razão fica indefinida e aparece como",
        "lacuna na linha, nunca como zero."
      )
    )
  )
}

mod_debt_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    slice <- schema_slice(bundle, "wealth_by_bin")
    output$missing <- shiny::renderUI(if (is.null(slice)) data_missing_ui())
    if (is.null(slice)) return(invisible(NULL))
    shiny::updateSelectInput(session, "year", choices = sort(unique(slice$year)), selected = max(slice$year))
    shiny::updateSelectInput(session, "geo", choices = sort(unique(slice$geo_code)), selected = "BR")

    selecionado <- shiny::reactive({
      shiny::req(input$year, input$geo)
      slice |>
        dplyr::filter(
          .data$year == as.integer(input$year), .data$geo_code == input$geo,
          .data$contributors > 0
        ) |>
        dplyr::mutate(media = .data$debts_real / .data$contributors) |>
        dplyr::arrange(.data$share_upper)
    })

    grafico_principal <- function(d, coluna, escala) {
      ggplot2::ggplot(d, ggplot2::aes(.data$share_upper, .data[[coluna]])) +
        ggplot2::annotate(
          "rect", xmin = 0.99, xmax = 1, ymin = -Inf, ymax = Inf,
          fill = cores_irpf$grade, alpha = 0.7
        ) +
        # `na.rm = TRUE` silencia o aviso do ggplot; o buraco na linha continua
        # onde a razão é indefinida, que é a informação a preservar.
        ggplot2::geom_line(colour = cor_destaque(1), linewidth = 0.9, na.rm = TRUE) +
        escala_participacao(
          d$share_upper, eixo = "x", ancora = c(0, 1),
          nome = "Posição na distribuição de renda (limite superior do grupo)"
        ) +
        escala +
        tema_irpf(direcao = "y")
    }

    grafico_topo <- function(d, coluna, escala) {
      ggplot2::ggplot(d, ggplot2::aes(.data$posicao, .data[[coluna]], group = 1)) +
        ggplot2::geom_line(colour = cor_destaque(1), linewidth = 0.9, na.rm = TRUE) +
        ggplot2::geom_point(colour = cor_destaque(1), size = 1.8, na.rm = TRUE) +
        escala +
        ggplot2::labs(x = "Percentil de renda (limite superior de cada grupo)") +
        tema_irpf(direcao = "y") +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 8))
    }

    base_principal <- shiny::reactive({
      selecionado() |> dplyr::filter(.data$bin_code <= 99L, is.finite(.data$media))
    })
    base_topo <- shiny::reactive({
      selecionado() |>
        dplyr::filter(.data$bin_code %in% codigos_topo) |>
        dplyr::mutate(posicao = eixo_ordinal_topo(.data$share_upper))
    })

    output$mean_debt <- shiny::renderPlot({
      d <- base_principal()
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem dívidas por grupo para a seleção."))
      grafico_principal(
        d, "media",
        escala_dinheiro(c(0, d$media), eixo = "y", nome = "Dívida média por declaração, R$ de 2024")
      )
    })

    output$mean_debt_top <- shiny::renderPlot({
      d <- base_topo() |> dplyr::filter(is.finite(.data$media))
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem dívidas no topo para a seleção."))
      grafico_topo(
        d, "media",
        escala_dinheiro(c(0, d$media), eixo = "y", nome = "Dívida média por declaração, R$ de 2024")
      )
    })

    output$ratio <- shiny::renderPlot({
      # A lacuna do primeiro centil é informação: renda declarada nula não é
      # dívida zero. O grupo entra na base e sai da linha como buraco, em vez de
      # ser filtrado e desaparecer do eixo.
      d <- base_principal()
      shiny::validate(shiny::need(any(is.finite(d$debt_income_ratio)), "Sem razão dívida/renda para a seleção."))
      grafico_principal(
        d, "debt_income_ratio",
        escala_indice(
          c(0, d$debt_income_ratio), span_min = 0.1, nome = "Dívidas declaradas por real de renda anual"
        )
      )
    })

    output$ratio_top <- shiny::renderPlot({
      d <- base_topo()
      shiny::validate(shiny::need(any(is.finite(d$debt_income_ratio)), "Sem razão dívida/renda no topo."))
      grafico_topo(
        d, "debt_income_ratio",
        escala_indice(
          c(0, d$debt_income_ratio), span_min = 0.1, nome = "Dívidas declaradas por real de renda anual"
        )
      )
    })

    output$rodape <- shiny::renderUI({
      d <- selecionado()
      topo <- d[is.finite(d$share_lower) & d$share_lower >= 0.99 - 1e-9, , drop = FALSE]
      sem_razao <- sum(!is.finite(d$debt_income_ratio))
      observacoes <- c(
        if (nrow(topo) > 0L) {
          paste0(
            geografia_nome(bundle, input$geo), ", ", input$year, ": o 1% de maior renda ",
            "responde por ", rotulo_percentual(0.1)(sum(topo$debt_share, na.rm = TRUE)),
            " do estoque de dívidas declarado no recorte."
          )
        },
        if (sem_razao > 0L) {
          paste(
            sem_razao, "de", nrow(d),
            "grupos ficam sem razão dívida/renda porque a renda declarada do grupo é nula."
          )
        }
      )
      bloco_rodape(
        notas = c(
          paste(
            "Dívidas e ônus são o saldo declarado no encerramento do ano;",
            "a renda é o fluxo dos doze meses. A razão mede alavancagem",
            "declarada, não capacidade de pagamento."
          ),
          nota_unidade
        ),
        observacoes = observacoes,
        fonte = fonte_receita
      )
    })

    output$conceitos <- shiny::renderUI(
      bloco_conceitos(
        bundle,
        rankings = "RB4",
        indicadores = c("debt_income_ratio", "debt_share"),
        extras = debt_conceitos_extras()
      )
    )
  })
}
