mod_evolution_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("missing")),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        shiny::selectizeInput(
          ns("geo"), "Geografias (até 3)", choices = NULL, multiple = TRUE,
          options = list(maxItems = 3, plugins = list("remove_button"))
        ),
        shiny::selectInput(ns("ranking"), "Conceito de renda", choices = NULL),
        shiny::uiOutput(ns("definicao_conceito")),
        shiny::selectInput(ns("metric"), "Indicador", choices = metric_choices),
        shiny::uiOutput(ns("definicao_indicador")),
        shiny::checkboxInput(ns("sem_topo"), "Comparar com a série sem o top 0,01%", FALSE)
      ),
      bslib::card(
        bslib::card_header(
          class = "cabecalho-com-acao",
          shiny::textOutput(ns("title"), inline = TRUE),
          shiny::downloadButton(ns("baixar"), "Baixar dados (CSV)", class = "btn-sm botao-baixar")
        ),
        # navset_underline dentro do card, e não navset_card_underline: este
        # marca cada painel como contêiner de preenchimento e anula a altura
        # declarada do gráfico.
        bslib::navset_underline(
          bslib::nav_panel("Gráfico", grafico_interativo(ns, "plot", "520px")),
          bslib::nav_panel("Tabela", shiny::tableOutput(ns("tabela")))
        )
      ),
      shiny::uiOutput(ns("rodape")),
      shiny::uiOutput(ns("conceitos"))
    )
  )
}

serie_todos <- "Todos os grupos"
serie_sem_topo <- "Sem o top 0,01%"

mod_evolution_server <- function(id, bundle, estado = NULL, ativo = NULL, inicial = list()) {
  shiny::moduleServer(id, function(input, output, session) {
    output$missing <- shiny::renderUI(if (!bundle_has_data(bundle)) data_missing_ui())
    if (!bundle_has_data(bundle)) return(invisible(NULL))

    escolhas <- escolhas_geografia(bundle, bundle$metrics$geo_code)
    geo_inicial <- unique(c(
      valor_inicial(estado, "geo", escolhas, "BR"),
      intersect(inicial$comparar, escolhas)
    ))
    shiny::updateSelectizeInput(session, "geo", choices = escolhas, selected = geo_inicial)
    rankings <- unique(bundle$metrics$ranking_id)
    shiny::updateSelectInput(
      session, "ranking",
      choices = stats::setNames(rankings, vapply(rankings, \(x) ranking_label(bundle, x), character(1))),
      selected = inicial$conceito %||% "RB4"
    )
    if (!is.null(inicial$ind)) shiny::updateSelectInput(session, "metric", selected = inicial$ind)
    if (isTRUE(inicial$sem_topo)) shiny::updateCheckboxInput(session, "sem_topo", value = TRUE)
    sincronizar_estado(session, input, estado, "geo", ativo = ativo, primeiro = TRUE)

    rotulo_metrica <- shiny::reactive(names(metric_choices)[match(input$metric, metric_choices)])
    sem_topo_disponivel <- shiny::reactive({
      variante <- schema_slice(bundle, "metrics_sem_topo")
      !is.null(variante) && input$metric %in% names(variante)
    })

    selected <- shiny::reactive({
      shiny::req(input$geo, input$ranking, input$metric)
      montar <- function(tabela, serie) {
        base <- tabela[
          tabela$geo_code %in% input$geo & tabela$ranking_id == input$ranking, ,
          drop = FALSE
        ]
        if (nrow(base) == 0L) return(NULL)
        data.frame(
          geo_code = base$geo_code,
          year = as.integer(base$year),
          valor = base[[input$metric]],
          serie = serie,
          inferior = if ("gini_lower_bound" %in% names(base)) base$gini_lower_bound else NA_real_,
          superior = if ("gini_upper_bound" %in% names(base)) base$gini_upper_bound else NA_real_
        )
      }
      partes <- list(montar(bundle$metrics, serie_todos))
      if (isTRUE(input$sem_topo) && sem_topo_disponivel()) {
        partes <- c(partes, list(montar(bundle$metrics_sem_topo, serie_sem_topo)))
      }
      d <- do.call(rbind, Filter(Negate(is.null), partes))
      if (is.null(d)) return(data.frame())
      d <- d[is.finite(d$valor), , drop = FALSE]
      nomes <- vapply(input$geo, function(codigo) geografia_nome(bundle, codigo), character(1))
      d$geografia <- factor(unname(nomes[d$geo_code]), levels = unname(nomes))
      d$serie <- factor(d$serie, levels = c(serie_todos, serie_sem_topo))
      d[order(d$geografia, d$serie, d$year), , drop = FALSE]
    })

    output$definicao_indicador <- shiny::renderUI({
      item <- texto_indicador(bundle, input$metric)
      definicao_curta(if (is.null(item)) NULL else item$resumo)
    })
    output$definicao_conceito <- shiny::renderUI({
      shiny::req(input$ranking)
      item <- texto_conceito(bundle, input$ranking)
      definicao_curta(if (is.null(item)) NULL else item$resumo)
    })

    output$title <- shiny::renderText({
      nomes <- vapply(input$geo, function(codigo) geografia_nome(bundle, codigo), character(1))
      paste(rotulo_metrica(), "—", paste(nomes, collapse = ", "))
    })

    formatar <- shiny::reactive({
      if (grepl("share$", input$metric)) rotulo_percentual(0.1) else rotulo_indice(0.001)
    })

    output$plot <- shiny::renderPlot({
      d <- selected()
      shiny::validate(shiny::need(nrow(d) > 0L, "Indicador não definido para a seleção."))
      varias <- nlevels(droplevels(d$geografia)) > 1L
      duas_series <- nlevels(droplevels(d$serie)) > 1L

      # Participações partem do zero; índices ganham amplitude mínima para que
      # uma variação pequena não ocupe a altura inteira do painel.
      escala_y <- if (grepl("share$", input$metric)) {
        escala_participacao(d$valor, nome = rotulo_metrica())
      } else {
        escala_indice(d$valor, nome = rotulo_metrica())
      }
      geografias <- levels(droplevels(d$geografia))
      completa <- d[d$serie == serie_todos, , drop = FALSE]

      grafico <- ggplot2::ggplot(
        d,
        ggplot2::aes(
          .data$year, .data$valor, colour = .data$geografia, linetype = .data$serie,
          group = interaction(.data$geografia, .data$serie)
        )
      ) +
        marcar_ano_ressalva(d$year) +
        ggplot2::geom_line(linewidth = 1) +
        ggplot2::geom_point(size = 2.4) +
        escala_ano(d$year) +
        escala_y +
        ggplot2::scale_colour_manual(
          values = stats::setNames(cor_destaque(length(geografias)), geografias),
          guide = "none"
        ) +
        ggplot2::scale_linetype_manual(
          name = NULL,
          values = stats::setNames(c("solid", "22"), c(serie_todos, serie_sem_topo)),
          guide = if (duas_series) "legend" else "none"
        ) +
        ggplot2::coord_cartesian(clip = "off") +
        ggplot2::labs(x = NULL) +
        tema_irpf(base_size = 13, direcao = "y")

      # Uma geografia: primeiro e último valor rotulados. Várias: o nome no fim
      # de cada linha, que dispensa legenda de cor.
      if (varias) {
        grafico +
          rotular_series_no_fim(completa, "year", "valor", "geografia") +
          ggplot2::theme(plot.margin = ggplot2::margin(10, 110, 8, 8))
      } else {
        grafico + rotular_extremos(completa, "year", "valor", formatar = formatar())
      }
    }, alt = function() paste(
      "Série por ano-calendário de", rotulo_metrica(), "para",
      paste(vapply(input$geo, function(codigo) geografia_nome(bundle, codigo), character(1)), collapse = ", "),
      "no conceito", ranking_label(bundle, input$ranking),
      if (isTRUE(input$sem_topo)) ", com a série sem o top 0,01% tracejada" else "",
      ". A faixa sombreada marca 2018, ano não comparável; os valores estão na aba Tabela."
    ))

    output$plot_leitura <- shiny::renderUI({
      linhas <- linhas_no_ponteiro(selected(), evento_ponteiro(input, "plot"), "year")
      if (nrow(linhas) == 0L) return(leitura_ui(NULL))
      f <- formatar()
      partes <- vapply(seq_len(nrow(linhas)), function(i) {
        rotulo <- as.character(linhas$geografia[[i]])
        if (linhas$serie[[i]] == serie_sem_topo) rotulo <- paste(rotulo, "sem o top 0,01%")
        paste0(rotulo, ": ", f(linhas$valor[[i]]))
      }, character(1))
      texto <- paste0(linhas$year[[1]], " · ", paste(partes, collapse = " · "))
      # O Gini publicado é o limite inferior; o superior mostra quanto a
      # desigualdade dentro dos grupos ainda poderia acrescentar.
      if (input$metric == "gini_grouped" && nrow(linhas) == 1L && is.finite(linhas$superior[[1]])) {
        texto <- paste0(
          texto, " (limite superior de Gastwirth: ",
          rotulo_indice(0.0001)(linhas$superior[[1]]), ")"
        )
      }
      if (linhas$year[[1]] == 2018L) texto <- paste(texto, "· 2018 não é comparável")
      leitura_ui(texto)
    })

    tabela_larga <- shiny::reactive({
      d <- selected()
      if (nrow(d) == 0L) return(data.frame())
      d$coluna <- ifelse(
        d$serie == serie_todos, as.character(d$geografia),
        paste(as.character(d$geografia), "(sem o top 0,01%)")
      )
      colunas <- unique(d$coluna)
      anos <- sort(unique(d$year))
      saida <- data.frame(Ano = as.character(anos))
      for (coluna in colunas) {
        bloco <- d[d$coluna == coluna, , drop = FALSE]
        saida[[coluna]] <- bloco$valor[match(anos, bloco$year)]
      }
      saida
    })

    output$tabela <- shiny::renderTable({
      saida <- tabela_larga()
      shiny::validate(shiny::need(nrow(saida) > 0L, "Sem dados para a seleção."))
      f <- formatar()
      for (coluna in names(saida)[-1]) saida[[coluna]] <- f(saida[[coluna]])
      saida
    }, striped = TRUE, align = "l")

    output$baixar <- shiny::downloadHandler(
      filename = function() paste0("irpf-centis-evolucao-", input$metric, ".csv"),
      content = function(file) {
        d <- selected()
        escrever_csv_ptbr(
          data.frame(
            Ano = d$year,
            Geografia = as.character(d$geografia),
            Serie = as.character(d$serie),
            Conceito = ranking_label(bundle, input$ranking),
            Indicador = rotulo_metrica(),
            Valor = d$valor
          ),
          file
        )
      }
    )

    # Em quais geografias 2018 destoa, no indicador e conceito escolhidos: a
    # nota fala do que o gráfico mostra, em vez de uma ressalva genérica.
    saltos_brasil <- shiny::reactive({
      geografias_salto_2018(bundle$metrics, input$ranking, input$metric)
    })

    output$rodape <- shiny::renderUI({
      shiny::req(input$geo, input$ranking, input$metric)
      nomes <- function(codigos) {
        paste(vapply(codigos, function(codigo) geografia_nome(bundle, codigo), character(1)), collapse = ", ")
      }
      com_salto <- intersect(input$geo, saltos_brasil())
      nota_2018 <- if (length(com_salto) > 0L) {
        paste0(
          "Em ", nomes(com_salto), ", 2018 se afasta dos anos vizinhos porque um único ",
          "grupo do topo destoa no arquivo oficial; o valor é preservado como publicado. ",
          if (sem_topo_disponivel()) "Marque a série sem o top 0,01% para ver o ano sem ele." else ""
        )
      } else if (length(saltos_brasil()) > 0L) {
        paste0(
          "Nas geografias escolhidas, 2018 acompanha os anos vizinhos neste indicador. ",
          "O ano não é comparável em ", nomes(saltos_brasil()), "."
        )
      } else {
        "O ano-calendário 2018 fica sombreado: na fonte oficial, um grupo do topo destoa dos anos vizinhos."
      }
      bloco_rodape(
        notas = c(
          paste(
            "Os índices são estimados a partir das médias e das quantidades dos",
            "grupos divulgados; não observam a variação dentro de cada grupo."
          ),
          nota_2018
        ),
        fonte = fonte_receita
      )
    })

    output$conceitos <- shiny::renderUI(
      bloco_conceitos(
        bundle,
        rankings = input$ranking,
        indicadores = input$metric,
        adicional = tabela_conceitos(bundle, destaque = input$ranking)
      )
    )

    shiny::reactive(list(
      ind = input$metric,
      conceito = input$ranking,
      comparar = if (length(input$geo) > 1L) input$geo[-1] else NULL,
      sem_topo = isTRUE(input$sem_topo)
    ))
  })
}
