mod_overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::tags$header(
      class = "app-intro",
      shiny::tags$p(class = "app-intro-kicker", "Visão geral · Brasil"),
      shiny::tags$h1("Os números centrais do IRPF por centis"),
      shiny::tags$p(
        "Declarações válidas, desigualdade agrupada e participação do topo ",
        "no conceito principal de renda (RB4)."
      )
    ),
    shiny::uiOutput(ns("content")),
    shiny::tags$h2(class = "titulo-secao", "Por onde começar"),
    shiny::uiOutput(ns("perguntas")),
    shiny::uiOutput(ns("rodape")),
    shiny::uiOutput(ns("conceitos"))
  )
}

# Cada cartão faz a pergunta que o leitor traria e responde com um número do
# próprio bundle — o formato das fichas que desfazem mitos do Grattan e do Tax
# Foundation — e leva à aba que aprofunda a resposta.
perguntas_visao_geral <- function(bundle) {
  if (!bundle_has_data(bundle)) return(list())
  ultimo <- max(bundle$metrics$year)
  primeiro <- min(bundle$metrics$year)
  br <- bundle$metrics[bundle$metrics$geo_code == "BR" & bundle$metrics$ranking_id == "RB4", , drop = FALSE]
  linha <- function(ano) br[br$year == ano, , drop = FALSE]
  pct <- rotulo_percentual(0.1)
  ind <- rotulo_indice(0.001)
  perguntas <- list()

  if (nrow(linha(ultimo)) == 1L) {
    perguntas$topos <- list(
      pergunta = "Quanto da renda declarada fica com o 1% do topo?",
      resposta = paste0(
        "Em ", ultimo, ", o 1% de maior renda declarou ", pct(linha(ultimo)$top_1_share),
        " da renda RB4; o 0,1%, ", pct(linha(ultimo)$top_0_1_share), "."
      ),
      aba = "topos", rotulo = "Topos da renda"
    )
  }
  if (nrow(linha(primeiro)) == 1L && nrow(linha(ultimo)) == 1L) {
    perguntas$evolucao <- list(
      pergunta = "A desigualdade entre declarantes aumentou?",
      resposta = paste0(
        "O Gini agrupado foi de ", ind(linha(primeiro)$gini_grouped), " em ", primeiro,
        " a ", ind(linha(ultimo)$gini_grouped), " em ", ultimo,
        ". O ano de 2018 não é comparável."
      ),
      aba = "evolucao", rotulo = "Evolução"
    )
  }
  aliquotas <- bundle$effective_tax
  if (nrow(aliquotas) > 0L) {
    a <- aliquotas[aliquotas$geo_code == "BR" & aliquotas$year == max(aliquotas$year) &
      is.finite(aliquotas$effective_rate), , drop = FALSE]
    topo <- a[a$bin_code == max(a$bin_code), , drop = FALSE]
    if (nrow(a) > 0L && nrow(topo) == 1L) {
      perguntas$rendimentos <- list(
        pergunta = "Quem paga mais imposto, em proporção da renda?",
        resposta = paste0(
          "Em ", max(a$year), ", a alíquota efetiva média chega a ", pct(max(a$effective_rate)),
          " no grupo de maior carga e fica em ", pct(topo$effective_rate),
          " no 0,01% de maior renda."
        ),
        aba = "rendimentos", rotulo = "Rendimentos e imposto"
      )
    }
  }
  estados <- bundle$metrics[bundle$metrics$year == ultimo & bundle$metrics$geo_level == "state" &
    bundle$metrics$ranking_id == "RB4" & is.finite(bundle$metrics$gini_grouped), , drop = FALSE]
  if (nrow(estados) >= 2L) {
    menor <- estados[which.min(estados$gini_grouped), ]
    maior <- estados[which.max(estados$gini_grouped), ]
    perguntas$estados <- list(
      pergunta = "Como a desigualdade varia entre os estados?",
      resposta = paste0(
        "Em ", ultimo, ", o Gini agrupado vai de ", ind(menor$gini_grouped), " (",
        geografia_nome(bundle, menor$geo_code), ") a ", ind(maior$gini_grouped), " (",
        geografia_nome(bundle, maior$geo_code), "), com centis calculados dentro de cada UF."
      ),
      aba = "estados", rotulo = "Estados e regiões"
    )
  }
  patrimonio <- schema_slice(bundle, "wealth_by_bin")
  if (!is.null(patrimonio)) {
    p <- patrimonio[patrimonio$geo_code == "BR" & patrimonio$year == max(patrimonio$year), , drop = FALSE]
    topo <- p[p$share_lower >= 0.99 - 1e-9, , drop = FALSE]
    if (nrow(topo) > 0L && any(is.finite(topo$assets_share))) {
      perguntas$bens <- list(
        pergunta = "Quanto patrimônio declara quem está no topo da renda?",
        resposta = paste0(
          "Em ", max(p$year), ", o 1% de maior renda declarou ",
          pct(sum(topo$assets_share, na.rm = TRUE)), " dos bens e direitos."
        ),
        aba = "bens", rotulo = "Bens"
      )
    }
  }
  perguntas
}

mod_overview_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    output$content <- shiny::renderUI({
      if (!bundle_has_data(bundle)) return(data_missing_ui())
      latest <- max(bundle$metrics$year)
      row <- bundle$metrics |>
        dplyr::filter(.data$year == latest, .data$geo_code == "BR", .data$ranking_id == "RB4")
      if (nrow(row) == 0L) return(data_missing_ui())
      anterior <- bundle$metrics |>
        dplyr::filter(.data$year == latest - 1L, .data$geo_code == "BR", .data$ranking_id == "RB4")

      pontos <- function(x) scales::number(x, accuracy = 0.001, decimal.mark = ",")
      pp <- function(x) scales::number(100 * x, accuracy = 0.1, decimal.mark = ",")

      bslib::layout_columns(
        # Quatro por linha só em tela larga; no tablet, duas.
        col_widths = bslib::breakpoints(sm = 6, lg = 3),
        bslib::value_box(
          title = paste("Declarantes —", latest),
          value = rotulo_contagem()(row$contributors),
          showcase = bsicons::bs_icon("people"),
          variacao_ui(row, anterior, "contributors", rotulo_contagem(), "declarações", latest)
        ),
        bslib::value_box(
          title = titulo_com_ajuda("Gini agrupado", bundle, "gini_grouped"),
          value = scales::number(row$gini_grouped, accuracy = 0.001, decimal.mark = ","),
          showcase = bsicons::bs_icon("bar-chart"),
          variacao_ui(row, anterior, "gini_grouped", pontos, "ponto", latest)
        ),
        bslib::value_box(
          title = titulo_com_ajuda("Participação do top 1%", bundle, "top_1_share"),
          value = scales::percent(row$top_1_share, accuracy = 0.1, decimal.mark = ","),
          showcase = bsicons::bs_icon("graph-up-arrow"),
          variacao_ui(row, anterior, "top_1_share", pp, "p.p.", latest)
        ),
        bslib::value_box(
          title = titulo_com_ajuda("Participação do top 0,1%", bundle, "top_0_1_share"),
          value = scales::percent(row$top_0_1_share, accuracy = 0.1, decimal.mark = ","),
          showcase = bsicons::bs_icon("arrows-expand"),
          variacao_ui(row, anterior, "top_0_1_share", pp, "p.p.", latest)
        )
      )
    })

    perguntas <- perguntas_visao_geral(bundle)

    output$perguntas <- shiny::renderUI({
      if (length(perguntas) == 0L) return(NULL)
      cartoes <- lapply(names(perguntas), function(chave) {
        item <- perguntas[[chave]]
        bslib::card(
          class = "cartao-pergunta",
          bslib::card_body(
            shiny::tags$h3(item$pergunta),
            shiny::p(item$resposta),
            shiny::actionLink(
              session$ns(paste0("ir_", chave)),
              paste("Ver em", item$rotulo, "→"),
              class = "link-pergunta"
            )
          )
        )
      })
      do.call(
        bslib::layout_columns,
        c(list(col_widths = bslib::breakpoints(sm = 12, md = 6, lg = 4)), cartoes)
      )
    })

    # nav_select precisa da sessão raiz: dentro do módulo o id "aba" seria
    # prefixado e não acharia a barra de navegação.
    lapply(names(perguntas), function(chave) {
      shiny::observeEvent(input[[paste0("ir_", chave)]], {
        bslib::nav_select("aba", perguntas[[chave]]$aba, session = session$rootScope())
      }, ignoreInit = TRUE)
    })

    output$rodape <- shiny::renderUI({
      if (!bundle_has_data(bundle)) return(NULL)
      latest <- max(bundle$metrics$year)
      bloco_rodape(
        notas = c(nota_unidade, "Valores monetários em R$ de 2024, deflacionados pelo IPCA anual médio."),
        observacoes = paste0(
          "Os cartões acima trazem o Brasil no conceito central de renda (RB4), ",
          "no ano-calendário ", latest, ", com a variação contra o ano anterior."
        ),
        fonte = fonte_receita
      )
    })

    output$conceitos <- shiny::renderUI(
      bloco_conceitos(
        bundle,
        rankings = "RB4",
        indicadores = c("gini_grouped", "top_1_share", "top_0_1_share")
      )
    )
  })
}
