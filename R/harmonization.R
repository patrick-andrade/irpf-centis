bind_parsed_results <- function(parsed, element, empty_factory) {
  if (length(parsed) == 0L) return(empty_factory())
  result <- dplyr::bind_rows(purrr::map(parsed, element))
  if (nrow(result) == 0L) empty_factory() else result
}

normalize_source_units <- function(distribution_bins, income_components) {
  legacy_year <- distribution_bins$year <= 2021L
  distribution_bins$rank_sum[legacy_year] <- distribution_bins$rank_sum[legacy_year] * 1e6
  distribution_bins$rank_cumulative[legacy_year] <- distribution_bins$rank_cumulative[legacy_year] * 1e6

  legacy_component <- income_components$year <= 2021L & income_components$unit == "BRL"
  income_components$value_nominal[legacy_component] <-
    income_components$value_nominal[legacy_component] * 1e6

  list(
    distribution_bins = distribution_bins,
    income_components = income_components
  )
}

read_ipca_deflators <- function(path = "data/external/ipca-annual.csv") {
  path <- project_path(path)
  if (!fs::file_exists(path)) {
    rlang::abort(c(
      "Deflatores IPCA não encontrados: valores reais não podem ser calculados.",
      "i" = "Execute `run.cmd context` para baixar o IPCA anual do SIDRA."
    ))
  }
  deflators <- readr::read_csv(path, show_col_types = FALSE)
  required <- c("year", "annual_average_index", "deflator_to_2024")
  missing <- setdiff(required, names(deflators))
  if (nrow(deflators) == 0L || length(missing) > 0L) {
    rlang::abort(c(
      paste0("Arquivo de deflatores inválido em ", path, "."),
      "i" = "Execute `run.cmd context` para regenerá-lo."
    ))
  }
  deflators
}

apply_deflators <- function(distribution_bins, income_components, deflators) {
  missing_years <- setdiff(unique(distribution_bins$year), deflators$year)
  if (length(missing_years) > 0L) {
    rlang::abort(c(
      paste0(
        "Sem deflator IPCA para os anos: ",
        paste(sort(missing_years), collapse = ", "), "."
      ),
      "i" = "Execute `run.cmd context` para atualizar a série do IPCA."
    ))
  }
  bins <- distribution_bins |>
    dplyr::left_join(dplyr::select(deflators, "year", "deflator_to_2024"), by = "year") |>
    dplyr::mutate(
      rank_upper_real = .data$rank_upper * .data$deflator_to_2024,
      rank_sum_real = .data$rank_sum * .data$deflator_to_2024,
      rank_cumulative_real = .data$rank_cumulative * .data$deflator_to_2024,
      rank_mean_real = .data$rank_mean * .data$deflator_to_2024
    )
  components <- income_components |>
    dplyr::left_join(dplyr::select(deflators, "year", "deflator_to_2024"), by = "year") |>
    dplyr::mutate(value_real = .data$value_nominal * .data$deflator_to_2024)
  list(distribution_bins = bins, income_components = components)
}

leaf_distribution <- function(distribution_bins) {
  distribution_bins |>
    dplyr::filter(.data$is_leaf, .data$bin_code %in% c(1:99, 101:109, 111:120))
}
