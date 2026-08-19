request_official <- function(url) {
  httr2::request(url) |>
    httr2::req_user_agent("irpf-centis-research/0.1 (public-data research)") |>
    httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 5L)
}

perform_download_with_retry <- function(request, path, max_tries = 5L) {
  last_error <- NULL
  for (attempt in seq_len(max_tries)) {
    if (fs::file_exists(path)) fs::file_delete(path)
    result <- tryCatch(
      httr2::req_perform(request, path = path),
      error = function(error) {
        last_error <<- error
        NULL
      }
    )
    if (!is.null(result)) return(result)
    if (attempt < max_tries) {
      delay <- min(2^(attempt - 1L), 10)
      cli::cli_warn("Falha de transporte; nova tentativa {attempt + 1}/{max_tries} em {delay}s.")
      Sys.sleep(delay)
    }
  }
  rlang::abort(
    paste0("Download falhou após ", max_tries, " tentativas."),
    parent = last_error
  )
}

read_official_html <- function(url) {
  response <- request_official(url) |> httr2::req_perform()
  httr2::resp_check_status(response)
  xml2::read_html(httr2::resp_body_string(response))
}

discover_page_files <- function(page_url, family, year = NA_integer_) {
  page <- read_official_html(page_url)
  links <- page |>
    rvest::html_elements("a")

  tibble::tibble(
    label = rvest::html_text2(links),
    href = rvest::html_attr(links, "href")
  ) |>
    dplyr::filter(!is.na(.data$href)) |>
    dplyr::mutate(
      page_url = .env$page_url,
      url_view = xml2::url_absolute(.data$href, .env$page_url),
      extension = stringr::str_to_lower(stringr::str_match(.data$url_view, "\\.(xlsx|pdf)(?:/view)?(?:$|\\?)")[, 2])
    ) |>
    dplyr::filter(.data$extension %in% c("xlsx", "pdf")) |>
    dplyr::mutate(
      download_url = dplyr::if_else(
        stringr::str_ends(.data$url_view, "/view"),
        stringr::str_replace(.data$url_view, "/view$", "/@@download/file"),
        .data$url_view
      ),
      dataset_family = family,
      year = as.integer(year),
      source_id = paste0(
        family, "-",
        purrr::map_chr(.data$download_url, ~ substr(digest::digest(.x, algo = "sha256"), 1, 16))
      ),
      file_name = stringr::str_match(.data$url_view, "/([^/]+\\.(?:xlsx|pdf))(?:/view)?$")[, 2],
      file_name = dplyr::coalesce(.data$file_name, paste0(slugify(.data$label), ".", .data$extension)),
      layout = classify_source_layout(.data$file_name, .data$year, family)
    ) |>
    dplyr::distinct(.data$download_url, .keep_all = TRUE) |>
    dplyr::select(
      "source_id", "dataset_family", "year", "label",
      "extension", "layout", "page_url", "url_view",
      "download_url", "file_name"
    )
}

classify_source_layout <- function(file_name, year, family) {
  name <- normalize_text(file_name)
  dplyr::case_when(
    stringr::str_detect(name, "metadados|metodologia|capa") ~ "metadata",
    family == "receita_wealth" ~ "wealth_historical",
    !is.na(year) & year <= 2023 & stringr::str_detect(name, "distribuicao.*centis") ~ "expanded_monolithic",
    stringr::str_detect(name, "centis br") ~ "expanded_national",
    stringr::str_detect(name, "centis.*uf") ~ "expanded_regional",
    TRUE ~ "unknown"
  )
}

discover_expanded_sources <- function(years = NULL) {
  cfg <- read_sources_config()$receita_expanded
  years <- years %||% unlist(cfg$years)
  collection <- read_official_html(cfg$collection_url)
  year_links <- collection |>
    rvest::html_elements("a") |>
    rvest::html_attr("href") |>
    stats::na.omit() |>
    xml2::url_absolute(cfg$collection_url)

  detected_years <- stringr::str_match(year_links, "/(20[0-9]{2})/?$")[, 2] |>
    stats::na.omit() |>
    as.integer() |>
    unique()
  years <- sort(unique(c(as.integer(years), detected_years)))

  purrr::map_dfr(years, function(year) {
    page_url <- paste0(stringr::str_remove(cfg$collection_url, "/$"), "/", year)
    discover_page_files(page_url, "receita_expanded", year)
  })
}

discover_wealth_sources <- function() {
  cfg <- read_sources_config()$receita_wealth
  discover_page_files(cfg$collection_url, "receita_wealth", NA_integer_)
}

discover_all_sources <- function(include_wealth = TRUE) {
  expanded <- discover_expanded_sources()
  wealth <- if (isTRUE(include_wealth)) discover_wealth_sources() else tibble::tibble()
  dplyr::bind_rows(expanded, wealth) |>
    dplyr::arrange(.data$dataset_family, .data$year, .data$file_name)
}

read_discovered_sources <- function(path = "data/metadata/sources-discovered.csv") {
  if (!fs::file_exists(project_path(path))) return(tibble::tibble())
  readr::read_csv(project_path(path), show_col_types = FALSE)
}

read_source_manifest <- function(path = "data/metadata/sources-manifest.csv") {
  if (!fs::file_exists(project_path(path))) {
    return(tibble::tibble(
      source_id = character(), dataset_family = character(), year = integer(),
      label = character(), extension = character(), layout = character(),
      page_url = character(), download_url = character(), file_name = character(),
      local_path = character(), retrieved_at = character(), bytes = double(),
      sha256 = character(), status = character()
    ))
  }
  readr::read_csv(project_path(path), show_col_types = FALSE)
}

download_one_source <- function(row, overwrite = FALSE) {
  stopifnot(nrow(row) == 1L)
  is_metadata <- row$extension[[1]] == "pdf"
  family <- row$dataset_family[[1]]
  year_dir <- ifelse(is.na(row$year[[1]]), "historical", as.character(row$year[[1]]))
  root <- if (is_metadata) "data/metadata/official" else "data/raw"
  destination <- project_path(root, family, year_dir, row$file_name[[1]])
  fs::dir_create(fs::path_dir(destination), recurse = TRUE)

  if (fs::file_exists(destination) && !isTRUE(overwrite)) {
    return(tibble::tibble(
      source_id = row$source_id[[1]], dataset_family = family,
      year = as.integer(row$year[[1]]), label = row$label[[1]],
      extension = row$extension[[1]], layout = row$layout[[1]],
      page_url = row$page_url[[1]], download_url = row$download_url[[1]],
      file_name = row$file_name[[1]], local_path = fs::path_rel(destination),
      retrieved_at = format(fs::file_info(destination)$modification_time, tz = "UTC", usetz = TRUE),
      bytes = as.double(fs::file_size(destination)),
      sha256 = digest::digest(destination, algo = "sha256", file = TRUE),
      status = "cached"
    ))
  }

  tmp <- tempfile(pattern = "irpf-download-", fileext = paste0(".", row$extension[[1]]))
  on.exit(if (fs::file_exists(tmp)) fs::file_delete(tmp), add = TRUE)
  response <- perform_download_with_retry(
    request_official(row$download_url[[1]]),
    path = tmp
  )
  httr2::resp_check_status(response)
  if (!fs::file_exists(tmp) || fs::file_size(tmp) == 0) {
    rlang::abort(paste("Download vazio:", row$download_url[[1]]))
  }
  if (fs::file_exists(destination)) fs::file_delete(destination)
  fs::file_move(tmp, destination)

  tibble::tibble(
    source_id = row$source_id[[1]], dataset_family = family,
    year = as.integer(row$year[[1]]), label = row$label[[1]],
    extension = row$extension[[1]], layout = row$layout[[1]],
    page_url = row$page_url[[1]], download_url = row$download_url[[1]],
    file_name = row$file_name[[1]], local_path = fs::path_rel(destination),
    retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    bytes = as.double(fs::file_size(destination)),
    sha256 = digest::digest(destination, algo = "sha256", file = TRUE),
    status = "downloaded"
  )
}

download_sources <- function(discovered, years = NULL, include_pdf = TRUE, overwrite = FALSE) {
  selected <- discovered
  if (!is.null(years)) {
    selected <- selected |>
      dplyr::filter(.data$year %in% as.integer(years))
  }
  if (!isTRUE(include_pdf)) selected <- dplyr::filter(selected, .data$extension != "pdf")
  if (nrow(selected) == 0L) rlang::abort("Nenhuma fonte selecionada para download.")

  existing <- read_source_manifest()
  new_rows <- purrr::map_dfr(seq_len(nrow(selected)), function(i) {
    cli::cli_inform(c("i" = "Baixando {selected$file_name[[i]]}"))
    download_one_source(selected[i, ], overwrite = overwrite)
  })

  manifest <- dplyr::bind_rows(existing, new_rows) |>
    dplyr::arrange(.data$source_id, .data$retrieved_at) |>
    dplyr::group_by(.data$source_id) |>
    dplyr::slice_tail(n = 1L) |>
    dplyr::ungroup() |>
    dplyr::arrange(.data$dataset_family, .data$year, .data$file_name)
  write_csv_atomic(manifest, project_path("data/metadata/sources-manifest.csv"))
  manifest
}
