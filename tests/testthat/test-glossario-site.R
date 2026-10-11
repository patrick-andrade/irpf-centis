# Página de glossário do site: cada conceito e cada indicador do contrato tem
# a âncora para onde apontam os "?" das páginas Explorar.

test_that("glossário tem âncora para todo conceito e todo indicador", {
  md <- glossario_markdown()
  texto <- paste(md, collapse = "\n")
  for (id in read_schema("rankings")$ranking_id) {
    expect_match(texto, paste0("{#", ancora_conceito(id), "}"), fixed = TRUE)
  }
  for (id in read_schema("indicators")$indicator_id) {
    expect_match(texto, paste0("{#", ancora_indicador(id), "}"), fixed = TRUE)
  }
})

test_that("fichas trazem leitura, faixa, nota agrupada e referências com DOI", {
  texto <- paste(glossario_markdown(), collapse = "\n")
  expect_match(texto, "**Como ler:**", fixed = TRUE)
  expect_match(texto, "**Cálculo com dados agrupados:**", fixed = TRUE)
  expect_match(texto, "](https://doi.org/", fixed = TRUE)
  # Wolfson e Palma não são limitados por construção.
  expect_match(texto, "**Atenção:** indicador não limitado", fixed = TRUE)
})

test_that("referências inexistentes não quebram a lista", {
  refs <- read_schema("references")
  expect_equal(referencias_markdown("chave_que_nao_existe", refs), character())
  expect_length(referencias_markdown(paste(refs$key[1:2], collapse = ";"), refs), 2L)
})
