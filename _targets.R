library(targets)
library(tarchetypes)

tar_option_set(
  packages = c(
    "arrow", "digest", "dplyr", "fs", "httr2", "jsonlite", "purrr",
    "readr", "readxl", "rlang", "rvest", "sf", "stringi", "stringr",
    "tibble", "tidyr", "xml2", "yaml"
  ),
  format = "rds",
  error = "stop"
)

invisible(purrr::walk(sort(fs::dir_ls("R", glob = "*.R")), source))

list(
  tar_target(project_config, read_project_config()),
  tar_target(source_manifest, read_source_manifest(), cue = tar_cue(mode = "always")),
  tar_target(source_spec, manifest_xlsx_specs(source_manifest), iteration = "list"),
  tar_target(
    raw_xlsx,
    validate_manifest_spec(source_spec),
    pattern = map(source_spec),
    format = "file"
  ),
  tar_target(
    parsed_file,
    parse_manifest_file(raw_xlsx, source_manifest),
    pattern = map(raw_xlsx),
    iteration = "list"
  ),
  tar_target(
    distribution_bins_raw_units,
    bind_parsed_results(parsed_file, "distribution_bins", empty_distribution_bins)
  ),
  tar_target(
    income_components_raw_units,
    bind_parsed_results(parsed_file, "income_components", empty_income_components)
  ),
  tar_target(
    normalized_units,
    normalize_source_units(distribution_bins_raw_units, income_components_raw_units)
  ),
  tar_target(distribution_bins_nominal, normalized_units$distribution_bins),
  tar_target(income_components_nominal, normalized_units$income_components),
  tar_target(wealth_spec, wealth_manifest_spec(source_manifest)),
  tar_target(wealth_xlsx, validate_manifest_spec(wealth_spec), format = "file"),
  tar_target(
    wealth_ranked_national,
    parse_wealth_workbook(wealth_xlsx, wealth_spec$source_id[[1]])
  ),
  tar_target(
    wealth_metrics,
    calculate_wealth_metrics(wealth_ranked_national, project_config$analysis$atkinson_epsilon)
  ),
  tar_target(ipca_deflators, read_ipca_deflators()),
  tar_target(state_geometry, read_ibge_state_geometry()),
  tar_target(state_polygons, flatten_state_geometry(state_geometry)),
  tar_target(
    coverage_context,
    build_coverage_context(distribution_bins_nominal, ipca_deflators)
  ),
  tar_target(
    harmonized,
    apply_deflators(distribution_bins_nominal, income_components_nominal, ipca_deflators)
  ),
  tar_target(distribution_bins, harmonized$distribution_bins),
  tar_target(income_components, harmonized$income_components),
  tar_target(quality_checks, run_quality_checks(distribution_bins_nominal)),
  tar_target(hierarchy_reconciliation, reconcile_hierarchy(distribution_bins_nominal)),
  tar_target(quality_gate, assert_quality(quality_checks)),
  tar_target(
    distribution_metrics,
    calculate_all_metrics(distribution_bins, project_config$analysis$atkinson_epsilon)
  ),
  tar_target(effective_tax, effective_tax_rates(distribution_bins, income_components)),
  tar_target(theil_decomposition, theil_decomposition_uf(distribution_bins_nominal, "RB4")),
  tar_target(
    processed_files,
    {
      quality_gate
      write_processed_outputs(
        distribution_bins, income_components, distribution_metrics,
        effective_tax, theil_decomposition, quality_checks,
        hierarchy_reconciliation, wealth_ranked_national, wealth_metrics,
        coverage_context
      )
    },
    format = "file"
  ),
  tar_target(
    app_bundle,
    {
      quality_gate
      write_app_bundle(
        income_components, distribution_metrics, effective_tax,
        theil_decomposition, wealth_ranked_national, wealth_metrics,
        state_polygons
      )
    },
    format = "file"
  )
)
