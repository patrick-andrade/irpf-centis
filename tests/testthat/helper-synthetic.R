synthetic_distribution <- function(year = 2024L, geo_code = "BR", ranking_id = "RB4") {
  codes <- 1:120
  attributes <- purrr::map_dfr(codes, bin_attributes)
  leaf_income <- c(rep(100, 99), rep(20, 9), rep(3, 10))
  leaf_people <- c(rep(100, 99), rep(10, 9), rep(1, 10))
  rank_sum <- rep(NA_real_, 120)
  contributors <- rep(NA_real_, 120)
  leaf_codes <- c(1:99, 101:109, 111:120)
  rank_sum[leaf_codes] <- leaf_income
  contributors[leaf_codes] <- leaf_people
  rank_sum[110] <- sum(rank_sum[111:120], na.rm = TRUE)
  contributors[110] <- sum(contributors[111:120], na.rm = TRUE)
  rank_sum[100] <- sum(rank_sum[101:110], na.rm = TRUE)
  contributors[100] <- sum(contributors[101:110], na.rm = TRUE)

  tibble::tibble(
    year = as.integer(year), geo_level = ifelse(geo_code == "BR", "national", "state"),
    geo_code = geo_code, ranking_id = ranking_id, bin_code = codes
  ) |>
    dplyr::bind_cols(attributes) |>
    dplyr::mutate(
      contributors = contributors,
      joint_returns = 0,
      rank_upper = dplyr::coalesce(rank_sum / contributors, 0),
      rank_sum = rank_sum,
      rank_cumulative = cumsum(dplyr::coalesce(rank_sum, 0)),
      rank_mean = dplyr::coalesce(rank_sum / contributors, 0),
      source_id = "synthetic", source_file = "fixture.xlsx", source_sheet = "BRIV"
    )
}
