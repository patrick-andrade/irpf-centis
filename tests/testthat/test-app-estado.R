# Estado comum entre as abas, link da visão e leitura de valores sob o cursor.

app_env <- load_app_module_env()
filled_bundle <- synthetic_app_bundle()

test_that("link da visão aceita só valores do bundle e cai no padrão no resto", {
  valido <- app_env$ler_permalink(
    "?aba=evolucao&ano=2023&geo=SP&comparar=RJ,XX&ind=top_1_share&sem_topo=1&ordem=nome",
    filled_bundle
  )
  expect_equal(valido$aba, "evolucao")
  expect_equal(valido$ano, "2023")
  expect_equal(valido$geo, "SP")
  expect_equal(valido$comparar, "RJ")
  expect_equal(valido$ind, "top_1_share")
  expect_true(valido$sem_topo)
  expect_equal(valido$ordem, "nome")

  invalido <- app_env$ler_permalink("?aba=nada&ano=1990&geo=ZZ&ind=x&sem_topo=talvez", filled_bundle)
  expect_null(invalido$aba)
  expect_null(invalido$ano)
  expect_null(invalido$geo)
  expect_null(invalido$ind)
  expect_false(invalido$sem_topo)

  vazio <- app_env$ler_permalink("", filled_bundle)
  expect_null(vazio$aba)
})

test_that("query da visão omite o vazio e junta listas com vírgula", {
  expect_equal(
    app_env$montar_query(list(aba = "evolucao", ano = NULL, geo = "SP", comparar = c("RJ", "MG"), sem_topo = TRUE)),
    "?aba=evolucao&geo=SP&comparar=RJ,MG&sem_topo=1"
  )
  expect_equal(app_env$montar_query(list(aba = NULL, sem_topo = FALSE)), "")
})

test_that("só a aba visível escreve no estado comum", {
  estado <- shiny::reactiveValues(ano = NULL, geo = NULL)
  shiny::testServer(
    app_env$mod_top_server,
    args = list(bundle = filled_bundle, estado = estado, ativo = function() FALSE),
    {
      session$setInputs(year = "2024", geo = "BR")
      session$setInputs(year = "2023", geo = "SP")
      expect_null(estado$geo)
      expect_null(estado$ano)
    }
  )
  shiny::testServer(
    app_env$mod_top_server,
    args = list(bundle = filled_bundle, estado = estado, ativo = function() TRUE),
    {
      session$setInputs(year = "2024", geo = "BR")
      session$setInputs(year = "2023", geo = "SP")
      expect_equal(estado$geo, "SP")
      expect_equal(estado$ano, "2023")
    }
  )
})

test_that("leitura do ponteiro acha o ano mais próximo e o grupo do eixo ordinal", {
  dados <- data.frame(year = 2017:2019, valor = c(0.5, 0.6, 0.55))
  linha <- app_env$linhas_no_ponteiro(dados, list(x = 2018.3, domain = list()), "year")
  expect_equal(linha$year, 2018L)
  expect_equal(nrow(app_env$linhas_no_ponteiro(dados, NULL, "year")), 0L)

  topo <- data.frame(posicao = factor(c("99,1", "99,2")), valor = 1:2)
  evento <- list(x = 2.2, domain = list(discrete_limits = list(x = c("99,1", "99,2"))))
  expect_equal(app_env$linhas_no_ponteiro(topo, evento, "posicao")$valor, 2L)
  evento$x <- 7
  expect_equal(nrow(app_env$linhas_no_ponteiro(topo, evento, "posicao")), 0L)
})

test_that("salto de 2018 é identificado por geografia", {
  metrics <- data.frame(
    year = rep(2017:2019, 2), geo_code = rep(c("PE", "RS"), each = 3), ranking_id = "RB4",
    gini_grouped = c(0.563, 0.865, 0.562, 0.55, 0.552, 0.551)
  )
  expect_equal(app_env$geografias_salto_2018(metrics, "RB4", "gini_grouped"), "PE")
  expect_equal(app_env$geografias_salto_2018(metrics, "RB4", "gini_grouped", geos = "RS"), character())
  expect_equal(app_env$geografias_salto_2018(metrics, "RB4", "nao_existe"), character())
})

test_that("evolução compara até três geografias e acrescenta a série sem o topo", {
  shiny::testServer(app_env$mod_evolution_server, args = list(bundle = filled_bundle), {
    session$setInputs(geo = c("BR", "SP", "RJ"), ranking = "RB4", metric = "gini_grouped", sem_topo = TRUE)
    d <- selected()
    expect_setequal(as.character(unique(d$geografia)), c("Brasil", "São Paulo", "Rio de Janeiro"))
    expect_setequal(as.character(unique(d$serie)), c("Todos os grupos", "Sem o top 0,01%"))
    expect_no_error(output$plot)
    expect_match(output$title, "Brasil, São Paulo, Rio de Janeiro")
    tabela <- output$tabela
    expect_match(tabela, "São Paulo (sem o top 0,01%)", fixed = TRUE)
    expect_match(tabela, "0,550", fixed = TRUE)
    session$setInputs(plot_hover = list(x = 2024.1, domain = list()))
    expect_match(as.character(output$plot_leitura$html), "2024 · Brasil: 0,550", fixed = TRUE)
    expect_equal(session$returned()$comparar, c("SP", "RJ"))
    expect_true(session$returned()$sem_topo)
  })
})

test_that("topos desenham a série histórica e mostram a variação anual", {
  shiny::testServer(app_env$mod_top_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", geo = "BR")
    expect_no_error(output$serie)
    conteudo <- as.character(output$content$html)
    expect_match(conteudo, "ante 2023")
    expect_match(conteudo, "icone-ajuda", fixed = TRUE)
    expect_match(output$tabela, "Top 0,1%", fixed = TRUE)
    session$setInputs(serie_hover = list(x = 2023.2, domain = list()))
    expect_match(as.character(output$serie_leitura$html), "2023 · Top 10%: 50,0%", fixed = TRUE)
  })
})

test_that("visão geral responde perguntas com números do bundle", {
  perguntas <- app_env$perguntas_visao_geral(filled_bundle)
  expect_true(all(c("topos", "evolucao", "rendimentos", "estados") %in% names(perguntas)))
  expect_match(perguntas$topos$resposta, "20,0%", fixed = TRUE)
  expect_match(perguntas$estados$resposta, "Rio de Janeiro")
  shiny::testServer(app_env$mod_overview_server, args = list(bundle = filled_bundle), {
    html <- as.character(output$perguntas$html)
    expect_match(html, "cartao-pergunta", fixed = TRUE)
    expect_match(html, "Ver em Topos da renda", fixed = TRUE)
  })
})

test_that("estados podem ser ordenados por nome e o CSV sai da seleção", {
  shiny::testServer(app_env$mod_regions_server, args = list(bundle = filled_bundle), {
    session$setInputs(year = "2024", metric = "gini_grouped", ordem = "nome")
    expect_equal(selected()$`Unidade da Federação`, c("Rio de Janeiro", "São Paulo"))
    session$setInputs(ordem = "valor")
    expect_equal(selected()$`Unidade da Federação`[[1]], "São Paulo")
    expect_no_error(output$map)
    arquivo <- output$baixar
    texto <- readLines(arquivo, encoding = "UTF-8", warn = FALSE)
    expect_match(texto[[1]], "Gini agrupado", fixed = TRUE)
  })
})
