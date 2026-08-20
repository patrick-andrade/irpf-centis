# O painel roda isolado no navegador e carrega apenas app/R/*.R, então a camada
# de visualização precisa existir também lá. A cópia é gerada; este teste é o
# que impede as duas de divergirem em silêncio.

test_that("app/R/viz.R está em sincronia com R/viz.R", {
  expect_true(
    app_viz_em_sincronia(),
    info = "Rode sync_app_viz() após editar R/viz.R."
  )
})

test_that("a cópia do painel é marcada como gerada", {
  linhas <- readLines(
    file.path(test_project_root, "app", "R", "viz.R"),
    encoding = "UTF-8", warn = FALSE
  )
  expect_match(linhas[1], "GERADO AUTOMATICAMENTE")
})

test_that("a camada compartilhada não usa pacote fora do que roda em wasm", {
  fonte <- readLines(
    file.path(test_project_root, "R", "viz.R"),
    encoding = "UTF-8", warn = FALSE
  )
  usados <- unique(stringr::str_match_all(
    paste(fonte, collapse = "\n"), "([A-Za-z][A-Za-z0-9.]*)::"
  )[[1]][, 2])
  # ggplot2, scales, viridisLite e rlang estão confirmados em repo.r-wasm.org;
  # grid, stats e grDevices vêm com o R. Pacote novo aqui quebra o painel.
  expect_setequal(
    setdiff(usados, c("ggplot2", "scales", "viridisLite", "rlang", "grid", "stats", "grDevices")),
    character()
  )
})
