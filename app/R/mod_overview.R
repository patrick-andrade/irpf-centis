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
      bslib::layout_columns(
        col_widths = c(3, 3, 3, 3),
        bslib::value_box(
          title = paste("Declarantes —", latest),
          value = scales::label_number(big.mark = ".", decimal.mark = ",", accuracy = 1)(row$contributors),
          showcase = bsicons::bs_icon("people")
        ),
        bslib::value_box(
          title = "Gini agrupado",
          value = scales::number(row$gini_grouped, accuracy = 0.001, decimal.mark = ","),
          showcase = bsicons::bs_icon("bar-chart")
        ),
        bslib::value_box(
          title = "Participação do top 1%",
          value = scales::percent(row$top_1_share, accuracy = 0.1, decimal.mark = ","),
          showcase = bsicons::bs_icon("graph-up-arrow")
        ),
        bslib::value_box(
          title = "Wolfson agrupado",
          value = scales::number(row$wolfson_grouped, accuracy = 0.001, decimal.mark = ","),
          showcase = bsicons::bs_icon("arrows-expand")
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

