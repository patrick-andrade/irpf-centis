prepare_grouped_distribution <- function(data, value_col = "rank_mean", weight_col = "contributors") {
  value <- data[[value_col]]
  weight <- data[[weight_col]]
  keep <- is.finite(value) & is.finite(weight) & weight > 0 & value >= 0
  tibble::tibble(value = value[keep], weight = weight[keep]) |>
    dplyr::arrange(.data$value)
}

grouped_lorenz <- function(data, value_col = "rank_mean", weight_col = "contributors") {
  d <- prepare_grouped_distribution(data, value_col, weight_col)
  total_income <- sum(d$value * d$weight)
  total_weight <- sum(d$weight)
  if (nrow(d) == 0L || total_income <= 0 || total_weight <= 0) return(tibble::tibble(p = NA_real_, l = NA_real_))
  tibble::tibble(
    p = c(0, cumsum(d$weight) / total_weight),
    l = c(0, cumsum(d$value * d$weight) / total_income)
  )
}

grouped_gini <- function(data, value_col = "rank_mean", weight_col = "contributors") {
  lorenz <- grouped_lorenz(data, value_col, weight_col)
  if (anyNA(lorenz)) return(NA_real_)
  1 - sum((head(lorenz$l, -1) + tail(lorenz$l, -1)) * diff(lorenz$p))
}

# Limites de Gastwirth (1972) para o Gini com dados agrupados: o limite
# inferior é o trapézio sobre as médias de faixa (grouped_gini); o superior
# soma a desigualdade intragrupo máxima compatível com a média e os limites
# monetários de cada faixa (distribuição de dois pontos). A faixa superior é
# aberta, então seu máximo intragrupo é o supremo 1 - a/m.
grouped_gini_bounds <- function(data,
                                value_col = "rank_mean",
                                weight_col = "contributors",
                                upper_col = "rank_upper",
                                order_col = "share_lower") {
  lower <- grouped_gini(data, value_col, weight_col)
  if (!is.finite(lower)) {
    return(tibble::tibble(gini_lower_bound = NA_real_, gini_upper_bound = NA_real_))
  }
  ordered <- data[order(data[[order_col]]), , drop = FALSE]
  mean_i <- ordered[[value_col]]
  weight_i <- ordered[[weight_col]]
  upper_i <- ordered[[upper_col]]
  keep <- is.finite(mean_i) & is.finite(weight_i) & weight_i > 0 & mean_i >= 0
  mean_i <- mean_i[keep]
  weight_i <- weight_i[keep]
  upper_i <- upper_i[keep]
  lower_i <- dplyr::lag(upper_i, default = 0)
  lower_i[!is.finite(lower_i)] <- 0
  pop_share <- weight_i / sum(weight_i)
  income_share <- (mean_i * weight_i) / sum(mean_i * weight_i)
  gini_max_within <- ifelse(
    mean_i <= 0,
    0,
    ifelse(
      !is.finite(upper_i),
      pmax(0, 1 - lower_i / mean_i),
      ifelse(
        upper_i > lower_i & mean_i >= lower_i & mean_i <= upper_i,
        (mean_i - lower_i) * (upper_i - mean_i) / (mean_i * (upper_i - lower_i)),
        0
      )
    )
  )
  upper <- lower + sum(pop_share * income_share * gini_max_within, na.rm = TRUE)
  tibble::tibble(gini_lower_bound = lower, gini_upper_bound = min(upper, 1))
}

grouped_theil_t <- function(data, value_col = "rank_mean", weight_col = "contributors") {
  d <- prepare_grouped_distribution(data, value_col, weight_col)
  mu <- stats::weighted.mean(d$value, d$weight)
  if (!is.finite(mu) || mu <= 0) return(NA_real_)
  ratio <- d$value / mu
  terms <- ifelse(ratio == 0, 0, ratio * log(ratio))
  sum(d$weight * terms) / sum(d$weight)
}

grouped_atkinson <- function(data, epsilon = 0.5, value_col = "rank_mean", weight_col = "contributors") {
  d <- prepare_grouped_distribution(data, value_col, weight_col)
  mu <- stats::weighted.mean(d$value, d$weight)
  if (!is.finite(mu) || mu <= 0 || epsilon < 0) return(NA_real_)
  if (epsilon == 1) {
    # Caso limite ε=1: média geométrica ponderada; renda nula leva A -> 1.
    if (any(d$value == 0)) return(1)
    log_mean <- sum(d$weight * log(d$value)) / sum(d$weight)
    return(1 - exp(log_mean) / mu)
  }
  equivalent <- (sum(d$weight * d$value^(1 - epsilon)) / sum(d$weight))^(1 / (1 - epsilon))
  1 - equivalent / mu
}

income_share_top <- function(data, proportion) {
  threshold <- 1 - proportion
  numerator <- data |>
    dplyr::filter(.data$share_lower >= threshold - share_tolerance) |>
    dplyr::summarise(value = sum(.data$rank_sum, na.rm = TRUE)) |>
    dplyr::pull("value")
  denominator <- sum(data$rank_sum, na.rm = TRUE)
  if (denominator <= 0) NA_real_ else numerator / denominator
}

income_share_bottom <- function(data, proportion) {
  numerator <- data |>
    dplyr::filter(.data$share_upper <= proportion + share_tolerance) |>
    dplyr::summarise(value = sum(.data$rank_sum, na.rm = TRUE)) |>
    dplyr::pull("value")
  denominator <- sum(data$rank_sum, na.rm = TRUE)
  if (denominator <= 0) NA_real_ else numerator / denominator
}

grouped_quantile_limit <- function(data, probability) {
  candidates <- data |>
    dplyr::filter(.data$share_upper >= probability - share_tolerance, is.finite(.data$rank_upper)) |>
    dplyr::arrange(.data$share_upper)
  if (nrow(candidates) == 0L) return(NA_real_)
  candidates$rank_upper[[1]]
}

calculate_distribution_metrics <- function(data, epsilon = 0.5) {
  p90 <- grouped_quantile_limit(data, 0.90)
  p50 <- grouped_quantile_limit(data, 0.50)
  top10 <- income_share_top(data, 0.10)
  bottom40 <- income_share_bottom(data, 0.40)
  gini_bounds <- grouped_gini_bounds(data)
  contributors_total <- sum(data$contributors, na.rm = TRUE)
  income_total_real <- if ("rank_sum_real" %in% names(data)) {
    sum(data$rank_sum_real, na.rm = TRUE)
  } else {
    NA_real_
  }
  tibble::tibble(
    contributors = contributors_total,
    income_total = sum(data$rank_sum, na.rm = TRUE),
    income_mean = sum(data$rank_sum, na.rm = TRUE) / contributors_total,
    income_total_real = income_total_real,
    income_mean_real = income_total_real / contributors_total,
    gini_grouped = gini_bounds$gini_lower_bound,
    gini_lower_bound = gini_bounds$gini_lower_bound,
    gini_upper_bound = gini_bounds$gini_upper_bound,
    theil_t_grouped = grouped_theil_t(data),
    atkinson_grouped = grouped_atkinson(data, epsilon),
    top_10_share = top10,
    top_1_share = income_share_top(data, 0.01),
    top_0_1_share = income_share_top(data, 0.001),
    top_0_01_share = income_share_top(data, 0.0001),
    bottom_40_share = bottom40,
    palma = ifelse(bottom40 > 0, top10 / bottom40, NA_real_),
    p90_p50 = ifelse(p50 > 0, p90 / p50, NA_real_)
  )
}

calculate_all_metrics <- function(distribution_bins, epsilon = 0.5) {
  leaf_distribution(distribution_bins) |>
    dplyr::group_by(.data$year, .data$geo_level, .data$geo_code, .data$ranking_id) |>
    dplyr::group_modify(~ dplyr::bind_cols(
      calculate_distribution_metrics(.x, epsilon),
      calculate_polarization_metrics(.x)
    )) |>
    dplyr::ungroup() |>
    dplyr::mutate(grouped_estimate = TRUE, atkinson_epsilon = epsilon)
}
