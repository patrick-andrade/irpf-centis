app_env <- load_app_module_env()

empty_bundle <- app_env$load_app_bundle(tempfile(fileext = ".rds"))
filled_bundle <- synthetic_app_bundle()

expect_missing_card <- function(server_fun, bundle) {
  shiny::testServer(server_fun, args = list(bundle = bundle), {
    html <- as.character(output$missing$html)
    expect_match(html, "Dados processados não disponíveis")
  })
}

test_that("abas renderizam o cartão de dados ausentes com bundle vazio", {
  expect_missing_card(app_env$mod_composition_server, empty_bundle)
  expect_missing_card(app_env$mod_assets_server, empty_bundle)
  expect_missing_card(app_env$mod_debt_server, empty_bundle)
  expect_missing_card(app_env$mod_regions_server, empty_bundle)
  expect_missing_card(app_env$mod_evolution_server, empty_bundle)
})

test_that("composição renderiza gráficos e alíquota efetiva com dados", {
  shiny::testServer(app_env$mod_composition_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", geo = "BR", group = "taxable")
    expect_no_error(output$plot)
    expect_no_error(output$tax_curve)
    expect_match(as.character(output$conceitos$html), "Conceitos e indicadores")
  })
})

test_that("aba de bens renderiza composição, concentração e série direta", {
  shiny::testServer(app_env$mod_assets_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", geo = "BR")
    expect_no_error(output$plot)
    expect_no_error(output$concentration)
    expect_no_error(output$concentration_top)
    expect_no_error(output$direct_plot)
    # A distinção entre bens dentro dos centis de renda e ordenação direta pelo
    # patrimônio é o que a aba antiga só insinuava no cabeçalho.
    expect_match(as.character(output$conceitos$html), "Ordenação direta nacional")
  })
})

test_that("aba de dívidas desenha estoque e razão, e marca o grupo sem renda", {
  shiny::testServer(app_env$mod_debt_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", geo = "BR")
    expect_no_error(output$mean_debt)
    expect_no_error(output$mean_debt_top)
    expect_no_error(output$ratio)
    expect_no_error(output$ratio_top)
    rodape <- as.character(output$rodape$html)
    expect_match(rodape, "renda declarada do grupo é nula")
    expect_match(rodape, "estoque de dívidas declarado")
  })
})

test_that("aba de estados desenha mapa por polígonos, ranking e tabela", {
  shiny::testServer(app_env$mod_regions_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", metric = "gini_grouped")
    expect_no_error(output$map)
    expect_no_error(output$plot)
    expect_no_error(output$table)
    expect_match(as.character(output$conceitos$html), "Gini agrupado")
  })
})

test_that("evolução responde à seleção de geografia e indicador", {
  shiny::testServer(app_env$mod_evolution_server, args = list(bundle = filled_bundle), {
    session$setInputs(geo = "SP", ranking = "RB4", metric = "top_1_share")
    expect_no_error(output$plot)
    expect_match(output$title, "SP")
    conceitos <- as.character(output$conceitos$html)
    expect_match(conceitos, "Participação do top 1%")
    # A tabela de conceitos deixa comparar as ordenações sem percorrer o seletor.
    expect_match(conceitos, "Renda ampliada 1")
  })
})

test_that("topos traduzem participação em contagem de declarações", {
  shiny::testServer(app_env$mod_top_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", geo = "BR")
    expect_no_error(output$content)
    rodape <- as.character(output$rodape$html)
    expect_match(rodape, "Brasil, 2024: o top 0,01% reúne 100 declarações", fixed = TRUE)
    expect_match(rodape, "das quais 15 conjuntas, e 80 dependentes", fixed = TRUE)
    expect_match(rodape, "contagens de declarações não são")
  })
})

test_that("ano sem declarações conjuntas não vira zero na observação", {
  shiny::testServer(app_env$mod_top_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2023", geo = "BR")
    rodape <- as.character(output$rodape$html)
    expect_match(rodape, "não é divulgada neste ano")
    expect_false(grepl("das quais", rodape, fixed = TRUE))
  })
})

test_that("metodologia expõe conceitos, indicadores e referências", {
  shiny::testServer(app_env$mod_methodology_server, args = list(bundle = filled_bundle), {
    expect_match(as.character(output$conceitos$html), "Renda ampla sem transferências patrimoniais")
    indicadores <- as.character(output$indicadores$html)
    expect_match(indicadores, "Cálculo com dados agrupados")
    expect_match(indicadores, "Gastwirth")
    expect_match(as.character(output$referencias$html), "doi.org")
    expect_match(as.character(output$downloads$html), "github.com/patrick-andrade/irpf-centis")
  })
})
