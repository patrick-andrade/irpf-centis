mod_top_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      shiny::selectInput(ns("year"), "Ano", choices = NULL),
      shiny::selectInput(ns("geo"), "Geografia", choices = NULL)
    ),
    shiny::uiOutput(ns("content")),
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

mod_top_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    if (!bundle_has_data(bundle)) {
      output$content <- shiny::renderUI(data_missing_ui())
      return(invisible(NULL))
    }
    shiny::updateSelectInput(session, "year", choices = sort(unique(bundle$metrics$year)), selected = max(bundle$metrics$year))
    shiny::updateSelectInput(session, "geo", choices = sort(unique(bundle$metrics$geo_code)), selected = "BR")
    row <- shiny::reactive({
      bundle$metrics |>
        dplyr::filter(.data$year == as.integer(input$year), .data$geo_code == input$geo, .data$ranking_id == "RB4")
    })
    output$content <- shiny::renderUI({
      d <- row()
      shiny::validate(shiny::need(nrow(d) == 1L, "Sem dados para a seleção."))
      bslib::layout_columns(
        col_widths = c(3, 3, 3, 3),
        bslib::value_box("Top 10%", scales::percent(d$top_10_share, 0.1, decimal.mark = ",")),
        bslib::value_box("Top 1%", scales::percent(d$top_1_share, 0.1, decimal.mark = ",")),
        bslib::value_box("Top 0,1%", scales::percent(d$top_0_1_share, 0.1, decimal.mark = ",")),
        bslib::value_box("Top 0,01%", scales::percent(d$top_0_01_share, 0.1, decimal.mark = ","))
      )
    })

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
  })
}
