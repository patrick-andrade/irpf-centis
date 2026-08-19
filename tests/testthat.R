library(testthat)

source_files <- sort(list.files("R", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(source_files, source, encoding = "UTF-8"))

test_dir("tests/testthat")
