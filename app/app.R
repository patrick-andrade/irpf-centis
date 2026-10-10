module_files <- sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(module_files, source, encoding = "UTF-8"))

bundle <- load_app_bundle("data/app-bundle.rds")

ui <- bslib::page_navbar(
  id = "aba",
  lang = "pt-BR",
  window_title = "Painel interativo — IRPF por centis",
  # O painel roda num iframe do shinylive: o link volta ao site pela URL
  # absoluta e com target="_top", senão o site abriria dentro do próprio painel.
  title = shiny::tags$a(
    class = "marca-painel", href = site_url, target = "_top",
    title = "Voltar ao site do estudo", "IRPF por centis"
  ),
  fillable = FALSE,
  theme = bslib::bs_theme(
    version = 5,
    bg = "#F7F9FC",
    fg = "#101D40",
    primary = "#156DF9"
  ),
  header = shiny::tagList(
    shiny::tags$head(
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
      shiny::tags$script(src = "estado-url.js")
    ),
    shiny::tags$div(
      class = "universe-warning",
      role = "note",
      "Os dados representam declarações válidas do IRPF, não toda a população brasileira."
    )
  ),
  # A UI dos módulos entra direto no navbar, e não por uiOutput/renderUI: saídas
  # de abas ocultas ficam suspensas até a aba ser aberta, de modo que os selects
  # ainda não existiriam quando os updateSelectInput da inicialização são
  # enviados — as mensagens se perdiam e cinco das sete abas ficavam com os
  # filtros vazios. Os `value` em ASCII são os nomes das abas no link da visão.
  bslib::nav_panel("Visão geral", value = "visao-geral", mod_overview_ui("overview")),
  bslib::nav_panel("Evolução", value = "evolucao", mod_evolution_ui("evolution")),
  bslib::nav_panel("Topos da renda", value = "topos", mod_top_ui("top")),
  bslib::nav_panel("Rendimentos e imposto", value = "rendimentos", mod_composition_ui("composition")),
  # nav_menu mantém a navbar com sete entradas e ainda assim declara os dois
  # painéis inline: o conteúdo entra no DOM no carregamento, então os
  # updateSelectInput da inicialização encontram os selects.
  bslib::nav_menu(
    "Patrimônio e dívidas",
    bslib::nav_panel("Bens", value = "bens", mod_assets_ui("assets")),
    bslib::nav_panel("Dívidas", value = "dividas", mod_debt_ui("debt"))
  ),
  bslib::nav_panel("Estados e regiões", value = "estados", mod_regions_ui("regions")),
  bslib::nav_panel("Metodologia e dados", value = "metodologia", mod_methodology_ui("methodology")),
  bslib::nav_spacer(),
  bslib::nav_item(
    shiny::tags$button(
      type = "button", class = "btn btn-sm btn-outline-primary botao-copiar-link",
      onclick = "irpfCopiarLink(this)",
      bsicons::bs_icon("link-45deg"), " Copiar link desta visão"
    )
  ),
  footer = shiny::tags$footer(
    class = "app-footer",
    "Fonte: Receita Federal do Brasil. Índices de desigualdade e polarização são aproximações com dados agrupados."
  )
)

server <- function(input, output, session) {
  # Ano e geografia são comuns às abas, e o link da URL é o ponto de partida.
  inicial <- ler_permalink(shiny::isolate(session$clientData$url_search), bundle)
  estado <- shiny::reactiveValues(ano = inicial$ano, geo = inicial$geo)
  if (!is.null(inicial$aba)) bslib::nav_select("aba", inicial$aba)
  aba_ativa <- function(valor) function() identical(input$aba, valor)

  mod_overview_server("overview", bundle)
  extras <- list(
    evolucao = mod_evolution_server("evolution", bundle, estado, aba_ativa("evolucao"), inicial),
    topos = mod_top_server("top", bundle, estado, aba_ativa("topos"), inicial),
    rendimentos = mod_composition_server("composition", bundle, estado, aba_ativa("rendimentos"), inicial),
    bens = mod_assets_server("assets", bundle, estado, aba_ativa("bens"), inicial),
    dividas = mod_debt_server("debt", bundle, estado, aba_ativa("dividas"), inicial),
    estados = mod_regions_server("regions", bundle, estado, aba_ativa("estados"), inicial)
  )
  mod_methodology_server("methodology", bundle)

  # A URL da página acompanha a visão: aba, ano e geografia quando a aba os
  # usa, e os filtros próprios dela. O debounce evita reescrever a URL a cada
  # passo de uma troca que mexe em vários filtros.
  query <- shiny::reactive({
    aba <- input$aba %||% "visao-geral"
    proprios <- extras[[aba]]
    c(
      list(
        aba = if (!identical(aba, "visao-geral")) aba,
        ano = if (aba %in% abas_com_ano) estado$ano,
        geo = if (aba %in% abas_com_geo) estado$geo
      ),
      if (is.function(proprios)) proprios() else list()
    ) |>
      montar_query()
  }) |>
    shiny::debounce(300)
  shiny::observeEvent(query(), {
    session$sendCustomMessage("estado-url", list(query = query()))
  })
}

shiny::shinyApp(ui, server)
