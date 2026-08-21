# O painel só explica os próprios rótulos se os contratos e a bibliografia não
# divergirem. Estes testes são a trava contra essa deriva.

glossary_env <- load_app_module_env()
indicadores <- read_schema("indicators")
referencias <- read_schema("references")
conceitos <- read_schema("rankings")

chaves_do_bib <- function() {
  linhas <- readLines(project_path("reports/references.bib"), encoding = "UTF-8", warn = FALSE)
  sub(",$", "", sub("^@[a-z]+[{]", "", grep("^@", linhas, value = TRUE)))
}

chaves_citadas <- function(coluna) {
  unique(unlist(strsplit(stats::na.omit(coluna), ";")))
}

test_that("todo indicador do seletor tem definição no contrato", {
  escolhas <- glossary_env$metric_choices
  expect_true(all(unname(escolhas) %in% indicadores$indicator_id))
  rotulos <- indicadores$label[match(unname(escolhas), indicadores$indicator_id)]
  # O rótulo do seletor e o do contrato precisam ser o mesmo texto: é por ele
  # que o leitor liga o gráfico à definição.
  expect_equal(rotulos, names(escolhas))
})

test_that("todo indicador tem leitura, faixa e nota de cálculo agrupado", {
  for (coluna in c("short_label", "definition", "reading", "range", "grouped_note")) {
    vazios <- indicadores$indicator_id[is.na(indicadores[[coluna]]) | !nzchar(indicadores[[coluna]])]
    expect_equal(vazios, character(0), label = paste0("indicadores sem '", coluna, "'"))
  }
})

test_that("todo conceito de renda tem definição e composição", {
  for (coluna in c("definition", "formula")) {
    vazios <- conceitos$ranking_id[is.na(conceitos[[coluna]]) | !nzchar(conceitos[[coluna]])]
    expect_equal(vazios, character(0), label = paste0("conceitos sem '", coluna, "'"))
  }
})

test_that("as referências citadas existem no contrato de referências", {
  citadas <- c(
    chaves_citadas(indicadores$reference_keys),
    chaves_citadas(conceitos$reference_keys)
  )
  expect_equal(setdiff(unique(citadas), referencias$key), character(0))
})

test_that("contrato de referências e bibliografia do Quarto não divergem", {
  # O .bib alimenta os relatórios e o CSV alimenta o painel, que não tem pandoc.
  # Os dois precisam descrever o mesmo acervo.
  bib <- chaves_do_bib()
  expect_equal(setdiff(referencias$key, bib), character(0))
  expect_equal(setdiff(bib, referencias$key), character(0))
})

test_that("blocos de conceito e rodapé degradam sem quebrar com bundle vazio", {
  vazio <- glossary_env$load_app_bundle(tempfile(fileext = ".rds"))
  expect_null(glossary_env$bloco_conceitos(vazio, rankings = "RB4", indicadores = "gini_grouped"))
  expect_null(glossary_env$tabela_conceitos(vazio))
  expect_null(glossary_env$bloco_rodape())
})

test_that("rodapé empilha nota, observação e fonte nesta ordem", {
  html <- as.character(htmltools::renderTags(glossary_env$bloco_rodape(
    notas = "primeira", observacoes = "segunda", fonte = "terceira"
  ))$html)
  expect_lt(regexpr("Nota:", html, fixed = TRUE), regexpr("Observação:", html, fixed = TRUE))
  expect_lt(regexpr("Observação:", html, fixed = TRUE), regexpr("Fonte:", html, fixed = TRUE))
})

test_that("a tabela de conceitos da metodologia cobre todos os rankings", {
  # A tabela em docs/methodology.md é estática; este teste é o que impede que um
  # conceito novo entre no contrato e fique de fora da página de referência.
  texto <- readLines(project_path("docs/methodology.md"), encoding = "UTF-8", warn = FALSE)
  ausentes <- conceitos$ranking_id[!vapply(
    conceitos$ranking_id,
    function(id) any(grepl(paste0("| ", id, " |"), texto, fixed = TRUE)),
    logical(1)
  )]
  expect_equal(ausentes, character(0))
})
