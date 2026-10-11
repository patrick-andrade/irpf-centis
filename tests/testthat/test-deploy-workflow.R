# Garantias da publicação no GitHub Pages. O deploy só repete o render do
# Quarto sobre o que está versionado (_freeze, bundle JS, figuras e dados das
# páginas): nada de R nem de Node no job, e nada publicado sem o CI aprovar.

ler_fluxo <- function(nome) {
  paste(readLines(
    file.path(test_project_root, ".github", "workflows", nome),
    encoding = "UTF-8", warn = FALSE
  ), collapse = "\n")
}

test_that("publicação depende do CI aprovado e só do commit que é a ponta do main", {
  fluxo <- ler_fluxo("deploy-pages.yml")
  expect_match(fluxo, "workflow_run", fixed = TRUE)
  expect_match(fluxo, "conclusion == 'success'", fixed = TRUE)
  # Um CI antigo que termina por último não leva o site de volta.
  expect_match(fluxo, "commits/main", fixed = TRUE)
  expect_match(fluxo, "needs.verificar.outputs.publicar == 'true'", fixed = TRUE)
})

test_that("deploy é replay: sem R, sem shinylive e com o Quarto fixado", {
  fluxo <- ler_fluxo("deploy-pages.yml")
  expect_no_match(fluxo, "setup-r", fixed = TRUE)
  expect_no_match(fluxo, "shinylive", fixed = TRUE)
  expect_no_match(fluxo, "export-app", fixed = TRUE)
  expect_match(fluxo, "version: 1.9.38", fixed = TRUE)
  expect_match(fluxo, ".nojekyll", fixed = TRUE)
  # Guarda: os dados das páginas Explorar chegaram ao site.
  expect_match(fluxo, "explorar/dados/evolucao.json", fixed = TRUE)
})

test_that("CI testa com o mesmo Quarto do deploy", {
  versao <- function(fluxo) regmatches(fluxo, regexpr("version: [0-9.]+", fluxo))
  expect_equal(versao(ler_fluxo("ci.yml")), versao(ler_fluxo("deploy-pages.yml")))
})
