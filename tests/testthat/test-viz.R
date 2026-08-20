# Regras da camada de visualização. O ponto destas asserções é que nenhuma
# escala volte a ser automática: o domínio é declarado, as âncoras são
# redondas e os extremos do eixo ficam rotulados.

test_that("passo_bonito devolve escada 1-2-5", {
  expect_equal(passo_bonito(0.1), 0.02)
  expect_equal(passo_bonito(1), 0.2)
  expect_equal(passo_bonito(0.5), 0.1)
  expect_true(passo_bonito(0) > 0)
  expect_true(passo_bonito(NA_real_) > 0)
})

test_that("escala_indice garante amplitude mínima e âncoras redondas", {
  # Gini patrimonial real: 16 anos dentro de 0,03. Sem amplitude mínima, essa
  # variação ocupava a altura inteira do painel.
  escala <- escala_indice(c(0.851, 0.862, 0.880), span_min = 0.15)
  expect_gte(diff(escala$limits), 0.15)
  expect_lte(escala$limits[1], 0.851)
  expect_gte(escala$limits[2], 0.880)

  # Extremos do eixo coincidem com quebras: nada de limite sem rótulo.
  expect_equal(escala$breaks[1], escala$limits[1])
  expect_equal(escala$breaks[length(escala$breaks)], escala$limits[2])
})

test_that("escala_indice aceita âncora fixa e a respeita", {
  escala <- escala_indice(c(0.851, 0.880), ancora = c(0.70, 1.00))
  expect_equal(escala$limits, c(0.70, 1.00))
  expect_equal(escala$breaks[1], 0.70)
  expect_equal(escala$breaks[length(escala$breaks)], 1.00)
})

test_that("participação e alíquota sempre incluem zero", {
  participacao <- escala_participacao(c(0.48, 0.52, 0.59))
  expect_equal(participacao$limits[1], 0)
  expect_true(0 %in% participacao$breaks)

  # Alíquota efetiva real de 2024: 0 a ~10%.
  aliquota <- escala_aliquota(c(0, 0.0735, 0.1008))
  expect_equal(aliquota$limits[1], 0)
  expect_gte(aliquota$limits[2], 0.1008)
  expect_lte(aliquota$limits[2], 1)
})

test_that("escala_participacao não passa de 100%", {
  escala <- escala_participacao(c(0.2, 0.98))
  expect_lte(escala$limits[2], 1)
})

test_that("escala_ano rotula todos os anos sem folga proporcional", {
  escala <- escala_ano(c(2020, 2017, 2024, 2017))
  expect_equal(escala$breaks, c(2017, 2020, 2024))
})

test_that("rótulo monetário usa a escala curta em português", {
  formatar <- rotulo_dinheiro_ptbr()
  saida <- formatar(c(0, 1500, 2.5e6, 1.2e9, 3e12))
  expect_equal(saida[1], "R$ 0")
  expect_match(saida[2], "mil$")
  expect_match(saida[3], "mi$")
  expect_match(saida[4], "bi$")
  expect_match(saida[5], "tri$")
  # O defeito que isto substitui: cut_short_scale() escreve "B" para bilhão.
  expect_false(any(grepl("[KMBT]$", saida)))
  expect_match(saida[4], "1,2 bi")
  expect_true(is.na(formatar(NA_real_)))
})

test_that("rótulos numéricos usam vírgula decimal e ponto de milhar", {
  expect_equal(rotulo_indice(0.001)(0.6039), "0,604")
  expect_equal(rotulo_percentual(0.1)(0.2507), "25,1%")
  expect_equal(rotulo_contagem()(41676499), "41.676.499")
})

test_that("cor_ordinal devolve rampa distinta e cor_destaque é Okabe-Ito", {
  cores <- cor_ordinal(4)
  expect_length(cores, 4)
  expect_length(unique(cores), 4)
  expect_equal(cor_ordinal(4, inverter = TRUE), rev(cores))
  expect_length(cor_ordinal(0), 0)
  expect_true(all(cor_destaque(3) %in%
    c("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9", "#000000")))
})

test_that("legenda pode ser ordenada pelo valor final da série", {
  dados <- data.frame(
    ano = rep(2017:2019, 3),
    valor = c(0.48, 0.49, 0.52, 0.19, 0.21, 0.25, 0.09, 0.10, 0.13),
    grupo = rep(c("Top 10%", "Top 1%", "Top 0,1%"), each = 3)
  )
  expect_equal(
    ordenar_por_valor_final(dados, "ano", "valor", "grupo"),
    c("Top 10%", "Top 1%", "Top 0,1%")
  )
})

test_that("anotações lidam com série vazia sem quebrar", {
  vazio <- data.frame(ano = numeric(), valor = numeric(), grupo = character())
  expect_null(rotular_extremos(vazio, "ano", "valor"))
  expect_null(rotular_series_no_fim(vazio, "ano", "valor", "grupo"))
  expect_equal(ordenar_por_valor_final(vazio, "ano", "valor", "grupo"), character())
})

test_that("tema remove grades menores e escolhe a direção da grade maior", {
  vertical <- tema_irpf(direcao = "y")
  expect_s3_class(vertical$panel.grid.minor, "element_blank")
  expect_s3_class(vertical$panel.grid.major.y, "element_line")
  expect_s3_class(vertical$panel.grid.major.x, "element_blank")

  horizontal <- tema_irpf(direcao = "x")
  expect_s3_class(horizontal$panel.grid.major.x, "element_line")
  expect_s3_class(horizontal$panel.grid.major.y, "element_blank")

  # Fundo explícito: o site tem tema escuro e figura transparente perde o texto.
  expect_equal(vertical$plot.background$fill, cores_irpf$fundo)
})

test_that("gráfico completo constrói com as escalas declaradas", {
  dados <- data.frame(ano = 2017:2024, valor = seq(0.577, 0.604, length.out = 8))
  grafico <- ggplot2::ggplot(dados, ggplot2::aes(ano, valor)) +
    ggplot2::geom_line() +
    escala_ano(dados$ano) +
    escala_indice(dados$valor) +
    rotular_extremos(dados, "ano", "valor") +
    tema_irpf()
  expect_s3_class(ggplot2::ggplot_build(grafico), "ggplot_built")
})

test_that("títulos longos são quebrados em vez de cortados na largura da figura", {
  longo <- paste(
    "Vinte grupos disjuntos do topo, cada um com a mesma largura no eixo.",
    "Brasil, ano-calendário mais recente."
  )
  quebrado <- quebrar_texto(longo, 88)
  expect_true(grepl("\n", quebrado, fixed = TRUE))
  expect_true(all(nchar(strsplit(quebrado, "\n", fixed = TRUE)[[1]]) <= 88))
  # Texto curto passa intacto; nulo e vazio não quebram a função.
  expect_equal(quebrar_texto("curto", 88), "curto")
  expect_null(quebrar_texto(NULL, 88))
  expect_equal(quebrar_texto("", 88), "")
})

test_that("escala do mapa em classes declara os limites e tolera dado degenerado", {
  # Dado com variação: escala em classes, com os limites declarados.
  classes <- escala_mapa_classes(c(0.50, 0.55, 0.58, 0.61, 0.64, 0.70))
  expect_s3_class(classes, "ScaleBinned")
  expect_true(length(classes$breaks) >= 2L)
  expect_equal(range(classes$breaks), classes$limits)

  # Todas as UFs com o mesmo valor: os quantis colapsam num ponto só e limites
  # de largura zero quebrariam a escala; cai no gradiente contínuo.
  expect_s3_class(escala_mapa_classes(rep(0.6, 8)), "ScaleContinuous")
  expect_s3_class(escala_mapa_classes(c(NA_real_, 0.6)), "ScaleContinuous")
})

test_that("séries que terminam próximas recebem rótulos separados", {
  dados <- data.frame(
    ano = rep(2023:2024, 2),
    valor = c(0.060, 0.062, 0.056, 0.058),
    grupo = rep(c("Top 10%", "Todos os declarantes"), each = 2)
  )
  camada <- rotular_series_no_fim(dados, "ano", "valor", "grupo")
  posicoes <- sort(camada$data$.y_rotulo)
  amplitude <- diff(range(dados$valor))
  expect_gte(diff(posicoes), 0.05 * amplitude - 1e-9)
})

test_that("contexto sai da rampa ordinal e recebe cinza", {
  escala <- escala_cor_ordinal(
    c("Todos os declarantes", "Top 10%", "Top 1%"),
    contexto = "Todos os declarantes"
  )
  valores <- escala$palette(3)
  expect_equal(unname(valores[1]), cor_contexto())
  expect_false(cor_contexto() %in% unname(valores[-1]))
})
