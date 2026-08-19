test_that("as_numeric_safe entende vírgula decimal e marcadores de ausência", {
  expect_equal(as_numeric_safe("1.234,56"), 1234.56)
  expect_equal(as_numeric_safe("12,5"), 12.5)
  expect_equal(as_numeric_safe("1234.56"), 1234.56)
  expect_equal(as_numeric_safe(c("10", "-", "...")), c(10, NA, NA))
  expect_equal(as_numeric_safe(5L), 5)
  expect_equal(as_numeric_safe("1e+06"), 1e6)
})

test_that("normalize_text remove acentos e pontuação para casar regexes", {
  expect_equal(normalize_text("Média do RB4 (R$)"), "media do rb4 r")
  expect_equal(normalize_text("  Imposto   Devido  "), "imposto devido")
})
