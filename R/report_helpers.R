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

serie_nacional <- function(metrics, metric, geo_code, ranking) {
  metrics |>
    dplyr::filter(.data$geo_code == .env$geo_code, .data$ranking_id == .env$ranking) |>
    dplyr::filter(is.finite(.data[[metric]])) |>
    dplyr::arrange(.data$year)
}

plot_metric_evolution <- function(metrics, metric, label, geo_code = "BR", ranking = "RB4",
                                  titulo = NULL, subtitulo = NULL, span_min = 0.15,
                                  ancora = NULL, faixa_gini = FALSE) {
  data <- serie_nacional(metrics, metric, geo_code, ranking)
  if (nrow(data) == 0L) return(ggplot2::ggplot() + tema_irpf())

  # A faixa de Gastwirth já está calculada em distribution-metrics.parquet e
  # nunca era desenhada: mostrá-la deixa visível que o número é estimativa com
  # dados agrupados, o que antes só aparecia no texto.
  camada_faixa <- NULL
  if (faixa_gini && all(c("gini_lower_bound", "gini_upper_bound") %in% names(data))) {
    camada_faixa <- ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$gini_lower_bound, ymax = .data$gini_upper_bound),
      fill = cores_irpf$grade, colour = NA, alpha = 0.8
    )
  }

  ggplot2::ggplot(data, ggplot2::aes(x = .data$year, y = .data[[metric]])) +
    camada_faixa +
    ggplot2::geom_line(linewidth = 0.9, colour = cor_destaque(1)) +
    ggplot2::geom_point(size = 2.2, colour = cor_destaque(1)) +
    rotular_extremos(data, "year", metric) +
    escala_ano(data$year) +
    escala_indice(data[[metric]], span_min = span_min, ancora = ancora, nome = label) +
    ggplot2::labs(
      x = NULL, title = quebrar_texto(titulo, 68),
      subtitle = quebrar_texto(subtitulo, 88),
      caption = "Estimativa com dados agrupados do IRPF."
    ) +
    tema_irpf(direcao = "y")
}

plot_top_shares <- function(metrics, geo_code = "BR", ranking = "RB4",
                            titulo = NULL, subtitulo = NULL) {
  niveis <- c("Top 10%", "Top 1%", "Top 0,1%")
  data <- metrics |>
    dplyr::filter(.data$geo_code == .env$geo_code, .data$ranking_id == .env$ranking) |>
    dplyr::select(
      "year", `Top 10%` = "top_10_share", `Top 1%` = "top_1_share",
      `Top 0,1%` = "top_0_1_share"
    ) |>
    tidyr::pivot_longer(-"year", names_to = "group", values_to = "share") |>
    dplyr::filter(is.finite(.data$share)) |>
    dplyr::mutate(group = factor(.data$group, levels = niveis))
  if (nrow(data) == 0L) return(ggplot2::ggplot() + tema_irpf())

  # Os três grupos são aninhados (Top 10% ⊃ Top 1% ⊃ Top 0,1%): rampa
  # sequencial codifica essa ordem, que a paleta qualitativa anterior perdia.
  # Rótulo no fim da linha dispensa a legenda, que vinha em ordem alfabética
  # contra a ordem vertical das linhas.
  ggplot2::ggplot(data, ggplot2::aes(.data$year, .data$share, colour = .data$group)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 1.9) +
    rotular_series_no_fim(data, "year", "share", "group") +
    escala_ano(data$year) +
    escala_participacao(data$share, nome = "Participação na renda declarada") +
    escala_cor_ordinal(niveis) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(
      x = NULL, title = quebrar_texto(titulo, 68),
      subtitle = quebrar_texto(subtitulo, 88),
      caption = "Grupos disjuntos no cálculo; estimativa com dados agrupados do IRPF."
    ) +
    tema_irpf(direcao = "y") +
    ggplot2::theme(
      legend.position = "none",
      plot.margin = ggplot2::margin(10, 62, 8, 8)
    )
}

plot_ranking_comparison <- function(metrics, metric, label, geo_code = "BR",
                                    rankings = c("RTB", "RB3", "RB4"),
                                    titulo = NULL, subtitulo = NULL) {
  data <- metrics |>
    dplyr::filter(.data$geo_code == .env$geo_code, .data$ranking_id %in% .env$rankings) |>
    dplyr::filter(is.finite(.data[[metric]])) |>
    dplyr::arrange(.data$ranking_id, .data$year)
  if (nrow(data) == 0L) return(ggplot2::ggplot() + tema_irpf())

  # Ordem pelo valor final: a legenda passa a coincidir com a ordem vertical
  # das linhas. RB5 fica fora por padrão — com o top 1% em ~70% ele comprime a
  # variação de RTB/RB3/RB4, que é o contraste que interessa.
  niveis <- ordenar_por_valor_final(data, "year", metric, "ranking_id")
  data$ranking_id <- factor(data$ranking_id, levels = niveis)

  escala_y <- if (grepl("share$", metric)) {
    escala_participacao(data[[metric]], nome = label)
  } else {
    escala_indice(data[[metric]], nome = label)
  }

  ggplot2::ggplot(data, ggplot2::aes(.data$year, .data[[metric]], colour = .data$ranking_id)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 1.9) +
    rotular_series_no_fim(data, "year", metric, "ranking_id") +
    escala_ano(data$year) +
    escala_y +
    escala_cor_ordinal(niveis, nome = "Conceito de renda") +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(
      x = NULL, title = quebrar_texto(titulo, 68),
      subtitle = quebrar_texto(subtitulo, 88),
      caption = paste(
        "RTB, RB3 e RB4 são definições sucessivamente mais amplas de renda declarada;",
        "ver Metodologia. Estimativa com dados agrupados."
      )
    ) +
    tema_irpf(direcao = "y") +
    ggplot2::theme(
      legend.position = "none",
      plot.margin = ggplot2::margin(10, 52, 8, 8)
    )
}

filtrar_aliquotas <- function(effective_tax, year, geo_code, ranking) {
  effective_tax |>
    dplyr::filter(
      .data$year == .env$year, .data$geo_code == .env$geo_code,
      .data$ranking_id == .env$ranking, is.finite(.data$effective_rate)
    ) |>
    dplyr::arrange(.data$share_upper)
}

# Painel 1: a distribuição inteira em eixo de percentil, com o trecho detalhado
# no painel seguinte marcado por uma faixa.
plot_effective_rate_curve <- function(effective_tax, year, geo_code = "BR",
                                      ranking = "RB4", titulo = NULL, subtitulo = NULL) {
  data <- filtrar_aliquotas(effective_tax, year, geo_code, ranking) |>
    dplyr::filter(.data$bin_code <= 99L)
  if (nrow(data) == 0L) return(ggplot2::ggplot() + tema_irpf())

  ggplot2::ggplot(data, ggplot2::aes(.data$share_upper, .data$effective_rate)) +
    ggplot2::annotate(
      "rect", xmin = 0.99, xmax = 1, ymin = -Inf, ymax = Inf,
      fill = cores_irpf$grade, alpha = 0.7
    ) +
    ggplot2::annotate(
      "text", x = 0.985, y = Inf, label = "topo detalhado\nno gráfico seguinte",
      hjust = 1, vjust = 1.25, size = 3, colour = cores_irpf$texto_suave
    ) +
    ggplot2::geom_line(colour = cor_destaque(1), linewidth = 0.9) +
    escala_participacao(
      data$share_upper, eixo = "x", ancora = c(0, 1),
      nome = "Posição na distribuição (limite superior do grupo)"
    ) +
    escala_aliquota(data$effective_rate, nome = "Alíquota efetiva média") +
    linha_zero("h") +
    ggplot2::labs(
      title = quebrar_texto(titulo, 68),
      subtitle = quebrar_texto(subtitulo, 88),
      caption = "Imposto devido dividido pela renda RB4 do grupo; média de cada grupo."
    ) +
    tema_irpf(direcao = "y")
}

# Painel 2: os 20 grupos disjuntos do topo em eixo ordinal de largura igual.
# Cada grupo recebe o mesmo espaço, e a queda da alíquota no topo — o achado
# mais noticiável do estudo — deixa de ser um penhasco de dois pixels.
plot_effective_rate_top <- function(effective_tax, year, geo_code = "BR",
                                    ranking = "RB4", titulo = NULL, subtitulo = NULL) {
  data <- filtrar_aliquotas(effective_tax, year, geo_code, ranking) |>
    dplyr::filter(.data$bin_code %in% codigos_topo) |>
    dplyr::mutate(
      posicao = eixo_ordinal_topo(.data$share_upper)
    )
  if (nrow(data) == 0L) return(ggplot2::ggplot() + tema_irpf())

  pico <- data[which.max(data$effective_rate), ]
  ultimo <- data[which.max(data$share_upper), ]

  ggplot2::ggplot(data, ggplot2::aes(.data$posicao, .data$effective_rate, group = 1)) +
    ggplot2::geom_line(colour = cor_destaque(1), linewidth = 0.9) +
    ggplot2::geom_point(colour = cor_destaque(1), size = 1.9) +
    ggplot2::geom_text(
      data = rbind(pico, ultimo),
      mapping = ggplot2::aes(label = rotulo_percentual(0.1)(.data$effective_rate)),
      vjust = -1.1, size = 3.2, colour = cores_irpf$tinta
    ) +
    escala_aliquota(data$effective_rate, nome = "Alíquota efetiva média") +
    linha_zero("h") +
    ggplot2::labs(
      x = "Percentil de renda (limite superior de cada grupo divulgado)",
      title = quebrar_texto(titulo, 68),
      subtitle = quebrar_texto(subtitulo, 88),
      caption = paste(
        "Vinte grupos disjuntos com a mesma largura no eixo:",
        "os dez décimos do top 1% e os dez do top 0,1%."
      )
    ) +
    tema_irpf(direcao = "y") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 8))
}

plot_effective_rate_evolution <- function(effective_tax_summary, geo_code = "BR",
                                          ranking = "RB4", titulo = NULL, subtitulo = NULL) {
  group_labels <- c(
    "all" = "Todos os declarantes", "top_10" = "Top 10%",
    "top_1" = "Top 1%", "top_0_1" = "Top 0,1%"
  )
  data <- effective_tax_summary |>
    dplyr::filter(.data$geo_code == .env$geo_code, .data$ranking_id == .env$ranking) |>
    dplyr::filter(is.finite(.data$effective_rate)) |>
    dplyr::mutate(group_label = factor(group_labels[.data$group], levels = unname(group_labels))) |>
    dplyr::arrange(.data$group_label, .data$year)
  if (nrow(data) == 0L) return(ggplot2::ggplot() + tema_irpf())

  niveis <- unname(group_labels)
  ggplot2::ggplot(data, ggplot2::aes(.data$year, .data$effective_rate, colour = .data$group_label)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 1.9) +
    rotular_series_no_fim(data, "year", "effective_rate", "group_label") +
    escala_ano(data$year) +
    escala_aliquota(data$effective_rate, nome = "Alíquota efetiva média") +
    # "Todos os declarantes" é referência, não parte do aninhamento dos grupos
    # de topo: entra em cinza para não competir com a rampa.
    escala_cor_ordinal(niveis, contexto = "Todos os declarantes") +
    linha_zero("h") +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(
      x = NULL, title = quebrar_texto(titulo, 68),
      subtitle = quebrar_texto(subtitulo, 88),
      caption = "Imposto devido dividido pela renda RB4 do grupo; dados agrupados."
    ) +
    tema_irpf(direcao = "y") +
    ggplot2::theme(
      legend.position = "none",
      plot.margin = ggplot2::margin(10, 78, 8, 8)
    )
}

# Sensibilidade ao grupo 120. A série nacional de 2018 é movida por um único
# grupo de 3.181 declarações entre 31,8 milhões — valor publicado pela Receita e
# conferido contra o arquivo de origem (ver docs/limitations.md). Mostrar a
# série com e sem esse grupo comunica a dependência em vez de escondê-la, e
# torna visível o quanto o topo governa os indicadores em todos os anos.
metricas_sem_grupo_120 <- function(distribution_bins, geo_code = "BR",
                                   ranking = "RB4", epsilon = 0.5) {
  leaf_distribution(distribution_bins) |>
    dplyr::filter(
      .data$geo_code == .env$geo_code, .data$ranking_id == .env$ranking,
      .data$bin_code != 120L
    ) |>
    dplyr::group_by(.data$year) |>
    dplyr::group_modify(~ calculate_distribution_metrics(.x, epsilon)) |>
    dplyr::ungroup()
}

plot_sensibilidade_topo <- function(distribution_bins, metrics, metric = "gini_grouped",
                                    label = "Gini agrupado", geo_code = "BR",
                                    ranking = "RB4", titulo = NULL, subtitulo = NULL) {
  completo <- serie_nacional(metrics, metric, geo_code, ranking) |>
    dplyr::transmute(year = .data$year, valor = .data[[metric]], serie = "Todos os grupos")
  sem_120 <- metricas_sem_grupo_120(distribution_bins, geo_code, ranking) |>
    dplyr::transmute(year = .data$year, valor = .data[[metric]], serie = "Sem o top 0,01%")
  data <- dplyr::bind_rows(completo, sem_120) |>
    dplyr::filter(is.finite(.data$valor))
  if (nrow(data) == 0L) return(ggplot2::ggplot() + tema_irpf())

  niveis <- c("Todos os grupos", "Sem o top 0,01%")
  data$serie <- factor(data$serie, levels = niveis)
  escala_y <- if (grepl("share$", metric)) {
    escala_participacao(data$valor, nome = label)
  } else {
    escala_indice(data$valor, nome = label)
  }

  ggplot2::ggplot(data, ggplot2::aes(.data$year, .data$valor, colour = .data$serie)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 1.9) +
    rotular_series_no_fim(data, "year", "valor", "serie") +
    escala_ano(data$year) +
    escala_y +
    escala_cor_ordinal(niveis) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(
      x = NULL, title = quebrar_texto(titulo, 68),
      subtitle = quebrar_texto(subtitulo, 88),
      caption = paste(
        "O grupo 120 reúne 0,01% das declarações.",
        "Valores de 2018 conferidos contra o arquivo oficial; ver Limitações."
      )
    ) +
    tema_irpf(direcao = "y") +
    ggplot2::theme(
      legend.position = "none",
      plot.margin = ggplot2::margin(10, 84, 8, 8)
    )
}

latest_metrics_table <- function(metrics, ranking = "RB4") {
  if (nrow(metrics) == 0L) return(tibble::tibble())
  latest <- max(metrics$year, na.rm = TRUE)
  # Nomes por extenso: "AC" e "RO" não são leitura de público geral, e o
  # dicionário de geografias já traz o nome ao lado do código.
  nomes <- read_schema("geographies") |>
    dplyr::select("geo_code", "geo_name")
  metrics |>
    dplyr::filter(.data$year == latest, .data$ranking_id == .env$ranking, .data$geo_level == "state") |>
    dplyr::left_join(nomes, by = "geo_code") |>
    dplyr::mutate(geo_name = dplyr::coalesce(.data$geo_name, .data$geo_code)) |>
    dplyr::select(
      `Unidade da Federação` = "geo_name", Declarantes = "contributors",
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
