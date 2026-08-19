mod_methodology_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_columns(
    col_widths = c(7, 5),
    bslib::card(
      bslib::card_header("Metodologia e limites"),
      shiny::h4("Universo"),
      shiny::p("Declarações válidas do IRPF; não toda a população brasileira."),
      shiny::h4("RB4"),
      shiny::p("Rendimentos tributáveis, isentos e exclusivos, sem doações e heranças."),
      shiny::h4("Dados agrupados"),
      shiny::p("Gini, Theil, Atkinson, Wolfson e Esteban–Ray não captam variação dentro dos grupos."),
      shiny::h4("Geografia"),
      shiny::p("Cada UF possui limites próprios de centis."),
      shiny::h4("Patrimônio"),
      shiny::p("Bens em grupos de RB4 medem concentração patrimonial ao longo da renda.")
    ),
    bslib::card(
      bslib::card_header("Dados curados"),
      shiny::downloadButton(ns("download_metrics"), "Baixar indicadores (CSV)"),
      shiny::hr(),
      shiny::a("Receita Federal — fonte oficial", href = "https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/estudos/distribuicao-da-renda", target = "_blank", rel = "noopener")
    )
  )
}

mod_methodology_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    output$download_metrics <- shiny::downloadHandler(
      filename = function() paste0("irpf-centis-indicadores-", Sys.Date(), ".csv"),
      content = function(file) readr::write_csv(bundle$metrics, file, na = "")
    )
  })
}

