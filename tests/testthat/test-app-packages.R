# O painel roda no navegador (shinylive/WebAssembly): cada pacote que ele chama
# é baixado na primeira visita, com as dependências. O readr entrou por uma
# única linha de download e trouxe vroom, tzdb, hms, bit, bit64, clipr e crayon.
# Este teste impede que um pacote novo entre sem decisão explícita.

pacotes_do_painel <- function(root = test_project_root) {
  arquivos <- c(
    file.path(root, "app", "app.R"),
    list.files(file.path(root, "app", "R"), pattern = "\\.R$", full.names = TRUE)
  )
  fonte <- unlist(lapply(arquivos, readLines, encoding = "UTF-8", warn = FALSE))
  fonte <- sub("#.*$", "", fonte)
  usados <- regmatches(fonte, gregexpr("[A-Za-z][A-Za-z0-9.]*(?=::)", fonte, perl = TRUE))
  sort(unique(unlist(usados)))
}

test_that("o painel só chama pacotes da lista que roda em wasm", {
  permitidos <- c(
    "shiny", "bslib", "bsicons", "htmltools", "ggplot2", "scales", "viridisLite",
    "dplyr", "tibble", "rlang", "stats", "grid", "grDevices", "utils"
  )
  expect_setequal(setdiff(pacotes_do_painel(), permitidos), character())
})

test_that("CSV da seleção sai no formato do Excel em português", {
  app_env <- load_app_module_env()
  arquivo <- tempfile(fileext = ".csv")
  app_env$escrever_csv_ptbr(
    data.frame(Geografia = c("São Paulo", "Brasil"), Valor = c(0.55, 1234.5)),
    arquivo
  )
  bytes <- readBin(arquivo, "raw", file.size(arquivo))
  expect_equal(bytes[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))
  texto <- rawToChar(bytes[-(1:3)])
  Encoding(texto) <- "UTF-8"
  expect_match(texto, "\"Geografia\";\"Valor\"", fixed = TRUE)
  expect_match(texto, "\"São Paulo\";0,55", fixed = TRUE)
  expect_match(texto, "1234,5", fixed = TRUE)
})
