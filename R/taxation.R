# Alíquota efetiva média por grupo da distribuição: imposto devido dividido
# pela renda do próprio conceito de ranking. Como RB4 inclui rendimentos
# isentos e tributação exclusiva, a leitura é de carga efetiva sobre a renda
# ampla declarada, não sobre a base de cálculo legal.
effective_tax_rates <- function(distribution_bins, income_components) {
  tax <- income_components |>
    dplyr::filter(.data$component_id == "tax_due") |>
    dplyr::select(
      "year", "geo_level", "geo_code", "ranking_id", "bin_code",
      tax_due = "value_nominal"
    )
  leaf_distribution(distribution_bins) |>
    dplyr::select(
      "year", "geo_level", "geo_code", "ranking_id", "bin_code",
      "share_lower", "share_upper", "contributors", "rank_sum"
    ) |>
    dplyr::inner_join(tax, by = c("year", "geo_level", "geo_code", "ranking_id", "bin_code")) |>
    dplyr::mutate(
      # A razão só é interpretável quando o conceito de renda do ranking contém
      # a renda que foi tributada. Nos conceitos estreitos (RB5, RB9, RB10) um
      # grupo pode ter renda do conceito próxima de zero e ainda dever imposto
      # sobre rendimentos que ficam de fora dele — a divisão então produz
      # "alíquotas" de milhares por cento, que não medem carga tributária
      # nenhuma. `tax_due > rank_sum` é sinal suficiente de que o conceito não
      # cobre a base tributada; nesses casos a razão fica NA. Os valores de
      # `tax_due` e `rank_sum` permanecem na tabela, sem substituição.
      effective_rate = dplyr::if_else(
        is.finite(.data$rank_sum) & .data$rank_sum > 0 &
          is.finite(.data$tax_due) & .data$tax_due <= .data$rank_sum,
        .data$tax_due / .data$rank_sum,
        NA_real_
      )
    )
}

effective_tax_summary <- function(effective_tax) {
  thresholds <- c(all = 0, top_10 = 0.90, top_1 = 0.99, top_0_1 = 0.999)
  purrr::map_dfr(names(thresholds), function(group) {
    cutoff <- thresholds[[group]]
    effective_tax |>
      dplyr::filter(.data$share_lower >= cutoff - share_tolerance) |>
      dplyr::group_by(.data$year, .data$geo_level, .data$geo_code, .data$ranking_id) |>
      dplyr::summarise(
        tax_due = sum(.data$tax_due, na.rm = TRUE),
        income = sum(.data$rank_sum, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::mutate(
        group = group,
        effective_rate = dplyr::if_else(
          .data$income > 0 & .data$tax_due <= .data$income,
          .data$tax_due / .data$income,
          NA_real_
        )
      )
  })
}
