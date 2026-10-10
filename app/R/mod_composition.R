mod_composition_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("missing")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        shiny::selectInput(ns("year"), "Ano", choices = NULL),
        shiny::selectInput(ns("geo"), "Geografia", choices = NULL),
        shiny::selectInput(ns("group"), "Grupo de campos", choices = grupos_de_campos)
      ),
      bslib::card(
        bslib::card_header("Composição declarada"),
        shiny::plotOutput(ns("plot"), height = "440px")
      ),
      bslib::card(
        bslib::card_header(
          class = "cabecalho-com-acao",
          "Alíquota efetiva média por posição na distribuição",
          shiny::downloadButton(ns("baixar"), "Baixar dados (CSV)", class = "btn-sm botao-baixar")
        ),
        shiny::p(class = "small text-muted", "Imposto devido dividido pela renda RB4 de cada grupo; média com dados agrupados, sem variação interna aos grupos."),
        grafico_interativo(ns, "tax_curve", "320px"),
        nota_topo_ordinal(),
        grafico_interativo(ns, "tax_curve_top", "320px")
      ),
      shiny::uiOutput(ns("rodape")),
      shiny::uiOutput(ns("conceitos"))
    )
  )
}

mod_composition_server <- function(id, bundle, estado = NULL, ativo = NULL, inicial = list()) {
  shiny::moduleServer(id, function(input, output, session) {
    output$missing <- shiny::renderUI(if (nrow(bundle$income_components) == 0L) data_missing_ui())
    if (nrow(bundle$income_components) == 0L) return(invisible(NULL))
    anos <- as.character(sort(unique(bundle$income_components$year)))
    escolhas <- escolhas_geografia(bundle, bundle$income_components$geo_code)
    shiny::updateSelectInput(session, "year", choices = anos, selected = valor_inicial(estado, "ano", anos, max(anos)))
    shiny::updateSelectInput(session, "geo", choices = escolhas, selected = valor_inicial(estado, "geo", escolhas, "BR"))
    if (!is.null(inicial$grupo)) shiny::updateSelectInput(session, "group", selected = inicial$grupo)
    sincronizar_estado(session, input, estado, "ano", "year", ativo)
    sincronizar_estado(session, input, estado, "geo", "geo", ativo)
    output$plot <- shiny::renderPlot({
      exigir_largura(session, "plot")
      shiny::req(input$year, input$geo, input$group)
      d <- bundle$income_components |>
        dplyr::filter(
          .data$year == as.integer(input$year), .data$geo_code == input$geo,
          .data$ranking_id == "RB4", .data$component_group == input$group
        ) |>
        component_totals()
      missing_count <- sum(is.na(d$value))
      d <- d |>
        dplyr::filter(is.finite(.data$value)) |>
        dplyr::slice_max(.data$value, n = 12, with_ties = FALSE) |>
        dplyr::arrange(.data$value)
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem valores de componentes divulgados para a seleção."))
      # Barras: o zero é obrigatório, porque o comprimento é a mensagem. A
      # grade útil aqui é a vertical, no eixo do valor.
      ggplot2::ggplot(d, ggplot2::aes(.data$value, stats::reorder(.data$field_label, .data$value))) +
        ggplot2::geom_col(fill = cor_destaque(1), width = 0.72) +
        escala_dinheiro(c(0, d$value), eixo = "x", nome = "Valor declarado em R$ de 2024") +
        ggplot2::labs(
          y = NULL,
          caption = if (missing_count > 0L) paste(missing_count, "campo(s) sem valor divulgado fora do gráfico") else NULL
        ) +
        tema_irpf(direcao = "x")
    }, alt = function() paste(
      "Barras horizontais dos componentes declarados em R$ de 2024 para",
      geografia_nome(bundle, input$geo), "em", input$year, ". O grupo de campos é",
      c(taxable = "tributáveis", exclusive = "exclusivos", exempt = "isentos",
        deduction = "deduções", tax = "imposto")[[input$group]], "."
    ))
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
      exigir_largura(session, "tax_curve")
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
    }, alt = function() paste(
      "Linha da alíquota efetiva média por posição na distribuição da renda RB4,",
      geografia_nome(bundle, input$geo), input$year, ". O eixo horizontal vai do percentil 1 ao 99."
    ))

    # Detalhe do topo em eixo ordinal: é onde a alíquota cai, e em escala de
    # percentil os 20 grupos ficariam comprimidos em 1% da largura.
    output$tax_curve_top <- shiny::renderPlot({
      exigir_largura(session, "tax_curve_top")
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
    }, alt = function() paste(
      "Linha da alíquota efetiva média nos vinte grupos disjuntos do topo da renda RB4,",
      geografia_nome(bundle, input$geo), input$year, ". Cada grupo ocupa a mesma largura."
    ))

    output$tax_curve_leitura <- shiny::renderUI({
      d <- aliquotas() |> dplyr::filter(.data$bin_code <= 99L)
      linhas <- linhas_no_ponteiro(d, evento_ponteiro(input, "tax_curve"), "share_upper")
      if (nrow(linhas) == 0L) return(leitura_ui(NULL))
      leitura_ui(paste0(
        "Até o percentil ", formatar_percentil(linhas$share_upper[[1]], 1), ": alíquota efetiva média de ",
        rotulo_percentual(0.1)(linhas$effective_rate[[1]])
      ))
    })

    output$tax_curve_top_leitura <- shiny::renderUI({
      d <- aliquotas() |>
        dplyr::filter(.data$bin_code %in% codigos_topo) |>
        dplyr::mutate(posicao = eixo_ordinal_topo(.data$share_upper))
      linhas <- linhas_no_ponteiro(d, evento_ponteiro(input, "tax_curve_top"), "posicao")
      if (nrow(linhas) == 0L) return(leitura_ui(NULL))
      leitura_ui(paste0(
        "Grupo até o percentil ", linhas$posicao[[1]], ": alíquota efetiva média de ",
        rotulo_percentual(0.1)(linhas$effective_rate[[1]])
      ))
    })

    output$baixar <- shiny::downloadHandler(
      filename = function() paste0("irpf-centis-aliquota-efetiva-", input$geo, "-", input$year, ".csv"),
      content = function(file) {
        d <- aliquotas()
        escrever_csv_ptbr(
          data.frame(
            Ano = d$year, Geografia = geografia_nome(bundle, input$geo),
            Grupo = d$bin_code, Percentil_limite_superior = 100 * d$share_upper,
            Aliquota_efetiva_media = d$effective_rate
          ),
          file
        )
      }
    )

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

    shiny::reactive(list(grupo = input$group))
  })
}
