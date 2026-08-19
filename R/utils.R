`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

# Tolerância numérica para comparações de participações acumuladas (fronteiras
# de topo/base construídas por somas de frações decimais).
share_tolerance <- 1e-9

project_root <- function(start = getwd()) {
  current <- fs::path_abs(start)
  repeat {
    if (fs::file_exists(fs::path(current, ".R-version")) &&
        fs::file_exists(fs::path(current, "DESCRIPTION"))) return(current)
    parent <- fs::path_dir(current)
    if (identical(parent, current)) {
      rlang::abort("Raiz do projeto não encontrada a partir do diretório atual.")
    }
    current <- parent
  }
}

project_path <- function(...) {
  fs::path(project_root(), ...)
}

read_project_config <- function(path = "config/project.yml") {
  yaml::read_yaml(project_path(path))
}

read_sources_config <- function(path = "config/sources.yml") {
  yaml::read_yaml(project_path(path))
}

read_schema <- function(name) {
  readr::read_csv(
    project_path("config", "schema", paste0(name, ".csv")),
    show_col_types = FALSE,
    na = c("", "NA")
  )
}

normalize_text <- function(x) {
  x |>
    as.character() |>
    stringi::stri_trans_general("Latin-ASCII") |>
    stringr::str_to_lower() |>
    stringr::str_replace_all("[^a-z0-9]+", " ") |>
    stringr::str_squish()
}

slugify <- function(x) {
  x |>
    normalize_text() |>
    stringr::str_replace_all(" ", "-") |>
    stringr::str_replace_all("(^-|-$)", "")
}

as_numeric_safe <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))
  text <- stringr::str_squish(as.character(x))
  result <- suppressWarnings(as.numeric(text))
  comma_decimal <- which(is.na(result) & !is.na(text) & grepl(",", text, fixed = TRUE))
  if (length(comma_decimal) > 0L) {
    result[comma_decimal] <- suppressWarnings(readr::parse_number(
      text[comma_decimal],
      locale = readr::locale(decimal_mark = ",", grouping_mark = "."),
      na = c("", "NA", "-", "...", "..")
    ))
  }
  result
}

write_csv_atomic <- function(x, path) {
  fs::dir_create(fs::path_dir(path), recurse = TRUE)
  tmp <- tempfile(pattern = "write-", tmpdir = fs::path_dir(path), fileext = ".csv")
  readr::write_csv(x, tmp, na = "")
  if (fs::file_exists(path)) fs::file_delete(path)
  fs::file_move(tmp, path)
  invisible(path)
}

empty_distribution_bins <- function() {
  tibble::tibble(
    year = integer(), geo_level = character(), geo_code = character(),
    ranking_id = character(), bin_code = integer(), bin_level = character(),
    parent_bin = integer(), is_aggregate = logical(), is_leaf = logical(),
    share_lower = double(), share_upper = double(), contributors = double(),
    joint_returns = double(), rank_upper = double(), rank_sum = double(),
    rank_cumulative = double(), rank_mean = double(), source_id = character(),
    source_file = character(), source_sheet = character()
  )
}

empty_income_components <- function() {
  tibble::tibble(
    year = integer(), geo_level = character(), geo_code = character(),
    ranking_id = character(), bin_code = integer(), component_id = character(),
    component_group = character(), field_label = character(), unit = character(),
    value_nominal = double(), source_id = character(), source_file = character(),
    source_sheet = character()
  )
}
