#' Conform a data frame to a registered canonical schema
#'
#' Validates that every required canonical column is present, then coerces
#' every declared column to its canonical type. Returns the conformed tibble.
#'
#' This is the entry point for data crate did not read. [crt_ingest()] reads a
#' registered CSV and dispatches to a handler before conforming; a caller that
#' already has a data frame — from a database, a spatial file, an API — comes
#' here directly. Both paths run the same validation and typing, because
#' `crt_ingest()` calls this function.
#'
#' @param df A data frame.
#' @param source Character. Source family code (e.g. `"nge"`).
#' @param file_name Character. Logical file name (e.g. `"track_sessions"`).
#'
#' @return A tibble conformed to the canonical schema for that entry.
#'
#' @details
#' Use [crt_files()] to discover what `(source, file_name)` pairs are registered.
#'
#' Presence is checked before types are applied, because a missing required
#' column would otherwise become a column of `NA` at coercion and the failure
#' would surface far from its cause.
#'
#' What this does **not** do is reject columns the schema does not declare —
#' extra columns pass through untouched. A caller that wants the canonical set
#' to be exhaustive should assert that itself; the schema declares a floor, not
#' a ceiling.
#'
#' Throws on an unknown `(source, file_name)` pair, on a missing required
#' column, and on a schema declaring a type crate does not support.
#'
#' @examples
#' # A frame that is already in canonical shape passes through, typed.
#' path <- system.file(
#'   "extdata/examples/bcfp/user_habitat_classification_wide.csv",
#'   package = "crate"
#' )
#' raw <- readr::read_csv(path, show_col_types = FALSE)
#' conformed <- crt_schema_conform(raw, "bcfp", "user_habitat_classification")
#' conformed
#'
#' # The schema declares blue_line_key as integer; readr guessed double.
#' class(raw$blue_line_key)
#' class(conformed$blue_line_key)
#'
#' @seealso [crt_ingest()] to read and conform a registered file in one call,
#'   [crt_files()] to list registered entries.
#' @export
crt_schema_conform <- function(df, source, file_name) {
  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg df} must be a data frame, not {.cls {class(df)}}.")
  }
  chk::chk_string(source)
  chk::chk_string(file_name)

  entry <- crt_registry_entry(source, file_name)
  schema <- crt_schema_read(entry$schema_yaml[[1L]])

  crt_schema_validate(df, schema)
  crt_schema_apply(df, schema)
}
