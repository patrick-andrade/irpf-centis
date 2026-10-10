mod_top_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      shiny::selectInput(ns("year"), "Ano", choices = NULL),
      shiny::selectInput(ns("geo"), "Geografia", choices = NULL)
    ),
    shiny::uiOutput(ns("content")),
    bslib::card(
      bslib::card_header(
        class = "cabecalho-com-acao",
        shiny::textOutput(ns("titulo_serie"), inline = TRUE),
        shiny::downloadButton(ns("baixar"), "Baixar dados (CSV)", class = "btn-sm botao-baixar")
      ),
      bslib::navset_underline(
        bslib::nav_panel("Gráfico", grafico_interativo(ns, "serie", "420px")),
        bslib::nav_panel("Tabela", shiny::tableOutput(ns("tabela")))
      )
    ),
    shiny::uiOutput(ns("rodape")),
    shiny::uiOutput(ns("conceitos"))
  )
}

topo_indicadores <- c("top_10_share", "top_1_share", "top_0_1_share", "top_0_01_share")

# "0,01% do topo" é uma fração; o leitor pergunta quantas declarações são. A
# tradução não sai do total multiplicado pelo corte: o tamanho de cada grupo é
# fixado pela Receita e é esse número que o estudo publica.
frase_contagem <- function(linha, geo_nome, contar) {
  partes <- paste0(contar(linha$contributors), " declarações")
  if (is.finite(linha$joint_returns)) {
    partes <- paste0(
      partes, ", das quais ", contar(linha$joint_returns), " conjuntas"
    )
  }
  if (is.finite(linha$dependents)) {
    partes <- paste0(partes, ", e ", contar(linha$dependents), " dependentes")
  }
  paste0(
    geo_nome, ", ", linha$year, ": o top ", linha$group_label, " reúne ", partes, "."
  )
}

mod_top_server <- function(id, bundle, estado = NULL, ativo = NULL, inicial = list()) {
  shiny::moduleServer(id, function(input, output, session) {
    if (!bundle_has_data(bundle)) {
      output$content <- shiny::renderUI(data_missing_ui())
      return(invisible(NULL))
    }
    anos <- as.character(sort(unique(bundle$metrics$year)))
    escolhas <- escolhas_geografia(bundle, bundle$metrics$geo_code)
    shiny::updateSelectInput(
      session, "year", choices = anos,
      selected = valor_inicial(estado, "ano", anos, max(anos))
    )
    shiny::updateSelectInput(
      session, "geo", choices = escolhas,
      selected = valor_inicial(estado, "geo", escolhas, "BR")
    )
    sincronizar_estado(session, input, estado, "ano", "year", ativo)
    sincronizar_estado(session, input, estado, "geo", "geo", ativo)

    linha_do_ano <- function(ano) {
      bundle$metrics |>
        dplyr::filter(.data$year == ano, .data$geo_code == input$geo, .data$ranking_id == "RB4")
    }

    output$content <- shiny::renderUI({
      shiny::req(input$year, input$geo)
      ano <- as.integer(input$year)
      d <- linha_do_ano(ano)
      shiny::validate(shiny::need(nrow(d) == 1L, "Sem dados para a seleção."))
      anterior <- linha_do_ano(ano - 1L)
      pp <- function(x) scales::number(100 * x, accuracy = 0.1, decimal.mark = ",")
      caixa <- function(rotulo, coluna) {
        bslib::value_box(
          title = titulo_com_ajuda(rotulo, bundle, coluna),
          value = scales::percent(d[[coluna]], 0.1, decimal.mark = ","),
          variacao_ui(d, anterior, coluna, pp, "p.p.", ano)
        )
      }
      bslib::layout_columns(
        # Quatro por linha só em tela larga; no tablet, duas.
        col_widths = bslib::breakpoints(sm = 6, lg = 3),
        caixa("Top 10%", "top_10_share"),
        caixa("Top 1%", "top_1_share"),
        caixa("Top 0,1%", "top_0_1_share"),
        caixa("Top 0,01%", "top_0_01_share")
      )
    })

    serie <- shiny::reactive({
      shiny::req(input$geo)
      dados_top_shares(bundle$metrics, input$geo, "RB4")
    })

    output$titulo_serie <- shiny::renderText(paste(
      "Participação dos grupos do topo na renda declarada —", geografia_nome(bundle, input$geo)
    ))

    output$serie <- shiny::renderPlot({
      d <- serie()
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem série para a seleção."))
      # A linha vertical liga o gráfico às caixas acima: é o ano escolhido.
      grafico_top_shares(d, base_size = 13) +
        ggplot2::geom_vline(
          xintercept = as.integer(input$year), colour = cores_irpf$referencia,
          linetype = "dashed", linewidth = 0.5
        )
    }, alt = function() paste(
      "Séries da participação do top 10%, do top 1% e do top 0,1% na renda RB4 declarada,",
      geografia_nome(bundle, input$geo),
      ", por ano-calendário. A faixa sombreada marca 2018, ano não comparável; a linha",
      "tracejada marca o ano escolhido. Os valores estão na aba Tabela."
    ))

    output$serie_leitura <- shiny::renderUI({
      linhas <- linhas_no_ponteiro(serie(), evento_ponteiro(input, "serie"), "year")
      if (nrow(linhas) == 0L) return(leitura_ui(NULL))
      partes <- paste0(linhas$group, ": ", rotulo_percentual(0.1)(linhas$share))
      texto <- paste0(linhas$year[[1]], " · ", paste(partes, collapse = " · "))
      if (linhas$year[[1]] == 2018L) texto <- paste(texto, "· 2018 não é comparável")
      leitura_ui(texto)
    })

    output$tabela <- shiny::renderTable({
      d <- serie()
      shiny::validate(shiny::need(nrow(d) > 0L, "Sem série para a seleção."))
      anos_serie <- sort(unique(d$year))
      saida <- data.frame(Ano = as.character(anos_serie))
      for (grupo in levels(d$group)) {
        bloco <- d[d$group == grupo, , drop = FALSE]
        saida[[grupo]] <- rotulo_percentual(0.1)(bloco$share[match(anos_serie, bloco$year)])
      }
      saida
    }, striped = TRUE, align = "l")

    output$baixar <- shiny::downloadHandler(
      filename = function() paste0("irpf-centis-topos-", input$geo, ".csv"),
      content = function(file) {
        d <- serie()
        escrever_csv_ptbr(
          data.frame(
            Ano = d$year, Geografia = geografia_nome(bundle, input$geo),
            Grupo = as.character(d$group), Participacao = d$share
          ),
          file
        )
      }
    )

    contagens <- shiny::reactive({
      contagens <- schema_slice(bundle, "top_group_counts")
      if (is.null(contagens)) return(NULL)
      shiny::req(input$year, input$geo)
      d <- contagens |>
        dplyr::filter(
          .data$year == as.integer(input$year), .data$geo_code == input$geo
        ) |>
        dplyr::arrange(.data$share_lower)
      if (nrow(d) == 0L) NULL else d
    })

    output$rodape <- shiny::renderUI({
      d <- contagens()
      contar <- rotulo_contagem()
      # A geografia abre a frase para não depender de preposição: "no Brasil",
      # "em São Paulo" e "no Acre" exigiriam concordância por unidade.
      geo_nome <- geografia_nome(bundle, input$geo)
      observacoes <- if (is.null(d)) {
        NULL
      } else {
        vapply(
          seq_len(nrow(d)),
          function(i) frase_contagem(d[i, ], geo_nome, contar),
          character(1)
        )
      }
      sem_conjuntas <- !is.null(d) && all(!is.finite(d$joint_returns))
      bloco_rodape(
        notas = c(
          paste(
            "Os grupos detalhados do topo são disjuntos no cálculo.",
            "Os agregados 100 e 110 não são somados novamente."
          ),
          nota_unidade,
          if (sem_conjuntas) {
            paste(
              "A quantidade de declarações conjuntas não é divulgada neste ano;",
              "o campo fica ausente, e não zerado."
            )
          }
        ),
        observacoes = observacoes,
        fonte = fonte_receita
      )
    })

    output$conceitos <- shiny::renderUI(
      bloco_conceitos(bundle, rankings = "RB4", indicadores = topo_indicadores)
    )

    shiny::reactive(list())
  })
}
