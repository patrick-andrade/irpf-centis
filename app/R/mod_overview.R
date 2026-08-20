mod_overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::uiOutput(ns("content"))
  )
}

mod_overview_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    output$content <- shiny::renderUI({
      if (!bundle_has_data(bundle)) return(data_missing_ui())
      years <- sort(unique(bundle$metrics$year))
      latest <- max(years)
      row <- bundle$metrics |>
        dplyr::filter(.data$year == latest, .data$geo_code == "BR", .data$ranking_id == "RB4")
      if (nrow(row) == 0L) return(data_missing_ui())
      anterior <- bundle$metrics |>
        dplyr::filter(.data$year == latest - 1L, .data$geo_code == "BR", .data$ranking_id == "RB4")

      # Um número sozinho não diz se subiu ou desceu. A variação contra o ano
      # anterior dá a referência mínima para interpretar o valor.
      variacao <- function(coluna, formatar, unidade) {
        if (nrow(anterior) == 0L || !is.finite(anterior[[coluna]])) return(NULL)
        delta <- row[[coluna]] - anterior[[coluna]]
        sinal <- if (delta > 0) "+" else if (delta < 0) "−" else "="
        shiny::p(
          class = "small text-muted mb-0",
          paste0(sinal, formatar(abs(delta)), " ", unidade, " ante ", latest - 1L)
        )
      }
      pontos <- function(x) scales::number(x, accuracy = 0.001, decimal.mark = ",")
      pp <- function(x) scales::number(100 * x, accuracy = 0.1, decimal.mark = ",")

      bslib::layout_columns(
        col_widths = c(3, 3, 3, 3),
        bslib::value_box(
          title = paste("Declarantes —", latest),
          value = rotulo_contagem()(row$contributors),
          showcase = bsicons::bs_icon("people"),
          variacao("contributors", rotulo_contagem(), "declarações")
        ),
        bslib::value_box(
          title = "Gini agrupado",
          value = scales::number(row$gini_grouped, accuracy = 0.001, decimal.mark = ","),
          showcase = bsicons::bs_icon("bar-chart"),
          variacao("gini_grouped", pontos, "ponto")
        ),
        bslib::value_box(
          title = "Participação do top 1%",
          value = scales::percent(row$top_1_share, accuracy = 0.1, decimal.mark = ","),
          showcase = bsicons::bs_icon("graph-up-arrow"),
          variacao("top_1_share", pp, "p.p.")
        ),
        bslib::value_box(
          title = "Participação do top 0,1%",
          value = scales::percent(row$top_0_1_share, accuracy = 0.1, decimal.mark = ","),
          showcase = bsicons::bs_icon("arrows-expand"),
          variacao("top_0_1_share", pp, "p.p.")
        ),
        bslib::card(
          full_screen = TRUE,
          bslib::card_header("Como ler estes números"),
          shiny::p("RB4 reúne rendimentos tributáveis, isentos e exclusivos, retirando doações e heranças."),
          shiny::p("Os índices usam médias de grupos e não observam a desigualdade dentro de cada grupo."),
          shiny::p("Uma declaração pode incluir titular, dependentes e declaração conjunta.")
        )
      )
    })
  })
}

