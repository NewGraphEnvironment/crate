#' List registered (source, file_name) entries crate knows how to ingest
#'
#' Returns the registry as a tibble. Optionally filterable by `source`.
#' Output drives consumer-side config authoring: callers (e.g. link's
#' `lnk_load_overrides()`) use this to know what entries crate can handle.
#'
#' @param source Character or NULL. If supplied, filter to entries with that
#'   source family code (e.g. `"bcfp"`). NULL returns all entries.
#'
#' @return A tibble with columns `source`, `file_name`, `handler_fn`,
#'   `schema_yaml`, `canonical_cols`.
#'
#' @examples
#' # All registered (source, file_name) entries
#' crt_files()
#'
#' # Filter to bcfp-sourced entries
#' crt_files(source = "bcfp")
#'
#' # Bogus source filter returns an empty tibble (not an error)
#' crt_files(source = "nonexistent")
#'
#' @seealso [crt_ingest()] to actually ingest a registered file.
#' @export
crt_files <- function(source = NULL) {
  if (!is.null(source)) {
    chk::chk_string(source)
  }

  reg <- crt_registry_load() # nolint: object_usage_linter.

  if (!is.null(source)) {
    reg <- reg[reg$source == source, , drop = FALSE]
  }

  reg
}
