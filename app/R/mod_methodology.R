repositorio_url <- "https://github.com/patrick-andrade/irpf-centis"
site_url <- "https://patrick-andrade.github.io/irpf-centis"

link_externo <- function(texto, href) {
  shiny::a(texto, href = href, target = "_blank", rel = "noopener")
}

mod_methodology_ui <- function(id) {
  ns <- shiny::NS(id)
  # navset_tab dentro de um card, e não navset_card_tab: este último marca cada
  # painel como html-fill-container, o modo que já anulou a altura declarada dos
  # gráficos das outras abas.
  bslib::card(bslib::navset_tab(
    bslib::nav_panel("Universo", shiny::uiOutput(ns("universo"))),
    bslib::nav_panel("Conceitos de renda", shiny::uiOutput(ns("conceitos"))),
    bslib::nav_panel("Indicadores", shiny::uiOutput(ns("indicadores"))),
    bslib::nav_panel("Dados curados", shiny::uiOutput(ns("pipeline"))),
    bslib::nav_panel("Referências", shiny::uiOutput(ns("referencias"))),
    bslib::nav_panel("Dados e código", shiny::uiOutput(ns("downloads")))
  ))
}

# Cada indicador ganha definição, leitura, faixa, a nota de cálculo com dados
# agrupados e as referências que sustentam a fórmula. É o único lugar do painel
# em que os três níveis aparecem juntos.
ficha_indicador <- function(bundle, linha) {
  instavel <- isTRUE(linha$unstable[[1]] == 1)
  shiny::tags$section(
    class = "ficha-indicador",
    shiny::h4(coluna_opcional(linha, "short_label") %||% linha$indicator_id[[1]]),
    shiny::p(coluna_opcional(linha, "definition")),
    if (!is.na(coluna_opcional(linha, "reading"))) {
      shiny::p(shiny::tags$em("Como ler: "), coluna_opcional(linha, "reading"))
    },
    if (!is.na(coluna_opcional(linha, "range"))) {
      shiny::p(class = "small text-muted", paste0("Faixa: ", coluna_opcional(linha, "range")))
    },
    if (!is.na(coluna_opcional(linha, "grouped_note"))) {
      shiny::p(
        class = "small text-muted",
        shiny::tags$strong("Cálculo com dados agrupados: "),
        coluna_opcional(linha, "grouped_note")
      )
    },
    if (instavel) {
      shiny::p(
        class = "small",
        shiny::tags$strong("Atenção: "),
        "indicador não limitado por construção; não comparar entre geografias sem checar a mediana do grupo."
      )
    },
    referencia_ui(bundle, coluna_opcional(linha, "reference_keys"))
  )
}

mod_methodology_server <- function(id, bundle) {
  shiny::moduleServer(id, function(input, output, session) {
    output$universo <- shiny::renderUI(shiny::tagList(
      shiny::h4("Unidade de observação"),
      shiny::p(paste(
        "A unidade divulgada pela Receita Federal é a declaração válida do IRPF,",
        "que pode reunir titular, dependentes e declaração conjunta. Os resultados",
        "não descrevem diretamente pessoas, domicílios nem toda a população brasileira."
      )),
      shiny::h4("Grupos hierárquicos"),
      shiny::p(paste(
        "Os grupos 100 e 110 são agregados que se sobrepõem aos detalhamentos",
        "seguintes. A distribuição disjunta usada nos índices contém 1-99, 101-109",
        "e 111-120; os agregados ficam preservados apenas para reconciliação e para",
        "a apresentação direta do top 1% e do top 0,1%."
      )),
      shiny::h4("Geografia"),
      shiny::p(paste(
        "Cada UF é ordenada separadamente. O centil 90 de uma UF não tem",
        "necessariamente o mesmo limite monetário do centil 90 de outra."
      )),
      shiny::h4("Valores reais"),
      shiny::p(paste(
        "Fluxos e estoques monetários são publicados em preços de 2024,",
        "deflacionados pelo IPCA anual médio (IBGE/SIDRA 1737). Os valores",
        "nominais permanecem nos dados curados."
      )),
      shiny::h4("Escopo inferencial"),
      shiny::p(paste(
        "O projeto é descritivo. Mudanças anuais podem refletir alterações",
        "econômicas, tributárias, cadastrais, metodológicas ou de cobertura, e não",
        "são apresentadas como efeitos causais."
      )),
      shiny::p(
        class = "small text-muted",
        "Lista completa em ",
        link_externo("docs/limitations.md", paste0(site_url, "/docs/limitations.html")),
        "."
      )
    ))

    output$conceitos <- shiny::renderUI({
      rankings <- schema_slice(bundle, "rankings")
      if (is.null(rankings)) return(shiny::p("Contrato de conceitos não disponível."))
      principal <- rankings$ranking_id[rankings$primary == 1]
      shiny::tagList(
        shiny::p(paste(
          "Cada conceito é uma ordenação diferente das mesmas declarações. O",
          "conceito central do estudo aparece destacado; os demais servem de",
          "contraste."
        )),
        tabela_conceitos(bundle, destaque = if (length(principal) > 0L) principal[[1]] else NULL),
        shiny::tags$dl(
          class = "glossario-lista",
          lapply(seq_len(nrow(rankings)), function(i) {
            item_glossario(texto_conceito(bundle, rankings$ranking_id[[i]]))
          })
        )
      )
    })

    output$indicadores <- shiny::renderUI({
      indicadores <- schema_slice(bundle, "indicators")
      if (is.null(indicadores)) return(shiny::p("Contrato de indicadores não disponível."))
      shiny::tagList(
        shiny::p(paste(
          "Todos os índices são calculados sobre as médias e as quantidades dos",
          "grupos divulgados. Como não há informação dentro de cada grupo, eles",
          "omitem a desigualdade intragrupo e devem ser lidos como aproximações."
        )),
        lapply(
          seq_len(nrow(indicadores)),
          function(i) ficha_indicador(bundle, indicadores[i, , drop = FALSE])
        )
      )
    })

    output$pipeline <- shiny::renderUI({
      carimbo <- bundle$metadata$created_at
      shiny::tagList(
        shiny::h4("Como os dados curados são construídos"),
        shiny::tags$ol(
          shiny::tags$li(shiny::tags$strong("discover"), " — lê as páginas oficiais e registra as fontes encontradas."),
          shiny::tags$li(shiny::tags$strong("download"), " — baixa os arquivos e grava tamanho e SHA-256 no manifesto; nada é reprocessado sem conferir o hash."),
          shiny::tags$li(shiny::tags$strong("context"), " — atualiza o deflator IPCA anual e a malha estadual do IBGE."),
          shiny::tags$li(shiny::tags$strong("build"), " — normaliza os layouts de cada ano e produz os dados curados; dois portões de qualidade interrompem o pipeline em vez de degradar em silêncio."),
          shiny::tags$li(shiny::tags$strong("check"), " — testa parser, harmonização, índices, patrimônio, tributação e os módulos deste painel."),
          shiny::tags$li(shiny::tags$strong("render"), " e ", shiny::tags$strong("site"), " — geram os relatórios e exportam este painel para WebAssembly.")
        ),
        shiny::h4("Decisões que o pipeline não negocia"),
        shiny::tags$ul(
          shiny::tags$li("Valores publicados pela Receita são preservados; divergências são registradas, nunca corrigidas em silêncio."),
          shiny::tags$li("Campo ausente na fonte permanece ausente e não é convertido em zero."),
          shiny::tags$li("Índices usam apenas os 118 grupos disjuntos; os agregados 100 e 110 não entram duas vezes."),
          shiny::tags$li("A ausência de deflator para qualquer ano interrompe o pipeline."),
          shiny::tags$li("Nenhum denominador populacional provisório entra nos produtos publicados, e não há fusão distributiva entre IRPF e PNAD.")
        ),
        shiny::h4("Ressalva de comparabilidade"),
        shiny::p(paste(
          "No arquivo oficial de 2018 o grupo do top 0,01% traz valores que",
          "destoam dos anos vizinhos em duas ordens de grandeza. Os 117 demais",
          "grupos seguem a tendência. Os números são os publicados, foram",
          "conferidos contra a origem e são preservados sem correção; o ano fica",
          "sinalizado e as séries acompanham a variante calculada sem esse grupo."
        )),
        if (!is.null(carimbo) && !is.na(carimbo)) {
          shiny::p(class = "small text-muted", paste("Dados deste painel gerados em", carimbo, "."))
        }
      )
    })

    output$referencias <- shiny::renderUI({
      refs <- schema_slice(bundle, "references")
      if (is.null(refs)) return(shiny::p("Lista de referências não disponível."))
      shiny::tagList(
        shiny::p(paste(
          "Fontes dos dados e literatura que sustenta as fórmulas dos",
          "indicadores. As mesmas chaves alimentam a bibliografia dos relatórios."
        )),
        referencia_ui(bundle, refs$key)
      )
    })

    output$downloads <- shiny::renderUI(shiny::tagList(
      shiny::h4("Baixar os dados curados"),
      shiny::p(class = "small text-muted", "Arquivos em CSV, com os valores exatamente como o painel os usa."),
      shiny::div(
        class = "grupo-downloads",
        shiny::downloadButton(session$ns("download_metrics"), "Indicadores por ano, UF e conceito"),
        shiny::downloadButton(session$ns("download_wealth"), "Bens e dívidas por grupo"),
        shiny::downloadButton(session$ns("download_top"), "Contagens dos grupos de topo"),
        shiny::downloadButton(session$ns("download_schema"), "Conceitos e indicadores")
      ),
      shiny::hr(),
      shiny::h4("Código e documentação"),
      shiny::tags$ul(
        shiny::tags$li(link_externo("Repositório no GitHub", repositorio_url), " — pipeline, contratos de dados e testes."),
        shiny::tags$li(link_externo("Metodologia completa", paste0(site_url, "/docs/methodology.html"))),
        shiny::tags$li(link_externo("Limitações", paste0(site_url, "/docs/limitations.html"))),
        shiny::tags$li(link_externo("Apêndice técnico", paste0(site_url, "/reports/technical-appendix.html")))
      ),
      shiny::h4("Fontes oficiais"),
      shiny::tags$ul(
        shiny::tags$li(link_externo(
          "Receita Federal — distribuição da renda",
          "https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/estudos/distribuicao-da-renda"
        )),
        shiny::tags$li(link_externo("IBGE/SIDRA — IPCA, tabela 1737", "https://sidra.ibge.gov.br/tabela/1737"))
      )
    ))

    baixar <- function(nome, dados) {
      shiny::downloadHandler(
        filename = function() paste0("irpf-centis-", nome, "-", Sys.Date(), ".csv"),
        content = function(file) readr::write_csv(dados, file, na = "")
      )
    }
    output$download_metrics <- baixar("indicadores", bundle$metrics)
    output$download_wealth <- baixar("bens-e-dividas-por-grupo", bundle$wealth_by_bin)
    output$download_top <- baixar("contagens-do-topo", bundle$top_group_counts)
    esquema_csv <- function() {
      partes <- list()
      if (!is.null(schema_slice(bundle, "rankings"))) {
        partes[["rankings"]] <- dplyr::transmute(
          bundle$rankings, tipo = "conceito_de_renda", id = .data$ranking_id,
          rotulo = .data$label, definicao = .data$definition
        )
      }
      if (!is.null(schema_slice(bundle, "indicators"))) {
        partes[["indicators"]] <- dplyr::transmute(
          bundle$indicators, tipo = "indicador", id = .data$indicator_id,
          rotulo = .data$label, definicao = .data$definition
        )
      }
      dplyr::bind_rows(partes)
    }
    output$download_schema <- baixar("conceitos-e-indicadores", esquema_csv())
  })
}
