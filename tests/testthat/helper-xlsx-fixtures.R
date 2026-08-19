# Constrói workbooks XLSX sintéticos mínimos nos dois layouts da fonte
# (monolítico 2017-2021 e dividido 2022-2024) para testar o parser sem
# depender dos arquivos oficiais. Valores hierárquicos reconciliam por
# construção (100 = soma de 101-110; 110 = soma de 111-120).

fixture_bin_values <- function() {
  centile <- tibble::tibble(
    code = 1:99, contributors = 100, rank_sum = 100 * (1:99)
  )
  top_tenths <- tibble::tibble(
    code = 101:109, contributors = 10, rank_sum = 1000 + 10 * (1:9)
  )
  top_hundredths <- tibble::tibble(
    code = 111:120, contributors = 1, rank_sum = 2000 + (1:10)
  )
  agg_110 <- tibble::tibble(
    code = 110,
    contributors = sum(top_hundredths$contributors),
    rank_sum = sum(top_hundredths$rank_sum)
  )
  agg_100 <- tibble::tibble(
    code = 100,
    contributors = sum(top_tenths$contributors) + agg_110$contributors,
    rank_sum = sum(top_tenths$rank_sum) + agg_110$rank_sum
  )
  dplyr::bind_rows(centile, agg_100, top_tenths, agg_110, top_hundredths) |>
    dplyr::arrange(.data$code) |>
    dplyr::mutate(
      rank_mean = .data$rank_sum / .data$contributors,
      rank_upper = .data$rank_mean * 1.5,
      rank_cumulative = cumsum(.data$rank_sum),
      tax_due = 0.1 * .data$rank_sum,
      dividends = 5
    )
}

fixture_headers <- c(
  "Quantidade de Contribuintes", "Limite Superior do RB4",
  "Soma do RB4", "Acumulado do RB4", "Média do RB4",
  "Imposto Devido", "Lucros e Dividendos"
)

fixture_value_columns <- function(bins) {
  lapply(
    list(
      bins$contributors, bins$rank_upper, bins$rank_sum,
      bins$rank_cumulative, bins$rank_mean, bins$tax_due, bins$dividends
    ),
    as.character
  )
}

write_fixture_workbook <- function(layout = c("split", "monolithic"), sheet = "BRV",
                                   extra_sheets = list()) {
  layout <- match.arg(layout)
  bins <- fixture_bin_values()
  values <- fixture_value_columns(bins)
  if (layout == "split") {
    columns <- c(
      list(c("Centil", as.character(bins$code))),
      purrr::map2(fixture_headers, values, ~ c(.x, .y))
    )
  } else {
    primary <- ifelse(bins$code <= 100, as.character(bins$code), NA_character_)
    secondary <- ifelse(bins$code %in% 101:110, as.character(bins$code - 100L), NA_character_)
    tertiary <- ifelse(bins$code %in% 111:120, as.character(bins$code - 110L), NA_character_)
    columns <- c(
      list(
        c("Centil", primary),
        c("Décimos do centil superior", secondary),
        c("Centésimos do centil superior", tertiary)
      ),
      purrr::map2(fixture_headers, values, ~ c(.x, .y))
    )
  }
  frame <- as.data.frame(columns, stringsAsFactors = FALSE, check.names = FALSE)
  names(frame) <- paste0("c", seq_along(frame))
  sheets <- c(stats::setNames(list(frame), sheet), extra_sheets)
  path <- tempfile(pattern = paste0("fixture-", layout, "-"), fileext = ".xlsx")
  writexl::write_xlsx(sheets, path, col_names = FALSE)
  path
}

write_wealth_fixture_workbook <- function(sheet = "BR07") {
  codes <- c(0L, 1:99, 100L, 101:109, 110L, 111:120)
  contributors <- c(50, rep(100, 99), 100, rep(10, 9), 10, rep(1, 10))
  contributors[codes == 110] <- 10
  contributors[codes == 100] <- 90 + 10
  wealth_mean <- c(0, 10 * (1:99), NA, 2000 + 10 * (1:9), NA, 5000 + (1:10))
  wealth_sum_millions <- dplyr::coalesce(wealth_mean, 0) * contributors / 1e6
  frame <- data.frame(
    c1 = c("Centil", ifelse(codes <= 100, as.character(codes), NA_character_)),
    c2 = c(NA, ifelse(codes %in% 101:110, as.character(codes - 100L), NA_character_)),
    c3 = c(NA, ifelse(codes %in% 111:120, as.character(codes - 110L), NA_character_)),
    c4 = c("Quantidade", as.character(contributors)),
    c5 = c("Limite", as.character(dplyr::coalesce(wealth_mean, 0) * 2)),
    c6 = c("Soma (milhões)", as.character(wealth_sum_millions)),
    c7 = c("Acumulado (milhões)", as.character(cumsum(wealth_sum_millions))),
    c8 = c("Média", as.character(dplyr::coalesce(wealth_mean, 0))),
    stringsAsFactors = FALSE
  )
  path <- tempfile(pattern = "fixture-wealth-", fileext = ".xlsx")
  writexl::write_xlsx(stats::setNames(list(frame), sheet), path, col_names = FALSE)
  path
}
