find_test_project_root <- function(start = getwd()) {
  current <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(current, ".R-version")) &&
        file.exists(file.path(current, "DESCRIPTION"))) return(current)
    parent <- dirname(current)
    if (identical(parent, current)) stop("Raiz do projeto não encontrada.")
    current <- parent
  }
}

test_project_root <- find_test_project_root()
source_files <- sort(list.files(file.path(test_project_root, "R"), pattern = "\\.R$", full.names = TRUE))
invisible(lapply(source_files, source, encoding = "UTF-8", local = globalenv()))
