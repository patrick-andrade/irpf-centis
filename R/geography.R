theil_decomposition_uf <- function(distribution_bins, ranking = "RB4") {
  data <- leaf_distribution(distribution_bins) |>
    dplyr::filter(.data$geo_level == "state", .data$ranking_id == ranking)
  if (nrow(data) == 0L) return(tibble::tibble())

  purrr::map_dfr(sort(unique(data$year)), function(selected_year) {
    year_data <- dplyr::filter(data, .data$year == selected_year)
    states <- year_data |>
      dplyr::group_by(.data$geo_code) |>
      dplyr::group_modify(~ tibble::tibble(
        population = sum(.x$contributors, na.rm = TRUE),
        income = sum(.x$rank_sum, na.rm = TRUE),
        theil = grouped_theil_t(.x)
      )) |>
      dplyr::ungroup() |>
      dplyr::mutate(mean = .data$income / .data$population)
    total_population <- sum(states$population)
    total_income <- sum(states$income)
    overall_mean <- total_income / total_population
    between <- sum((states$income / total_income) * log(states$mean / overall_mean), na.rm = TRUE)
    within <- sum((states$income / total_income) * states$theil, na.rm = TRUE)
    tibble::tibble(
      year = selected_year, ranking_id = ranking,
      theil_within_uf = within, theil_between_uf = between,
      theil_total_grouped = within + between,
      grouped_estimate = TRUE
    )
  })
}
