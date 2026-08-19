roman_rankings <- function() {
  read_schema("rankings") |>
    dplyr::select("roman", "ranking_id")
}

parse_sheet_identity <- function(sheet_name) {
  geos <- read_schema("geographies")$geo_code
  rankings <- roman_rankings()
  clean <- stringr::str_to_upper(stringr::str_replace_all(sheet_name, "[^A-Za-z0-9]", ""))
  geo <- geos[stringr::str_starts(clean, geos)][1]
  if (is.na(geo)) return(NULL)
  suffix <- stringr::str_remove(clean, paste0("^", geo))
  ranking <- rankings$ranking_id[match(suffix, rankings$roman)]
  if (is.na(ranking)) return(NULL)
  list(geo_code = geo, ranking_id = ranking)
}

bin_attributes <- function(bin_code) {
  code <- as.integer(bin_code)
  if (length(code) != 1L || is.na(code)) {
    return(tibble::tibble(
      bin_level = NA_character_, parent_bin = NA_integer_, is_aggregate = NA,
      share_lower = NA_real_, share_upper = NA_real_, is_leaf = NA
    ))
  }
  result <- if (code <= 99L) {
    tibble::tibble(
      bin_level = "centile", parent_bin = NA_integer_, is_aggregate = FALSE,
      share_lower = (code - 1) / 100, share_upper = code / 100
    )
  } else if (code == 100L) {
    tibble::tibble(
      bin_level = "top_1_aggregate", parent_bin = NA_integer_, is_aggregate = TRUE,
      share_lower = 0.99, share_upper = 1
    )
  } else if (code >= 101L && code <= 110L) {
    tibble::tibble(
      bin_level = "top_1_tenth", parent_bin = 100L, is_aggregate = code == 110L,
      share_lower = 0.99 + (code - 101) / 1000,
      share_upper = 0.99 + (code - 100) / 1000
    )
  } else if (code >= 111L && code <= 120L) {
    tibble::tibble(
      bin_level = "top_0_1_tenth", parent_bin = 110L, is_aggregate = FALSE,
      share_lower = 0.999 + (code - 111) / 10000,
      share_upper = 0.999 + (code - 110) / 10000
    )
  } else {
    tibble::tibble(
      bin_level = NA_character_, parent_bin = NA_integer_, is_aggregate = NA,
      share_lower = NA_real_, share_upper = NA_real_
    )
  }
  dplyr::mutate(result, is_leaf = !.data$is_aggregate)
}

resolve_field_ids <- function(headers) {
  fields <- read_schema("fields")
  normalized <- normalize_text(headers)
  ids <- rep(NA_character_, length(headers))
  current_layout <- length(headers) >= max(fields$position_2024, na.rm = TRUE)

  for (j in seq_along(ids)) {
    hits <- which(purrr::map_lgl(fields$regex, function(pattern) {
      if (is.na(pattern) || pattern == "") return(FALSE)
      stringr::str_detect(normalized[[j]], stringr::regex(pattern, ignore_case = TRUE))
    }))
    if (length(hits) > 0L) ids[[j]] <- fields$field_id[[hits[[1]]]]
    if (is.na(ids[[j]]) && current_layout) {
      positional <- which(fields$position_2024 == j)
      if (length(positional) == 1L) ids[[j]] <- fields$field_id[[positional]]
    }
    if (is.na(ids[[j]])) ids[[j]] <- paste0("unmapped_", j)
  }
  make.unique(ids, sep = "__duplicate_")
}

read_receita_sheet <- function(path, sheet, year, source_id) {
  identity <- parse_sheet_identity(sheet)
  if (is.null(identity)) return(NULL)
  raw <- readxl::read_excel(path, sheet = sheet, col_names = FALSE, .name_repair = "minimal", progress = FALSE)
  if (nrow(raw) == 0L || ncol(raw) == 0L) return(NULL)

  raw <- raw[, !purrr::map_lgl(raw, ~ all(is.na(.x))), drop = FALSE]
  char <- as.data.frame(purrr::map(raw, as.character), stringsAsFactors = FALSE)
  normalized_matrix <- matrix(normalize_text(unlist(char, use.names = FALSE)), nrow = nrow(char), ncol = ncol(char))
  centile_cells <- which(normalized_matrix == "centil", arr.ind = TRUE)
  if (nrow(centile_cells) == 0L) return(NULL)
  header_row <- min(centile_cells[, "row"])
  centile_col <- centile_cells[which.min(centile_cells[, "row"]), "col"]
  primary_codes <- suppressWarnings(as.integer(as_numeric_safe(raw[[centile_col]])))
  analytical_codes <- primary_codes
  hierarchy_width <- 1L

  # Nos arquivos monolíticos antigos, os códigos 101–110 e 111–120
  # aparecem como 1–10 em duas colunas hierárquicas adjacentes.
  if (ncol(raw) >= centile_col + 2L) {
    secondary <- suppressWarnings(as.integer(as_numeric_safe(raw[[centile_col + 1L]])))
    tertiary <- suppressWarnings(as.integer(as_numeric_safe(raw[[centile_col + 2L]])))
    secondary_rows <- is.na(primary_codes) & secondary %in% 1:10
    tertiary_rows <- is.na(primary_codes) & is.na(secondary) & tertiary %in% 1:10
    if (sum(secondary_rows, na.rm = TRUE) == 10L && sum(tertiary_rows, na.rm = TRUE) == 10L) {
      analytical_codes[secondary_rows] <- 100L + secondary[secondary_rows]
      analytical_codes[tertiary_rows] <- 110L + tertiary[tertiary_rows]
      hierarchy_width <- 3L
    }
  }

  data_rows <- which(seq_len(nrow(raw)) > header_row & analytical_codes %in% 1:120)
  if (length(data_rows) == 0L) return(NULL)
  data_start <- min(data_rows)
  data_rows <- data_rows[analytical_codes[data_rows] %in% 1:120]

  keep_cols <- c(centile_col, (centile_col + hierarchy_width):ncol(raw))
  headers <- purrr::map_chr(keep_cols, function(j) {
    parts <- unlist(char[header_row:(data_start - 1L), j], use.names = FALSE)
    parts <- parts[!is.na(parts) & stringr::str_squish(parts) != ""]
    stringr::str_squish(paste(unique(parts), collapse = " | "))
  })
  field_ids <- resolve_field_ids(headers)
  values <- raw[data_rows, keep_cols, drop = FALSE]
  values[[1]] <- analytical_codes[data_rows]
  names(values) <- field_ids
  values <- values |>
    dplyr::mutate(dplyr::across(dplyr::everything(), as_numeric_safe)) |>
    dplyr::filter(.data$centile %in% 1:120)

  required_fields <- c("centile", "contributors", "rank_upper", "rank_sum", "rank_cumulative", "rank_mean")
  missing_fields <- setdiff(required_fields, names(values))
  if (length(missing_fields) > 0L) {
    rlang::abort(paste(
      "Campos fixos ausentes em", fs::path_file(path), sheet, ":",
      paste(missing_fields, collapse = ", ")
    ))
  }
  if (!"joint_returns" %in% names(values)) values$joint_returns <- NA_real_

  geographies <- read_schema("geographies")
  geo <- dplyr::filter(geographies, .data$geo_code == identity$geo_code)
  attrs <- purrr::map_dfr(values$centile, bin_attributes)
  distribution <- dplyr::bind_cols(
    tibble::tibble(
      year = as.integer(year), geo_level = geo$geo_level[[1]],
      geo_code = identity$geo_code, ranking_id = identity$ranking_id,
      bin_code = as.integer(values$centile)
    ),
    attrs,
    tibble::tibble(
      contributors = values$contributors,
      joint_returns = values$joint_returns,
      rank_upper = values$rank_upper,
      rank_sum = values$rank_sum,
      rank_cumulative = values$rank_cumulative,
      rank_mean = values$rank_mean,
      source_id = source_id,
      source_file = fs::path_file(path),
      source_sheet = sheet
    )
  )

  component_columns <- setdiff(names(values), fixed <- c(
    "centile", "contributors", "joint_returns", "rank_upper",
    "rank_sum", "rank_cumulative", "rank_mean"
  ))
  fields <- read_schema("fields")
  components <- values |>
    dplyr::select("centile", dplyr::all_of(component_columns)) |>
    tidyr::pivot_longer(-"centile", names_to = "component_id", values_to = "value_nominal") |>
    dplyr::mutate(component_id = stringr::str_remove(.data$component_id, "__duplicate_.*$")) |>
    dplyr::left_join(
      dplyr::select(fields, "field_id", component_group = "group", field_label = "label", "unit"),
      by = c("component_id" = "field_id")
    ) |>
    dplyr::mutate(
      component_group = dplyr::coalesce(.data$component_group, "unmapped"),
      field_label = dplyr::coalesce(.data$field_label, .data$component_id),
      unit = dplyr::coalesce(.data$unit, "unknown"),
      year = as.integer(year), geo_level = geo$geo_level[[1]],
      geo_code = identity$geo_code, ranking_id = identity$ranking_id,
      bin_code = as.integer(.data$centile), source_id = source_id,
      source_file = fs::path_file(path), source_sheet = sheet
    ) |>
    dplyr::select(
      "year", "geo_level", "geo_code", "ranking_id",
      "bin_code", "component_id", "component_group",
      "field_label", "unit", "value_nominal", "source_id",
      "source_file", "source_sheet"
    )

  list(distribution_bins = distribution, income_components = components)
}

parse_receita_workbook <- function(path, year, source_id) {
  sheets <- readxl::excel_sheets(path)
  parsed <- purrr::map(sheets, ~ read_receita_sheet(path, .x, year, source_id))
  parsed <- purrr::compact(parsed)
  if (length(parsed) == 0L) {
    rlang::abort(paste("Nenhuma aba distributiva reconhecida em", fs::path_file(path)))
  }
  list(
    distribution_bins = dplyr::bind_rows(purrr::map(parsed, "distribution_bins")),
    income_components = dplyr::bind_rows(purrr::map(parsed, "income_components"))
  )
}

parse_manifest_file <- function(path, manifest) {
  rel <- fs::path_rel(path)
  row <- manifest |>
    dplyr::filter(.data$local_path == rel | fs::path_abs(.data$local_path) == fs::path_abs(path))
  if (nrow(row) != 1L) rlang::abort(paste("Fonte não identificada no manifesto:", path))
  if (row$dataset_family[[1]] == "receita_wealth") {
    return(list(
      distribution_bins = empty_distribution_bins(),
      income_components = empty_income_components()
    ))
  }
  parse_receita_workbook(path, row$year[[1]], row$source_id[[1]])
}
