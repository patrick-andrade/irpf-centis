#!/usr/bin/env Rscript

options(encoding = "UTF-8")
project <- normalizePath(getwd(), winslash = "/")
port <- httpuv::randomPort()
started <- Sys.time()
process <- callr::r_bg(
  function(project, port) {
    setwd(project)
    shiny::runApp("app", host = "127.0.0.1", port = port, launch.browser = FALSE)
  },
  args = list(project = project, port = port),
  supervise = TRUE,
  stdout = "|",
  stderr = "|"
)
on.exit(if (process$is_alive()) process$kill_tree(), add = TRUE)

ready <- FALSE
for (attempt in seq_len(100L)) {
  response <- tryCatch(
    httr2::request(sprintf("http://127.0.0.1:%d", port)) |>
      httr2::req_timeout(1) |>
      httr2::req_perform(),
    error = function(error) NULL
  )
  if (!is.null(response) && httr2::resp_status(response) == 200L) {
    ready <- TRUE
    break
  }
  Sys.sleep(0.1)
}

elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
result <- data.frame(
  measured_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  ready = ready,
  initial_response_seconds = elapsed,
  requirement_seconds = 5,
  pass = ready && elapsed <= 5
)
dir.create("output/benchmarks", recursive = TRUE, showWarnings = FALSE)
readr::write_csv(result, "output/benchmarks/app-startup.csv")
print(result)
if (!ready) {
  process$kill_tree()
  process$wait(timeout = 3000)
  cat(process$read_error(), sep = "\n")
  quit(status = 1L)
}
