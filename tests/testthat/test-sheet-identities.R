test_that("nomes de abas antigos e atuais são reconhecidos", {
  expect_equal(parse_sheet_identity("BRI"), list(geo_code = "BR", ranking_id = "RTB"))
  expect_equal(parse_sheet_identity("SPV"), list(geo_code = "SP", ranking_id = "RB4"))
  expect_equal(parse_sheet_identity("PIIII"), list(geo_code = "PI", ranking_id = "RB2"))
  expect_equal(parse_sheet_identity("BRXI"), list(geo_code = "BR", ranking_id = "RB10"))
  expect_null(parse_sheet_identity("Metadados"))
})

test_that("layouts de fonte são classificados sem confundir PDF", {
  expect_equal(classify_source_layout("Metadados_2024.pdf", 2024, "receita_expanded"), "metadata")
  expect_equal(classify_source_layout("Distribuicao_Renda_Centis_BR.xlsx", 2024, "receita_expanded"), "expanded_national")
  expect_equal(classify_source_layout("Distribuicao_Renda_Centis_SP_UF.xlsx", 2024, "receita_expanded"), "expanded_regional")
  expect_equal(classify_source_layout("Distribuicao_Renda_Centis.xlsx", 2017, "receita_expanded"), "expanded_monolithic")
})
