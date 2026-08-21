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

# Os portões abaixo checam plausibilidade dos indicadores derivados, não a
# estrutura da fonte. Existem porque a alíquota efetiva de 2017–2021 chegou a
# ser publicada acima de 100% sem que nada no pipeline reclamasse: o defeito só
# apareceu no gráfico, e depois de publicado.
validate_effective_rate_range <- function(effective_tax) {
  rates <- effective_tax$effective_rate
  finite <- rates[is.finite(rates)]
  out_of_range <- sum(finite < 0 | finite > 1)
  faixa <- tibble::tibble(
    check = "effective_rate_range",
    status = ifelse(out_of_range == 0L, "pass", "fail"),
    detail = ifelse(
      out_of_range == 0L,
      "Alíquotas efetivas dentro de [0, 1]",
      paste0(
        out_of_range, " grupo(s) com alíquota efetiva fora de [0, 1]; máximo ",
        scales::percent(max(finite), accuracy = 0.1)
      )
    )
  )
  # A supressão da razão em conceitos estreitos não pode ser silenciosa: sem
  # esta contagem, uma cobertura que caísse por defeito de parsing passaria
  # como se fosse a regra conceitual funcionando.
  suprimidos <- sum(is.na(rates))
  cobertura <- tibble::tibble(
    check = "effective_rate_coverage",
    status = ifelse(suprimidos == 0L, "pass", "warn"),
    detail = paste0(
      suprimidos, " de ", length(rates),
      " grupo(s) sem alíquota interpretável (imposto acima da renda do conceito",
      " ou renda nula); concentrados nos conceitos estreitos RB5, RB9 e RB10"
    )
  )
  dplyr::bind_rows(faixa, cobertura)
}

validate_index_ranges <- function(metrics) {
  bounded <- c("gini_grouped", "atkinson_grouped")
  offenders <- purrr::map_int(bounded, function(column) {
    values <- metrics[[column]]
    sum(is.finite(values) & (values < 0 | values > 1))
  })
  # Wolfson e Palma não são limitados por construção, mas explodem quando a
  # mediana do grupo tende a zero — é artefato de fórmula, não desigualdade.
  unstable <- sum(is.finite(metrics$wolfson_grouped) & metrics$wolfson_grouped > 1) +
    sum(is.finite(metrics$palma) & metrics$palma > 50)
  dplyr::bind_rows(
    tibble::tibble(
      check = "bounded_index_range",
      status = ifelse(sum(offenders) == 0L, "pass", "fail"),
      detail = ifelse(
        sum(offenders) == 0L,
        "Gini e Atkinson dentro de [0, 1]",
        paste(sum(offenders), "distribuições com índice limitado fora de [0, 1]")
      )
    ),
    tibble::tibble(
      check = "unstable_index_values",
      status = ifelse(unstable == 0L, "pass", "warn"),
      detail = paste(
        unstable,
        "distribuição(ões) com Wolfson > 1 ou Palma > 50; artefato de mediana próxima de zero"
      )
    )
  )
}

validate_year_over_year <- function(metrics, threshold = 0.05) {
  national <- metrics |>
    dplyr::filter(.data$geo_level == "national") |>
    dplyr::arrange(.data$ranking_id, .data$year) |>
    dplyr::group_by(.data$ranking_id) |>
    dplyr::mutate(jump = abs(.data$gini_grouped - dplyr::lag(.data$gini_grouped))) |>
    dplyr::ungroup() |>
    dplyr::filter(is.finite(.data$jump), .data$jump > threshold)
  tibble::tibble(
    check = "gini_year_over_year",
    status = ifelse(nrow(national) == 0L, "pass", "warn"),
    detail = ifelse(
      nrow(national) == 0L,
      paste0("Nenhum salto nacional de Gini acima de ", threshold, " entre anos consecutivos"),
      paste0(
        nrow(national), " salto(s) nacional(is) de Gini acima de ", threshold, ": ",
        paste(paste0(national$ranking_id, "/", national$year), collapse = ", ")
      )
    )
  )
}

run_derived_quality_checks <- function(metrics, effective_tax, wealth_bins, top_counts) {
  if (nrow(metrics) == 0L) {
    return(tibble::tibble(
      check = "derived_available", status = "fail",
      detail = "Nenhum indicador derivado calculado"
    ))
  }
  dplyr::bind_rows(
    validate_effective_rate_range(effective_tax),
    validate_index_ranges(metrics),
    validate_year_over_year(metrics),
    validate_debt_ratio_range(wealth_bins),
    validate_asset_total_identity(wealth_bins),
    validate_top_counts_nesting(top_counts)
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

# Estoque e fluxo declarados são não negativos, então a razão dívida/renda
# também é. Valor negativo aponta campo trocado no layout, não declarante com
# dívida negativa.
validate_debt_ratio_range <- function(wealth_bins) {
  if (nrow(wealth_bins) == 0L) {
    return(tibble::tibble(
      check = "debt_income_ratio_range", status = "fail",
      detail = "Nenhum grupo com bens e dívidas"
    ))
  }
  definidos <- sum(is.finite(wealth_bins$debt_income_ratio))
  offenders <- sum(
    is.finite(wealth_bins$debt_income_ratio) & wealth_bins$debt_income_ratio < 0
  )
  tibble::tibble(
    check = "debt_income_ratio_range",
    status = ifelse(offenders == 0L, "pass", "fail"),
    detail = ifelse(
      offenders == 0L,
      paste0(
        definidos, " de ", nrow(wealth_bins),
        " grupos com razão dívida/renda definida e não negativa"
      ),
      paste(offenders, "grupos com razão dívida/renda negativa")
    )
  )
}

# A série de bens usa a soma das quatro famílias, porque o total consolidado só
# é divulgado de 2022 em diante. Onde os dois existem precisam coincidir; se não
# coincidirem, ou o layout mudou ou uma família deixou de ser lida.
validate_asset_total_identity <- function(wealth_bins, tolerance = 0.005) {
  comparaveis <- wealth_bins |>
    dplyr::filter(
      is.finite(.data$assets_total_real), is.finite(.data$assets_sum_real),
      .data$assets_total_real > 0
    ) |>
    dplyr::mutate(
      gap = abs(.data$assets_sum_real - .data$assets_total_real) /
        .data$assets_total_real
    )
  offenders <- sum(comparaveis$gap > tolerance)
  tibble::tibble(
    check = "asset_total_identity",
    status = ifelse(offenders == 0L, "pass", "fail"),
    detail = ifelse(
      nrow(comparaveis) == 0L,
      "Nenhum grupo com total consolidado divulgado para conferir",
      ifelse(
        offenders == 0L,
        paste(nrow(comparaveis), "grupos com soma das famílias igual ao total divulgado"),
        paste(offenders, "grupos com soma das famílias fora do total divulgado")
      )
    )
  )
}

# As contagens de topo são aninhadas: o top 1% cabe dentro do top 10%. Inversão
# indica corte de grupo errado, não um dado da fonte.
validate_top_counts_nesting <- function(top_counts) {
  if (nrow(top_counts) == 0L) {
    return(tibble::tibble(
      check = "top_counts_nesting", status = "fail",
      detail = "Nenhuma contagem de topo calculada"
    ))
  }
  offenders <- top_counts |>
    dplyr::arrange(.data$year, .data$geo_code, .data$ranking_id, .data$share_lower) |>
    dplyr::group_by(.data$year, .data$geo_code, .data$ranking_id) |>
    dplyr::mutate(quebra = .data$contributors > dplyr::lag(.data$contributors)) |>
    dplyr::ungroup() |>
    dplyr::filter(.data$quebra %in% TRUE)
  tibble::tibble(
    check = "top_counts_nesting",
    status = ifelse(nrow(offenders) == 0L, "pass", "fail"),
    detail = ifelse(
      nrow(offenders) == 0L,
      paste(nrow(top_counts), "contagens de topo aninhadas corretamente"),
      paste(nrow(offenders), "recortes com contagem de topo fora da ordem")
    )
  )
}
