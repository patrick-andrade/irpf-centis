wealth_manifest_spec <- function(manifest) {
  spec <- manifest |>
    dplyr::filter(
      .data$dataset_family == "receita_wealth", .data$extension == "xlsx",
      stringr::str_detect(.data$file_name, "-3[.]xlsx$")
    )
  if (nrow(spec) != 1L) rlang::abort("Tabela III patrimonial não identificada univocamente.")
  spec
}

parse_wealth_sheet <- function(path, sheet, source_id) {
  year <- 2000L + as.integer(stringr::str_remove(sheet, "^BR")) - 1L
  raw <- readxl::read_excel(
    path, sheet = sheet, col_names = FALSE, .name_repair = "minimal", progress = FALSE
  )
  primary <- suppressWarnings(as.integer(as_numeric_safe(raw[[1]])))
  secondary <- suppressWarnings(as.integer(as_numeric_safe(raw[[2]])))
  tertiary <- suppressWarnings(as.integer(as_numeric_safe(raw[[3]])))
  codes <- primary
  secondary_rows <- is.na(primary) & secondary %in% 1:10
  tertiary_rows <- is.na(primary) & is.na(secondary) & tertiary %in% 1:10
  codes[secondary_rows] <- 100L + secondary[secondary_rows]
  codes[tertiary_rows] <- 110L + tertiary[tertiary_rows]
  rows <- which(codes %in% 0:120)

  attributes <- purrr::map_dfr(codes[rows], function(code) {
    if (code == 0L) {
      tibble::tibble(
        bin_level = "zero_wealth", parent_bin = NA_integer_,
        is_aggregate = FALSE, is_leaf = TRUE,
        positive_share_lower = NA_real_, positive_share_upper = NA_real_
      )
    } else {
      attrs <- bin_attributes(code)
      dplyr::transmute(
        attrs, .data$bin_level, .data$parent_bin, .data$is_aggregate, .data$is_leaf,
        positive_share_lower = .data$share_lower,
        positive_share_upper = .data$share_upper
      )
    }
  })

  result <- dplyr::bind_cols(
    tibble::tibble(
      year = year, geo_code = "BR", ranking_id = "WEALTH_DIRECT",
      bin_code = codes[rows]
    ),
    attributes,
    tibble::tibble(
      contributors = as_numeric_safe(raw[[4]][rows]),
      wealth_upper = as_numeric_safe(raw[[5]][rows]),
      wealth_sum = as_numeric_safe(raw[[6]][rows]) * 1e6,
      wealth_cumulative = as_numeric_safe(raw[[7]][rows]) * 1e6,
      wealth_mean = as_numeric_safe(raw[[8]][rows]),
      source_id = source_id, source_file = fs::path_file(path), source_sheet = sheet
    )
  )

  zero_share <- result$contributors[result$bin_code == 0L] /
    (result$contributors[result$bin_code == 0L] +
      sum(result$contributors[result$is_leaf & result$bin_code != 0L], na.rm = TRUE))
  result |>
    dplyr::mutate(
      population_share_lower = dplyr::if_else(
        .data$bin_code == 0L, 0,
        zero_share + (1 - zero_share) * .data$positive_share_lower
      ),
      population_share_upper = dplyr::if_else(
        .data$bin_code == 0L, zero_share,
        zero_share + (1 - zero_share) * .data$positive_share_upper
      )
    )
}

parse_wealth_workbook <- function(path, source_id) {
  result <- purrr::map_dfr(readxl::excel_sheets(path), ~ parse_wealth_sheet(path, .x, source_id))
  if (nrow(result) == 0L) rlang::abort("Tabela patrimonial direta sem registros.")
  result
}

calculate_wealth_metrics <- function(wealth_ranked_national, epsilon = 0.5) {
  wealth_ranked_national |>
    dplyr::filter(.data$is_leaf) |>
    dplyr::group_by(.data$year, .data$geo_code, .data$ranking_id) |>
    dplyr::group_modify(~ {
      data <- dplyr::transmute(
        .x, rank_mean = .data$wealth_mean, contributors = .data$contributors,
        rank_sum = .data$wealth_sum, rank_upper = .data$wealth_upper,
        share_lower = .data$population_share_lower,
        share_upper = .data$population_share_upper
      )
      dplyr::bind_cols(calculate_distribution_metrics(data, epsilon), calculate_polarization_metrics(data))
    }) |>
    dplyr::ungroup() |>
    dplyr::mutate(grouped_estimate = TRUE, atkinson_epsilon = epsilon)
}

# Bens e dívidas observados dentro dos grupos ordenados por renda. O bundle do
# painel soma os componentes sobre os bins e descarta `bin_code`, de modo que
# sem esta tabela não há como mostrar a distribuição do endividamento nem a
# razão dívida/renda ao longo da distribuição.
wealth_bin_families <- c(
  "assets_real_estate", "assets_movable", "assets_financial", "assets_other"
)

wealth_by_bin <- function(distribution_bins, income_components, ranking = "RB4") {
  alvo <- c(wealth_bin_families, "assets_total", "debts")
  componentes <- income_components |>
    dplyr::filter(
      .data$ranking_id == ranking,
      .data$component_id %in% alvo
    ) |>
    dplyr::transmute(
      .data$year, .data$geo_level, .data$geo_code, .data$ranking_id, .data$bin_code,
      component = paste0(.data$component_id, "_real"), .data$value_real
    ) |>
    tidyr::pivot_wider(names_from = "component", values_from = "value_real")
  ausentes <- setdiff(paste0(alvo, "_real"), names(componentes))
  componentes[ausentes] <- NA_real_
  familias <- paste0(wealth_bin_families, "_real")

  leaf_distribution(distribution_bins) |>
    dplyr::filter(.data$ranking_id == ranking) |>
    dplyr::select(
      "year", "geo_level", "geo_code", "ranking_id", "bin_code",
      "share_lower", "share_upper", "contributors", "rank_sum_real"
    ) |>
    dplyr::inner_join(
      componentes,
      by = c("year", "geo_level", "geo_code", "ranking_id", "bin_code")
    ) |>
    dplyr::mutate(
      # `assets_total` só é divulgado a partir de 2022, enquanto as quatro
      # famílias cobrem 2017-2024. A soma das famílias é o total comparável da
      # série; o total publicado serve de conferência onde existe, e não de
      # substituto. `na.rm = FALSE` mantém a ausência como ausência.
      assets_sum_real = rowSums(dplyr::across(dplyr::all_of(familias)), na.rm = FALSE),
      # Mesma disciplina do `effective_rate`: a razão só existe quando há renda
      # declarada no conceito. O primeiro centil tem renda nula em várias
      # geografias e precisa ficar NA em vez de virar zero ou infinito.
      debt_income_ratio = dplyr::if_else(
        is.finite(.data$rank_sum_real) & .data$rank_sum_real > 0 &
          is.finite(.data$debts_real),
        .data$debts_real / .data$rank_sum_real,
        NA_real_
      )
    ) |>
    dplyr::group_by(.data$year, .data$geo_level, .data$geo_code, .data$ranking_id) |>
    dplyr::mutate(
      debt_share = .data$debts_real / sum(.data$debts_real, na.rm = TRUE),
      assets_share = .data$assets_sum_real / sum(.data$assets_sum_real, na.rm = TRUE)
    ) |>
    dplyr::ungroup() |>
    dplyr::arrange(.data$year, .data$geo_code, .data$bin_code)
}
