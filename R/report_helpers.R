# Formatação numérica em português: milhar com ponto, decimal com vírgula.
# `scales` usa as convenções do inglês por padrão, o que faria "R$ 154,061"
# ser lido como cento e cinquenta e quatro reais em vez de cento e cinquenta
# e quatro mil.
fmt_brl <- function(x, accuracy = 1) {
  scales::label_currency(
    prefix = "R$ ", accuracy = accuracy,
    big.mark = ".", decimal.mark = ","
  )(x)
}

fmt_count <- function(x) {
  scales::label_number(accuracy = 1, big.mark = ".", decimal.mark = ",")(x)
}

fmt_index <- function(x, accuracy = 0.001) {
  scales::number(x, accuracy = accuracy, big.mark = ".", decimal.mark = ",")
}

fmt_share <- function(x, accuracy = 0.1) {
  scales::percent(x, accuracy = accuracy, big.mark = ".", decimal.mark = ",")
}

label_share_ptbr <- function(accuracy = 0.1) {
  scales::label_percent(accuracy = accuracy, big.mark = ".", decimal.mark = ",")
}

read_processed_or_empty <- function(file, type = c("parquet", "csv")) {
  type <- match.arg(type)
  path <- project_path("data/processed", file)
  if (!fs::file_exists(path)) return(tibble::tibble())
  if (type == "parquet") arrow::read_parquet(path) else readr::read_csv(path, show_col_types = FALSE)
}

load_report_data <- function() {
  list(
    bins = read_processed_or_empty("distribution-bins.parquet"),
    components = read_processed_or_empty("income-components.parquet"),
    metrics = read_processed_or_empty("distribution-metrics.parquet"),
    effective_tax = read_processed_or_empty("effective-tax.parquet"),
    decomposition = read_processed_or_empty("theil-decomposition-uf.parquet"),
    wealth = read_processed_or_empty("wealth-ranked-national.parquet"),
    wealth_metrics = read_processed_or_empty("wealth-metrics.parquet"),
    checks = read_processed_or_empty("quality-checks.csv", "csv")
  )
}

report_has_data <- function(data) {
  nrow(data$bins) > 0L && nrow(data$metrics) > 0L
}

data_unavailable_callout <- function() {
  cat("\n::: {.callout-warning}\n## Dados processados ainda não disponíveis\nExecute `run.cmd download`, `run.cmd context` e `run.cmd build`. A publicação externa permanece bloqueada enquanto o checklist não estiver concluído.\n:::\n")
}

ranking_palette <- c(
  "RTB" = "#6A1B9A", "RB3" = "#F2A900", "RB4" = "#005A9C", "RB5" = "#A51C30"
)

plot_metric_evolution <- function(metrics, metric, label, geo_code = "BR", ranking = "RB4") {
  data <- metrics |>
    dplyr::filter(.data$geo_code == .env$geo_code, .data$ranking_id == .env$ranking) |>
    dplyr::arrange(.data$year)
  ggplot2::ggplot(data, ggplot2::aes(x = .data$year, y = .data[[metric]])) +
    ggplot2::geom_line(linewidth = 0.9, colour = "#005A9C") +
    ggplot2::geom_point(size = 2.4, colour = "#F2A900") +
    ggplot2::scale_x_continuous(breaks = data$year) +
    ggplot2::labs(x = NULL, y = label, caption = "Estimativa com dados agrupados do IRPF.") +
    ggplot2::theme_minimal(base_size = 11)
}

plot_top_shares <- function(metrics, geo_code = "BR", ranking = "RB4") {
  data <- metrics |>
    dplyr::filter(.data$geo_code == .env$geo_code, .data$ranking_id == .env$ranking) |>
    dplyr::select("year", `Top 10%` = "top_10_share", `Top 1%` = "top_1_share", `Top 0,1%` = "top_0_1_share") |>
    tidyr::pivot_longer(-"year", names_to = "group", values_to = "share")
  ggplot2::ggplot(data, ggplot2::aes(.data$year, .data$share, colour = .data$group)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_y_continuous(labels = label_share_ptbr(0.1)) +
    ggplot2::scale_x_continuous(breaks = sort(unique(data$year))) +
    ggplot2::scale_colour_manual(values = c("Top 10%" = "#005A9C", "Top 1%" = "#A51C30", "Top 0,1%" = "#F2A900")) +
    ggplot2::labs(x = NULL, y = "Participação na renda", colour = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}

plot_ranking_comparison <- function(metrics, metric, label, geo_code = "BR",
                                    rankings = c("RTB", "RB3", "RB4", "RB5")) {
  data <- metrics |>
    dplyr::filter(.data$geo_code == .env$geo_code, .data$ranking_id %in% .env$rankings) |>
    dplyr::arrange(.data$ranking_id, .data$year)
  plot <- ggplot2::ggplot(data, ggplot2::aes(.data$year, .data[[metric]], colour = .data$ranking_id)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_x_continuous(breaks = sort(unique(data$year))) +
    ggplot2::scale_colour_manual(values = ranking_palette) +
    ggplot2::labs(
      x = NULL, y = label, colour = "Conceito de renda",
      caption = "Estimativas com dados agrupados; conceitos definidos em config/schema/rankings.csv."
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
  if (grepl("share$", metric)) {
    plot <- plot + ggplot2::scale_y_continuous(labels = label_share_ptbr(0.1))
  }
  plot
}

plot_effective_rate_curve <- function(effective_tax, year, geo_code = "BR",
                                      ranking = "RB4", min_share = 0) {
  data <- effective_tax |>
    dplyr::filter(
      .data$year == .env$year, .data$geo_code == .env$geo_code,
      .data$ranking_id == .env$ranking, .data$share_lower >= .env$min_share,
      is.finite(.data$effective_rate)
    ) |>
    dplyr::arrange(.data$share_upper)
  ggplot2::ggplot(data, ggplot2::aes(.data$share_upper, .data$effective_rate)) +
    ggplot2::geom_line(colour = "#005A9C", linewidth = 0.8) +
    ggplot2::geom_point(colour = "#005A9C", size = 1.1) +
    ggplot2::scale_x_continuous(labels = label_share_ptbr(0.1)) +
    ggplot2::scale_y_continuous(labels = label_share_ptbr(0.1)) +
    ggplot2::labs(
      x = "Posição na distribuição (limite superior do grupo)",
      y = "Alíquota efetiva média",
      caption = "Imposto devido dividido pela renda do conceito; média de cada grupo (dados agrupados)."
    ) +
    ggplot2::theme_minimal(base_size = 11)
}

plot_effective_rate_evolution <- function(effective_tax_summary, geo_code = "BR", ranking = "RB4") {
  group_labels <- c(
    "all" = "Todos os declarantes", "top_10" = "Top 10%",
    "top_1" = "Top 1%", "top_0_1" = "Top 0,1%"
  )
  data <- effective_tax_summary |>
    dplyr::filter(.data$geo_code == .env$geo_code, .data$ranking_id == .env$ranking) |>
    dplyr::mutate(group_label = factor(group_labels[.data$group], levels = unname(group_labels))) |>
    dplyr::arrange(.data$group_label, .data$year)
  ggplot2::ggplot(data, ggplot2::aes(.data$year, .data$effective_rate, colour = .data$group_label)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_x_continuous(breaks = sort(unique(data$year))) +
    ggplot2::scale_y_continuous(labels = label_share_ptbr(0.1)) +
    ggplot2::scale_colour_manual(values = c(
      "Todos os declarantes" = "#4D4D4D", "Top 10%" = "#005A9C",
      "Top 1%" = "#A51C30", "Top 0,1%" = "#F2A900"
    )) +
    ggplot2::labs(x = NULL, y = "Alíquota efetiva média", colour = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}

latest_metrics_table <- function(metrics, ranking = "RB4") {
  if (nrow(metrics) == 0L) return(tibble::tibble())
  latest <- max(metrics$year, na.rm = TRUE)
  metrics |>
    dplyr::filter(.data$year == latest, .data$ranking_id == .env$ranking, .data$geo_level == "state") |>
    dplyr::select(
      UF = "geo_code", Declarantes = "contributors",
      `Renda média (R$ de 2024)` = "income_mean_real", `Gini agrupado` = "gini_grouped",
      `Top 1%` = "top_1_share"
    ) |>
    dplyr::arrange(dplyr::desc(.data$`Gini agrupado`))
}

executive_findings <- function(metrics) {
  national <- metrics |>
    dplyr::filter(.data$geo_code == "BR", .data$ranking_id == "RB4") |>
    dplyr::arrange(.data$year)
  if (nrow(national) < 2L) return(character())
  first <- national[1, ]
  last <- national[nrow(national), ]
  direction <- function(a, b) ifelse(b > a, "aumentou", "diminuiu")
  c(
    sprintf("A participação do top 1%% %s de %.1f%% para %.1f%% entre %d e %d.", direction(first$top_1_share, last$top_1_share), 100 * first$top_1_share, 100 * last$top_1_share, first$year, last$year),
    sprintf("O Gini agrupado da RB4 %s de %.3f para %.3f no período.", direction(first$gini_grouped, last$gini_grouped), first$gini_grouped, last$gini_grouped),
    sprintf("A medida de polarização de Wolfson %s de %.3f para %.3f.", direction(first$wolfson_grouped, last$wolfson_grouped), first$wolfson_grouped, last$wolfson_grouped),
    sprintf("Em %d, o top 0,1%% concentrou %.1f%% da RB4 declarada.", last$year, 100 * last$top_0_1_share),
    "As diferenças estaduais são relativas às distribuições internas de cada UF; os limites monetários de um mesmo centil variam entre estados."
  )
}
