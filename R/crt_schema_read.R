#' Read a bundled schema YAML by relative path
#'
#' Resolves the YAML file path within crate's installed package via
#' [system.file()], then reads + parses it via [yaml::read_yaml()]. Single
#' source of truth for "load a schema YAML by registry-declared path" — used
#' by [crt_ingest()] and available for any future `crt_schema_*` family
#' member that needs schema access.
#'
#' @param yaml_path Character. Path relative to `inst/extdata/` in crate.
#'   E.g., `"schemas/bcfp/user_habitat_classification.yaml"`.
#' @return The parsed schema as a nested list (yaml::read_yaml output).
#' @keywords internal
crt_schema_read <- function(yaml_path) {
  chk::chk_string(yaml_path)
  full_path <- system.file(file.path("extdata", yaml_path), package = "crate")
  if (!nzchar(full_path)) {
    cli::cli_abort("Schema YAML not bundled at inst/extdata/{yaml_path}")
  }
  yaml::read_yaml(full_path)
}

# Internal: the parsed schema for one registered (source, file_name) pair.
#
# The accessors that answer questions about a registered schema --
# crt_schema_cols(), crt_schema_grade(), crt_schema_variant() -- all start from
# here, so the "unknown pair" error is the registry's own.

crt_schema_get <- function(source, file_name) {
  chk::chk_string(source)
  chk::chk_string(file_name)
  entry <- crt_registry_entry(source, file_name)
  crt_schema_read(entry$schema_yaml[[1L]])
}
