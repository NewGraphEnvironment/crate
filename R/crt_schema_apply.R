#' Apply a schema's canonical type declarations to handler output
#'
#' Schema YAML is the single source of truth for canonical column types.
#' [crt_ingest()] calls this after the registered handler returns, so every
#' (source, file_name) pair gets type enforcement for free — handlers do not
#' encode type knowledge.
#'
#' Reads `canonical.cols[].type` from the schema and coerces each named
#' column to the declared type. Columns present in the data but absent from
#' the schema's `canonical.cols` are left untouched. Columns absent from the
#' data but declared in the schema are left to [crt_schema_validate()] to
#' surface (this function does not validate presence — only type when the
#' column exists).
#'
#' Supported `type` values:
#'
#' - `integer` -> [as.integer()]
#' - `double` -> [as.double()]
#' - `string` -> [as.character()] (handles readr's Date / POSIXct
#'   auto-parsing for columns the schema declares as text)
#' - `logical` -> [as.logical()]
#'
#' @param df A data frame returned by a registered handler.
#' @param schema The parsed schema YAML (a list with `canonical$cols`).
#' @return A tibble with columns coerced to canonical types.
#' @keywords internal
crt_schema_apply <- function(df, schema) {
  cols <- schema[["canonical"]][["cols"]]
  if (is.null(cols)) {
    return(tibble::as_tibble(df))
  }
  for (col_spec in cols) {
    col_name <- col_spec[["name"]]
    col_type <- col_spec[["type"]]
    if (is.null(col_name) || is.null(col_type)) next
    if (!col_name %in% names(df)) next
    x <- df[[col_name]]
    df[[col_name]] <- switch(
      col_type,
      "integer" = if (is.integer(x)) x else suppressWarnings(as.integer(x)),
      "double"  = if (is.double(x)) x else suppressWarnings(as.double(x)),
      "string"  = if (is.character(x)) x else as.character(x),
      "logical" = if (is.logical(x)) x else as.logical(x),
      cli::cli_abort(c(
        "Unknown canonical type {.val {col_type}} declared for column {.field {col_name}}.",
        "i" = "Supported types: integer, double, string, logical."
      ))
    )
  }
  tibble::as_tibble(df)
}
