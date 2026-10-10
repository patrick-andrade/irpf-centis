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
        bslib::card_header(
          class = "cabecalho-com-acao",
          "Dívida média declarada por posição na distribuição de renda",
          shiny::downloadButton(ns("baixar"), "Baixar dados (CSV)", class = "btn-sm botao-baixar")
        ),
        grafico_interativo(ns, "mean_debt", "320px"),
        nota_topo_ordinal(),
        grafico_interativo(ns, "mean_debt_top", "320px")
      ),
      bslib::card(
        bslib::card_header("Razão dívida/renda por posição na distribuição de renda"),
        grafico_interativo(ns, "ratio", "320px"),
        nota_topo_ordinal(),
        grafico_interativo(ns, "ratio_top", "320px")
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

mod_debt_server <- function(id, bundle, estado = NULL, ativo = NULL, inicial = list()) {
  shiny::moduleServer(id, function(input, output, session) {
    slice <- schema_slice(bundle, "wealth_by_bin")
    output$missing <- shiny::renderUI(if (is.null(slice)) data_missing_ui())
    if (is.null(slice)) return(invisible(NULL))
    anos <- as.character(sort(unique(slice$year)))
    escolhas <- escolhas_geografia(bundle, slice$geo_code)
    shiny::updateSelectInput(session, "year", choices = anos, selected = valor_inicial(estado, "ano", anos, max(anos)))
    shiny::updateSelectInput(session, "geo", choices = escolhas, selected = valor_inicial(estado, "geo", escolhas, "BR"))
    sincronizar_estado(session, input, estado, "ano", "year", ativo)
    sincronizar_estado(session, input, estado, "geo", "geo", ativo)

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
    }, alt = function() paste(
      "Linha da dívida média por declaração ao longo dos percentis de renda RB4,",
      geografia_nome(bundle, input$geo), input$year, ". Valores em R$ de 2024."
    ))

    output$mean_debt_top <- shiny::renderPlot({
      d <- base_topo() |> dplyr::filter(is.finite(.data$media))
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem dívidas no topo para a seleção."))
      grafico_topo(
        d, "media",
        escala_dinheiro(c(0, d$media), eixo = "y", nome = "Dívida média por declaração, R$ de 2024")
      )
    }, alt = function() paste(
      "Linha da dívida média nos vinte grupos disjuntos do topo da renda RB4,",
      geografia_nome(bundle, input$geo), input$year, ". Valores em R$ de 2024."
    ))

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
    }, alt = function() paste(
      "Linha da razão entre dívida declarada e renda anual por percentil de renda RB4,",
      geografia_nome(bundle, input$geo), input$year, "."
    ))

    output$ratio_top <- shiny::renderPlot({
      d <- base_topo()
      shiny::validate(shiny::need(any(is.finite(d$debt_income_ratio)), "Sem razão dívida/renda no topo."))
      grafico_topo(
        d, "debt_income_ratio",
        escala_indice(
          c(0, d$debt_income_ratio), span_min = 0.1, nome = "Dívidas declaradas por real de renda anual"
        )
      )
    }, alt = function() paste(
      "Linha da razão entre dívida declarada e renda anual nos vinte grupos do topo da renda RB4,",
      geografia_nome(bundle, input$geo), input$year, ". Cada grupo ocupa a mesma largura."
    ))

    leitura_curva <- function(d, evento, coluna, formatar, descricao) {
      linhas <- linhas_no_ponteiro(d, evento, "share_upper")
      if (nrow(linhas) == 0L || !is.finite(linhas[[coluna]][[1]])) return(leitura_ui(NULL))
      leitura_ui(paste0(
        "Até o percentil ", formatar_percentil(linhas$share_upper[[1]], 1), ": ",
        descricao, " ", formatar(linhas[[coluna]][[1]])
      ))
    }
    leitura_topo <- function(d, evento, coluna, formatar, descricao) {
      linhas <- linhas_no_ponteiro(d, evento, "posicao")
      if (nrow(linhas) == 0L || !is.finite(linhas[[coluna]][[1]])) return(leitura_ui(NULL))
      leitura_ui(paste0(
        "Grupo até o percentil ", linhas$posicao[[1]], ": ", descricao, " ",
        formatar(linhas[[coluna]][[1]])
      ))
    }
    razao <- function(x) scales::number(x, accuracy = 0.01, decimal.mark = ",")

    output$mean_debt_leitura <- shiny::renderUI(leitura_curva(
      base_principal(), evento_ponteiro(input, "mean_debt"), "media",
      rotulo_dinheiro_ptbr(), "dívida média por declaração de"
    ))
    output$mean_debt_top_leitura <- shiny::renderUI(leitura_topo(
      base_topo(), evento_ponteiro(input, "mean_debt_top"), "media",
      rotulo_dinheiro_ptbr(), "dívida média por declaração de"
    ))
    output$ratio_leitura <- shiny::renderUI(leitura_curva(
      base_principal(), evento_ponteiro(input, "ratio"), "debt_income_ratio",
      razao, "dívidas por real de renda anual:"
    ))
    output$ratio_top_leitura <- shiny::renderUI(leitura_topo(
      base_topo(), evento_ponteiro(input, "ratio_top"), "debt_income_ratio",
      razao, "dívidas por real de renda anual:"
    ))

    output$baixar <- shiny::downloadHandler(
      filename = function() paste0("irpf-centis-dividas-", input$geo, "-", input$year, ".csv"),
      content = function(file) {
        d <- selecionado()
        escrever_csv_ptbr(
          data.frame(
            Ano = d$year, Geografia = geografia_nome(bundle, input$geo), Grupo = d$bin_code,
            Percentil_limite_superior = 100 * d$share_upper, Declaracoes = d$contributors,
            Dividas_RS_2024 = d$debts_real, Divida_media_RS_2024 = d$media,
            Participacao_nas_dividas = d$debt_share, Razao_divida_renda = d$debt_income_ratio
          ),
          file
        )
      }
    )

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

    shiny::reactive(list())
  })
}
