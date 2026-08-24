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
#' Validation and typing are not done here — the handler's output goes through
#' [crt_schema_conform()], which is also the entry point for data crate did not
#' read. One code path, so the two cannot drift.
#'
#' Throws on:
#' - Unknown `(source, file_name)` pair (not in registry)
#' - An entry registered `kind = schema_only`, which declares a canonical shape
#'   crate does not read. Conform your own data frame with
#'   [crt_schema_conform()] instead.
#' - File at `path` does not exist
#' - Input file's shape does not match any known upstream variant
#'
#' @examples
#' # Read the bundled wide-format fixture (today's upstream shape)
#' wide_path <- system.file(
#'   "extdata/examples/bcfp/user_habitat_classification_wide.csv",
#'   package = "crate"
#' )
#' wide <- crt_ingest("bcfp", "user_habitat_classification", wide_path)
#' wide
#'
#' # Read the bundled long-format fixture (historical pre-2026-04-26 shape).
#' # crt_ingest pivots it to canonical wide automatically - same call,
#' # same output shape, regardless of which upstream variant arrived.
#' long_path <- system.file(
#'   "extdata/examples/bcfp/user_habitat_classification_long.csv",
#'   package = "crate"
#' )
#' long <- crt_ingest("bcfp", "user_habitat_classification", long_path)
#' long
#'
#' # Both calls return the same canonical column set
#' identical(names(wide), names(long))
#'
#' @seealso [crt_files()] to list registered entries,
#'   [crt_schema_conform()] to conform a data frame crate did not read.
#' @export
crt_ingest <- function(source, file_name, path) {
  chk::chk_string(source)
  chk::chk_string(file_name)
  chk::chk_string(path)

  matched <- crt_registry_entry(source, file_name)

  # Check this before touching the filesystem. A schema_only entry has no
  # handler to dispatch to, and "file not found" would be a misleading first
  # error for a caller who is simply at the wrong entry point.
  kind <- crt_registry_kind(matched)
  if (!identical(kind, "file")) {
    cli::cli_abort(c(
      "({source}, {file_name}) is registered {.val {kind}}; there is no file for \\
       crate to read.",
      "i" = "crate declares its canonical shape but does not read it.",
      "i" = "Conform your own data frame with {.code crt_schema_conform(df, \\
             \"{source}\", \"{file_name}\")}."
    ))
  }

  if (!fs::file_exists(path)) {
    cli::cli_abort("File does not exist at path: {path}")
  }

  schema <- crt_schema_read(matched$schema_yaml[[1L]])

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

  # Validation then typing, both from the schema YAML. Routed through
  # crt_schema_conform() rather than calling crt_schema_validate() and
  # crt_schema_apply() here, so a caller arriving with their own data frame
  # gets exactly the treatment a file gets.
  crt_schema_conform(result, source, file_name)
}
