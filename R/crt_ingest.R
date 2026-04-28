#' Ingest a registered upstream file and return canonical-shape data
#'
#' Source-explicit dispatcher. Looks up `(source, file_name)` in the registry,
#' validates the input file's shape against known upstream variants from the
#' schema YAML, dispatches to the matching internal handler, and returns a
#' tibble in canonical shape.
#'
#' @param source Character. Source family code (e.g. `"bcfp"`).
#' @param file_name Character. Logical file name (e.g. `"user_habitat_classification"`).
#' @param path Character. Path to the source file (CSV today; future may accept
#'   S3 URLs, postgres connections, etc. as the registered handler grows).
#'
#' @return A tibble in the canonical shape declared by the schema YAML.
#'
#' @details
#' Use [crt_files()] to discover what `(source, file_name)` pairs are registered.
#'
#' When upstream reshapes a CSV (e.g. long -> wide), `crt_ingest()` shields
#' callers from the change: register the new shape as an `upstream_variant` in
#' the schema YAML and add a normalize handler, and the same `crt_ingest()`
#' call continues returning canonical output.
#'
#' Throws on:
#' - Unknown `(source, file_name)` pair (not in registry)
#' - File at `path` does not exist
#' - Input file's shape does not match any known upstream variant
#'
#' @examples
#' # Read the bundled wide-format fixture (today's upstream shape)
#' wide_path <- system.file(
#'   "extdata/examples/bcfp/wide_user_habitat_classification.csv",
#'   package = "crate"
#' )
#' wide <- crt_ingest("bcfp", "user_habitat_classification", wide_path)
#' wide
#'
#' # Read the bundled long-format fixture (historical pre-2026-04-26 shape).
#' # crt_ingest pivots it to canonical wide automatically - same call,
#' # same output shape, regardless of which upstream variant arrived.
#' long_path <- system.file(
#'   "extdata/examples/bcfp/long_user_habitat_classification.csv",
#'   package = "crate"
#' )
#' long <- crt_ingest("bcfp", "user_habitat_classification", long_path)
#' long
#'
#' # Both calls return the same canonical column set
#' identical(names(wide), names(long))
#'
#' @seealso [crt_files()] to list registered entries.
#' @export
crt_ingest <- function(source, file_name, path) {
  chk::chk_string(source)
  chk::chk_string(file_name)
  chk::chk_string(path)

  if (!fs::file_exists(path)) {
    cli::cli_abort("File does not exist at path: {path}")
  }

  reg <- registry_load() # nolint: object_usage_linter.
  matched <- reg[reg$source == source & reg$file_name == file_name, , drop = FALSE]
  if (nrow(matched) == 0L) {
    cli::cli_abort(c(
      "Unknown (source, file_name) pair: ({source}, {file_name}).",
      "i" = "See {.code crt_files()} for registered entries."
    ))
  }

  schema_yaml_rel <- matched$schema_yaml[[1L]]
  schema_path <- system.file(
    file.path("extdata", schema_yaml_rel),
    package = "crate"
  )
  if (!nzchar(schema_path)) {
    cli::cli_abort(
      "Schema YAML not bundled at inst/extdata/{schema_yaml_rel}"
    )
  }
  schema <- yaml::read_yaml(schema_path)

  raw <- readr::read_csv(path, show_col_types = FALSE)
  raw_cols <- names(raw)

  matched_variant <- NULL
  for (variant in schema$upstream_variants) {
    if (setequal(variant$cols, raw_cols)) {
      matched_variant <- variant
      break
    }
  }
  if (is.null(matched_variant)) {
    known_ids <- vapply( # nolint: object_usage_linter.
      schema$upstream_variants,
      function(v) v$id,
      character(1L)
    )
    cli::cli_abort(c(
      "Input shape does not match any known upstream variant for ({source}, {file_name}).",
      "i" = "Got cols: {paste(raw_cols, collapse = ', ')}",
      "i" = "Known variant ids: {paste(known_ids, collapse = ', ')}"
    ))
  }

  handler_fn_name <- matched$handler_fn[[1L]]
  handler <- get(
    handler_fn_name,
    envir = asNamespace("crate"),
    mode = "function"
  )
  result <- handler(raw, matched_variant$id)

  tibble::as_tibble(result)
}
