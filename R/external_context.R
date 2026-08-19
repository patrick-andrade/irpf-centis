fetch_ipca_annual <- function(path = "data/external/ipca-annual.csv") {
  cfg <- read_sources_config()$ibge_ipca
  response <- request_official(cfg$api_url) |> httr2::req_perform()
  httr2::resp_check_status(response)
  payload <- jsonlite::fromJSON(httr2::resp_body_string(response), simplifyDataFrame = TRUE)
  if (nrow(payload) < 2L || !all(c("D3C", "V") %in% names(payload))) {
    rlang::abort("Resposta inesperada da API SIDRA para o IPCA.")
  }
  monthly <- payload[-1, , drop = FALSE] |>
    tibble::as_tibble() |>
    dplyr::transmute(
      period = .data$D3C,
      year = as.integer(substr(.data$D3C, 1, 4)),
      month = as.integer(substr(.data$D3C, 5, 6)),
      index = as_numeric_safe(.data$V)
    ) |>
    dplyr::filter(.data$year %in% 2017:2024, is.finite(.data$index))
  annual <- monthly |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(annual_average_index = mean(.data$index), months = dplyr::n(), .groups = "drop")
  base_index <- annual$annual_average_index[annual$year == 2024]
  if (length(base_index) != 1L) rlang::abort("Índice-base de 2024 não encontrado.")
  annual <- annual |>
    dplyr::mutate(
      deflator_to_2024 = base_index / .data$annual_average_index,
      source_url = cfg$landing_url,
      retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
    )
  write_csv_atomic(annual, project_path(path))
  annual
}

read_coverage_context <- function(path = "data/external/coverage-context.csv") {
  path <- project_path(path)
  if (!fs::file_exists(path)) {
    return(tibble::tibble(
      year = integer(), geo_code = character(), declarants = double(),
      population_denominator = double(), denominator_definition = character(),
      coverage_ratio = double(), source_url = character(), status = character()
    ))
  }
  readr::read_csv(path, show_col_types = FALSE)
}

build_coverage_context <- function(distribution_bins, deflators, external = read_coverage_context()) {
  declarants <- leaf_distribution(distribution_bins) |>
    dplyr::filter(.data$ranking_id == "RB4") |>
    dplyr::group_by(.data$year, .data$geo_code) |>
    dplyr::summarise(declarants = sum(.data$contributors, na.rm = TRUE), .groups = "drop")

  declarants |>
    dplyr::left_join(
      dplyr::select(external, -dplyr::any_of("declarants")),
      by = c("year", "geo_code")
    ) |>
    dplyr::left_join(
      dplyr::select(deflators, "year", "annual_average_index", "deflator_to_2024"),
      by = "year"
    ) |>
    dplyr::mutate(
      population_denominator = as.numeric(.data$population_denominator),
      denominator_definition = dplyr::coalesce(
        .data$denominator_definition,
        "População adulta IBGE/PNAD — denominador pendente de congelamento metodológico"
      ),
      coverage_ratio = dplyr::if_else(
        is.finite(.data$population_denominator) & .data$population_denominator > 0,
        .data$declarants / .data$population_denominator,
        NA_real_
      ),
      status = dplyr::if_else(
        is.finite(.data$coverage_ratio), "available", "pending_ibge_adult_denominator"
      )
    )
}

fetch_ibge_state_geometry <- function(path = "data/external/ibge-states.geojson") {
  cfg <- read_sources_config()$ibge_geography
  response <- request_official(cfg$api_url) |> httr2::req_perform()
  httr2::resp_check_status(response)
  destination <- project_path(path)
  fs::dir_create(fs::path_dir(destination), recurse = TRUE)
  tmp <- tempfile(pattern = "ibge-states-", tmpdir = fs::path_dir(destination), fileext = ".geojson")
  writeBin(httr2::resp_body_raw(response), tmp)
  if (fs::file_exists(destination)) fs::file_delete(destination)
  fs::file_move(tmp, destination)
  destination
}

read_ibge_state_geometry <- function(path = "data/external/ibge-states.geojson") {
  path <- project_path(path)
  if (!fs::file_exists(path)) return(sf::st_sf(geometry = sf::st_sfc(crs = 4674)))
  sf::read_sf(path, quiet = TRUE)
}

# Achata a malha sf em um tibble de vértices para que o app desenhe o mapa
# com geom_polygon, sem depender de sf (requisito do shinylive/webR).
flatten_state_geometry <- function(state_geometry) {
  if (nrow(state_geometry) == 0L) {
    return(tibble::tibble(
      codarea = character(), piece = character(),
      long = double(), lat = double()
    ))
  }
  geometry <- sf::st_cast(sf::st_geometry(state_geometry), "MULTIPOLYGON")
  coords <- sf::st_coordinates(geometry)
  tibble::tibble(
    codarea = as.character(state_geometry$codarea[coords[, "L3"]]),
    piece = paste(coords[, "L3"], coords[, "L2"], coords[, "L1"], sep = "-"),
    long = coords[, "X"],
    lat = coords[, "Y"]
  )
}
