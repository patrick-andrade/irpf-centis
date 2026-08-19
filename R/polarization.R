lorenz_at_half <- function(data) {
  lorenz <- grouped_lorenz(data)
  if (anyNA(lorenz)) return(NA_real_)
  stats::approx(lorenz$p, lorenz$l, xout = 0.5, ties = "ordered")$y
}

grouped_wolfson <- function(data) {
  mu <- sum(data$rank_sum, na.rm = TRUE) / sum(data$contributors, na.rm = TRUE)
  median <- grouped_quantile_limit(data, 0.5)
  gini <- grouped_gini(data)
  l_half <- lorenz_at_half(data)
  if (!is.finite(mu) || !is.finite(median) || median <= 0 || !is.finite(gini) || !is.finite(l_half)) return(NA_real_)
  2 * (mu / median) * (0.5 - l_half) - gini
}

grouped_esteban_ray <- function(data, alpha = 1.3) {
  d <- prepare_grouped_distribution(data)
  if (nrow(d) == 0L || alpha < 1 || alpha > 1.6) return(NA_real_)
  p <- d$weight / sum(d$weight)
  mu <- sum(p * d$value)
  if (mu <= 0) return(NA_real_)
  distance <- abs(outer(d$value, d$value, "-")) / mu
  sum(outer(p^(1 + alpha), p, "*") * distance)
}

calculate_polarization_metrics <- function(data) {
  tibble::tibble(
    wolfson_grouped = grouped_wolfson(data),
    esteban_ray_a10 = grouped_esteban_ray(data, 1.0),
    esteban_ray_a13 = grouped_esteban_ray(data, 1.3),
    esteban_ray_a16 = grouped_esteban_ray(data, 1.6)
  )
}
