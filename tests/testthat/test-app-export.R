# A página que abre o painel publicado é gerada pelo shinylive a partir de um
# modelo genérico em inglês. Estes testes cobrem o que o projeto acrescenta a
# ela e o que o job de publicação precisa fazer para não depender de pacotes
# baixados em tempo de execução.

test_that("a página do painel declara português e troca o idioma do modelo", {
  pagina <- tempfile(fileext = ".html")
  writeLines(c("<!doctype html>", '<html lang="en">', "<head></head>", "</html>"), pagina)
  ajustar_index_painel(pagina)
  html <- readLines(pagina, encoding = "UTF-8")
  expect_true('<html lang="pt-BR">' %in% html)
  expect_false(any(grepl('lang="en"', html, fixed = TRUE)))
})

test_that("modelo do shinylive sem o marcador de idioma interrompe o export", {
  pagina <- tempfile(fileext = ".html")
  writeLines(c("<!doctype html>", "<html>", "</html>"), pagina)
  expect_error(ajustar_index_painel(pagina), "modelo do shinylive mudou")
})

test_that("a abertura do painel tem título, descrição e aviso de carregamento", {
  parametros <- parametros_index_painel()
  expect_match(parametros$title, "IRPF por centis")
  expect_match(parametros$include_in_head, 'name="description"', fixed = TRUE)
  expect_match(parametros$include_before_body, "Carregando o painel")
  expect_match(parametros$include_before_body, 'role="status"', fixed = TRUE)
  expect_match(parametros$include_after_body, "MutationObserver", fixed = TRUE)
})

test_that("export sem os pacotes do painel empacotados é recusado", {
  destino <- tempfile()
  pasta <- file.path(destino, "shinylive", "webr", "packages")
  dir.create(file.path(pasta, "ggplot2"), recursive = TRUE)
  expect_error(conferir_pacotes_painel(destino), "dplyr")
  for (pacote in c("dplyr", "scales", "bsicons", "viridisLite")) {
    dir.create(file.path(pasta, pacote))
  }
  expect_true(conferir_pacotes_painel(destino))
})

test_that("o job de publicação usa o script de export e fixa o shinylive", {
  fluxo <- readLines(
    file.path(test_project_root, ".github", "workflows", "deploy-pages.yml"),
    encoding = "UTF-8", warn = FALSE
  )
  fluxo <- paste(fluxo, collapse = "\n")
  expect_match(fluxo, "scripts/export-app.R", fixed = TRUE)
  expect_match(fluxo, "shinylive@0.5.0", fixed = TRUE)
  # Publicação depende do CI aprovado.
  expect_match(fluxo, "workflow_run", fixed = TRUE)
  expect_match(fluxo, "conclusion == 'success'", fixed = TRUE)
})
