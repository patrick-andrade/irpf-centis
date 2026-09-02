sample_discovered <- function() {
  tibble::tibble(
    source_id = c("receita_expanded-aaa", "receita_wealth-bbb"),
    dataset_family = c("receita_expanded", "receita_wealth"),
    year = c(2024L, NA_integer_),
    label = c("Centis 2024", "Bens tabela 1"),
    extension = c("xlsx", "xlsx"),
    layout = c("expanded_national", "wealth_historical"),
    page_url = c("https://example.invalid/2024", "https://example.invalid/wealth"),
    url_view = c("https://example.invalid/2024/a.xlsx/view", "https://example.invalid/wealth/b.xlsx/view"),
    download_url = c("https://example.invalid/2024/a.xlsx/@@download/file", "https://example.invalid/wealth/b.xlsx/@@download/file"),
    file_name = c("a.xlsx", "b.xlsx")
  )
}

test_that("inventário idêntico não gera alteração, inclusive com year NA", {
  inventory <- sample_discovered()
  expect_equal(nrow(diff_discovered_sources(inventory, inventory)), 0L)
})

test_that("URL nova ou URL que sumiu entram em changes.csv", {
  baseline <- sample_discovered()
  added <- tibble::tibble(
    source_id = "receita_expanded-ccc",
    dataset_family = "receita_expanded",
    year = 2025L,
    label = "Centis 2025",
    extension = "xlsx",
    layout = "expanded_national",
    page_url = "https://example.invalid/2025",
    url_view = "https://example.invalid/2025/c.xlsx/view",
    download_url = "https://example.invalid/2025/c.xlsx/@@download/file",
    file_name = "c.xlsx"
  )
  current <- dplyr::bind_rows(baseline, added)
  changes <- diff_discovered_sources(current, baseline)
  expect_equal(nrow(changes), 1L)
  expect_true(isTRUE(changes$current[[1]]))
  expect_true(is.na(changes$baseline[[1]]))

  removed <- diff_discovered_sources(baseline, current)
  expect_equal(nrow(removed), 1L)
  expect_true(is.na(removed$current[[1]]))
  expect_true(isTRUE(removed$baseline[[1]]))
})

test_that("o script do monitor não carrega o restante de R/", {
  text <- paste(readLines(project_path("scripts/check-sources.R"), encoding = "UTF-8"), collapse = "\n")
  expect_false(grepl('list.files\\("R"', text))
  expect_match(text, "R/utils.R", fixed = TRUE)
  expect_match(text, "R/acquisition.R", fixed = TRUE)
})

test_that("o workflow do monitor não restaura o renv e roda no trimestre", {
  text <- paste(readLines(project_path(".github/workflows/source-monitor.yml"), encoding = "UTF-8"), collapse = "\n")
  expect_false(grepl("setup-renv", text, fixed = TRUE))
  expect_match(text, "1,4,7,10", fixed = TRUE)
})
