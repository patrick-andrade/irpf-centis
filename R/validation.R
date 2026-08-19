manifest_xlsx_specs <- function(manifest) {
  rows <- manifest |>
    dplyr::filter(.data$extension == "xlsx", .data$status %in% c("downloaded", "cached"))
  if (nrow(rows) == 0L) return(list())
  split(rows, seq_len(nrow(rows)))
}

validate_manifest_spec <- function(spec) {
  stopifnot(nrow(spec) == 1L)
  path <- project_path(spec$local_path[[1]])
  if (!fs::file_exists(path)) rlang::abort(paste("Arquivo ausente:", path))
  actual <- digest::digest(path, algo = "sha256", file = TRUE)
  if (!identical(actual, spec$sha256[[1]])) rlang::abort(paste("Hash divergente:", path))
  path
}

validate_unique_keys <- function(distribution_bins) {
  duplicates <- distribution_bins |>
    dplyr::count(.data$year, .data$geo_level, .data$geo_code, .data$ranking_id, .data$bin_code) |>
    dplyr::filter(.data$n > 1L)
  tibble::tibble(
    check = "unique_distribution_key",
    status = ifelse(nrow(duplicates) == 0L, "pass", "fail"),
    detail = ifelse(nrow(duplicates) == 0L, "Chaves únicas", paste(nrow(duplicates), "chaves duplicadas"))
  )
}

validate_bin_counts <- function(distribution_bins) {
  counts <- distribution_bins |>
    dplyr::count(.data$year, .data$geo_code, .data$ranking_id, name = "raw_bins") |>
    dplyr::mutate(ok = .data$raw_bins == 120L)
  tibble::tibble(
    check = "raw_bin_count",
    status = ifelse(nrow(counts) > 0L && all(counts$ok), "pass", "fail"),
    detail = ifelse(nrow(counts) == 0L, "Sem dados", paste(sum(!counts$ok), "distribuições fora de 120 grupos"))
  )
}

validate_series_coverage <- function(distribution_bins) {
  years <- sort(unique(distribution_bins$year))
  geographies <- read_schema("geographies")$geo_code
  rankings <- read_schema("rankings")
  expected <- purrr::map_dfr(years, function(year) {
    available <- rankings |>
      dplyr::filter(
        .data$year_min <= year,
        is.na(.data$year_max) | .data$year_max >= year
      ) |>
      dplyr::pull("ranking_id")
    tidyr::expand_grid(year = year, geo_code = geographies, ranking_id = available)
  })
  observed <- distribution_bins |>
    dplyr::distinct(.data$year, .data$geo_code, .data$ranking_id)
  missing <- dplyr::anti_join(expected, observed, by = c("year", "geo_code", "ranking_id"))
  tibble::tibble(
    check = "series_coverage",
    status = ifelse(nrow(missing) == 0L, "pass", "warn"),
    detail = ifelse(
      nrow(missing) == 0L,
      "Todas as combinações esperadas estão presentes",
      paste0(
        nrow(missing), " combinação(ões) ausente(s) na fonte: ",
        paste(paste(missing$year, missing$geo_code, missing$ranking_id, sep = "-"), collapse = ", ")
      )
    )
  )
}

reconcile_hierarchy <- function(distribution_bins, tolerance = 0.01) {
  wide <- distribution_bins |>
    dplyr::select("year", "geo_code", "ranking_id", "bin_code", "contributors", "rank_sum") |>
    dplyr::group_by(.data$year, .data$geo_code, .data$ranking_id) |>
    dplyr::group_modify(function(.x, .y) {
      get_value <- function(code, field) .x[[field]][match(code, .x$bin_code)]
      tibble::tibble(
        contributors_100_gap = get_value(100, "contributors") - sum(.x$contributors[.x$bin_code %in% 101:110], na.rm = TRUE),
        contributors_110_gap = get_value(110, "contributors") - sum(.x$contributors[.x$bin_code %in% 111:120], na.rm = TRUE),
        rank_sum_100_gap = get_value(100, "rank_sum") - sum(.x$rank_sum[.x$bin_code %in% 101:110], na.rm = TRUE),
        rank_sum_110_gap = get_value(110, "rank_sum") - sum(.x$rank_sum[.x$bin_code %in% 111:120], na.rm = TRUE)
      )
    }) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      contributor_ok = abs(.data$contributors_100_gap) <= 1 &
        abs(.data$contributors_110_gap) <= 1,
      amount_ok = abs(.data$rank_sum_100_gap) <= tolerance &
        abs(.data$rank_sum_110_gap) <= tolerance,
      ok = .data$contributor_ok & .data$amount_ok
    )
  wide
}

run_quality_checks <- function(distribution_bins) {
  if (nrow(distribution_bins) == 0L) {
    return(tibble::tibble(check = "data_available", status = "fail", detail = "Nenhum dado normalizado"))
  }
  hierarchy <- reconcile_hierarchy(distribution_bins)
  dplyr::bind_rows(
    validate_unique_keys(distribution_bins),
    validate_bin_counts(distribution_bins),
    validate_series_coverage(distribution_bins),
    tibble::tibble(
      check = "hierarchical_contributors",
      status = ifelse(all(hierarchy$contributor_ok), "pass", "fail"),
      detail = paste(sum(!hierarchy$contributor_ok), "distribuições com divergência de contagem")
    ),
    tibble::tibble(
      check = "hierarchical_amounts",
      status = ifelse(all(hierarchy$amount_ok), "pass", "warn"),
      detail = paste(
        sum(!hierarchy$amount_ok),
        "distribuições com divergência monetária preservada da fonte; ver hierarchy-reconciliation.csv"
      )
    ),
    tibble::tibble(
      check = "leaf_bin_count",
      status = ifelse(
        all(leaf_distribution(distribution_bins) |>
          dplyr::count(.data$year, .data$geo_code, .data$ranking_id) |>
          dplyr::pull("n") == 118L),
        "pass", "fail"
      ),
      detail = "A visão analítica deve conter 118 grupos disjuntos"
    )
  )
}

assert_quality <- function(checks) {
  failures <- dplyr::filter(checks, .data$status == "fail")
  if (nrow(failures) > 0L) {
    rlang::abort(paste("Falhas de qualidade:", paste(failures$check, collapse = ", ")))
  }
  invisible(checks)
}
