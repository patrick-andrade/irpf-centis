test_that("hash de fonte conhecida é conferido antes de substituir o arquivo", {
  old <- tempfile(fileext = ".xlsx")
  candidate <- tempfile(fileext = ".xlsx")
  on.exit(unlink(c(old, candidate)), add = TRUE)
  writeBin(charToRaw("versao anterior"), old)
  writeBin(charToRaw("versao alterada"), candidate)

  expected <- digest::digest(old, algo = "sha256", file = TRUE)
  expect_identical(check_source_hash(old, expected, "fonte-1"), expected)
  expect_error(
    check_source_hash(candidate, expected, "fonte-1"),
    "Hash divergente para fonte conhecida fonte-1"
  )
  expect_identical(readBin(old, "raw", n = 100L), charToRaw("versao anterior"))
})

test_that("cópia local alterada de fonte conhecida não vira novo manifesto", {
  root <- tempfile(pattern = "irpf-cache-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  subject <- download_one_source
  sandbox <- new.env(parent = environment(subject))
  sandbox$source_destination <- function(...) {
    fs::path(root, "data/raw/receita_expanded/2099/fixture.xlsx")
  }
  environment(subject) <- sandbox
  row <- tibble::tibble(
    source_id = "known-source", dataset_family = "receita_expanded",
    year = 2099L, extension = "xlsx", file_name = "fixture.xlsx",
    label = "Fixture", layout = "expanded_national",
    page_url = "https://example.org/", download_url = "https://example.org/fixture.xlsx"
  )
  file <- fs::path(root, "data/raw/receita_expanded/2099/fixture.xlsx")
  fs::dir_create(fs::path_dir(file), recurse = TRUE)
  writeBin(charToRaw("arquivo esperado"), file)
  expected <- digest::digest(file, algo = "sha256", file = TRUE)
  writeBin(charToRaw("arquivo alterado"), file)

  expect_error(
    subject(row, expected_sha256 = expected),
    "Hash divergente para fonte conhecida known-source"
  )
  expect_identical(readBin(file, "raw", n = 100L), charToRaw("arquivo alterado"))
})

test_that("download alterado não substitui arquivo existente", {
  root <- tempfile(pattern = "irpf-overwrite-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  file <- fs::path(root, "data/raw/receita_expanded/2099/fixture.xlsx")
  fs::dir_create(fs::path_dir(file), recurse = TRUE)
  writeBin(charToRaw("arquivo anterior"), file)
  expected <- digest::digest(file, algo = "sha256", file = TRUE)

  subject <- download_one_source
  sandbox <- new.env(parent = environment(subject))
  sandbox$source_destination <- function(...) file
  sandbox$fetch_source_file <- function(row, path) {
    writeBin(charToRaw("download alterado"), path)
  }
  environment(subject) <- sandbox
  row <- tibble::tibble(
    source_id = "known-source", dataset_family = "receita_expanded",
    year = 2099L, extension = "xlsx", file_name = "fixture.xlsx",
    label = "Fixture", layout = "expanded_national",
    page_url = "https://example.org/", download_url = "https://example.org/fixture.xlsx"
  )

  expect_error(
    subject(row, overwrite = TRUE, expected_sha256 = expected),
    "Hash divergente para fonte conhecida known-source"
  )
  expect_identical(readBin(file, "raw", n = 100L), charToRaw("arquivo anterior"))
})

test_that("URL nova não reutiliza o arquivo local de outra fonte", {
  row <- tibble::tibble(
    source_id = "nova-fonte", dataset_family = "receita_expanded",
    year = 2099L, extension = "xlsx", file_name = "fixture.xlsx",
    label = "Fixture", layout = "expanded_national",
    page_url = "https://example.org/", download_url = "https://example.org/nova.xlsx"
  )
  old <- tibble::tibble(
    source_id = "fonte-anterior",
    local_path = as.character(fs::path_rel(source_destination(row))),
    download_url = "https://example.org/antiga.xlsx", sha256 = "hash-anterior"
  )
  subject <- download_sources
  sandbox <- new.env(parent = environment(subject))
  sandbox$read_source_manifest <- function(...) old
  environment(subject) <- sandbox

  expect_error(subject(row), "Caminho local já vinculado a outra fonte")
})
