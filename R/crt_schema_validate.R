#' Validate a data frame against a schema's canonical column declarations
#'
#' Checks that every column declared `required: true` in the schema's
#' `canonical.cols` is present in `names(df)`. Fails loud listing all missing
#' required columns. Returns `invisible(NULL)` on success.
#'
#' Called by [crt_ingest()] AFTER handler dispatch and BEFORE
#' [crt_schema_apply()] — validate shape first (fail loud on missing required
#' cols), coerce types second. Without validation here, a missing required
#' column would silently become NA after `as.integer(NULL)`-style coercion in
#' the type-apply step; this surfaces the failure at the right layer.
#'
#' Lives in the `crt_schema_*` family alongside [crt_schema_apply()] and
#' [crt_schema_read()].
#'
#' @details
#' Future extensions (reserved family slots; NOT in v0.0.2):
#'
#' - `cols[].range` numeric range checks
#' - `cols[].enum` value-membership checks
#' - `cols[].predicate` custom predicate function refs
#'
#' Each lands as additional `cli::cli_abort` branches in this function as
#' the schema YAML grows the corresponding declaration keys. The function
#' signature does not change — schema YAML drives behavior.
#'
#' @param df A data frame (handler output, post-shape, pre-type).
#' @param schema The parsed schema YAML (a list with `canonical$cols`).
#' @return `invisible(NULL)` on success. Throws fail-loud `cli::cli_abort`
#'   listing all missing required columns on failure.
#' @keywords internal
crt_schema_validate <- function(df, schema) {
  cols <- schema[["canonical"]][["cols"]]
  if (is.null(cols)) {
    return(invisible(NULL))
  }
  missing <- character(0)
  for (col_spec in cols) {
    col_name <- col_spec[["name"]]
    required <- isTRUE(col_spec[["required"]])
    if (is.null(col_name) || !required) next
    if (!col_name %in% names(df)) {
      missing <- c(missing, col_name)
    }
  }
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "Schema validation failed: required canonical columns missing.",
      "x" = "Missing: {paste(missing, collapse = ', ')}"
    ))
  }
  invisible(NULL)
}
