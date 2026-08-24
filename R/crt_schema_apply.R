#' Apply a schema's canonical type declarations to handler output
#'
#' Schema YAML is the single source of truth for canonical column types.
#' [crt_schema_conform()] calls this after validation, so every registered
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
#' - `datetime` -> `POSIXct` rendered in UTC, see below
#'
#' @section datetime is stamped, never converted:
#'
#' A `datetime` column means **an instant**, and this function never changes
#' which instant it is. A `POSIXct` input has its `tzone` attribute *stamped*
#' to `"UTC"`, which changes the rendering and nothing else; the epoch is
#' untouched.
#'
#' That distinction is the whole point of the type. Several readers return
#' correct UTC instants with an **empty `tzone`** attribute — GeoPackage
#' `DATETIME` columns read through `sf` are the case this was written for — so
#' R renders them in `Sys.timezone()`. On a UTC-7 machine the same instant
#' prints seven hours earlier than it does from an epoch, which reads as a
#' second clock in a second timezone. Converting to "fix" the rendering injects
#' a real whole-hour error into every downstream join; stamping fixes the label,
#' which is all that was ever wrong.
#'
#' Other inputs:
#'
#' - numeric is read as **epoch seconds**
#' - `Date` is read as UTC midnight. Note [as.POSIXct()] silently ignores `tz`
#'   for a `Date`, converting in the system zone instead, so this goes through
#'   `format()` first — west of UTC the naive call moves the day boundary.
#' - character is parsed as ISO 8601 in UTC, accepting a `T` separator and a
#'   trailing `Z`
#'
#' @param df A data frame.
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
      "datetime" = crt_datetime_utc(x, col_name),
      cli::cli_abort(c(
        "Unknown canonical type {.val {col_type}} declared for column {.field {col_name}}.",
        "i" = "Supported types: integer, double, string, logical, datetime."
      ))
    )
  }
  tibble::as_tibble(df)
}

#' Coerce a column to POSIXct rendered in UTC without moving the instant
#'
#' See the `datetime is stamped, never converted` section of
#' [crt_schema_apply()] for why this stamps rather than converts.
#'
#' @param x A vector.
#' @param col_name Column name, for the error message.
#' @return A POSIXct vector with `tzone` set to UTC.
#' @keywords internal
#' @noRd
crt_datetime_utc <- function(x, col_name) {
  if (inherits(x, "POSIXct")) {
    # Stamp. Assigning tzone relabels the rendering; the underlying epoch,
    # which is what every join and comparison uses, is not touched.
    attr(x, "tzone") <- "UTC"
    return(x)
  }
  if (inherits(x, "Date")) {
    # as.POSIXct.Date ignores `tz` and converts in the system zone, so west of
    # UTC a date lands on the previous day. format() first sidesteps that.
    return(as.POSIXct(format(x), tz = "UTC"))
  }
  if (is.numeric(x)) {
    return(as.POSIXct(as.numeric(x), origin = "1970-01-01", tz = "UTC"))
  }
  if (is.character(x)) {
    return(crt_datetime_parse_iso(x, col_name))
  }
  if (all(is.na(x))) {
    # An all-NA logical is what an empty column reads back as; there is no
    # instant to preserve, so this is unambiguous rather than a guess.
    return(as.POSIXct(rep(NA_real_, length(x)), origin = "1970-01-01", tz = "UTC"))
  }
  cli::cli_abort(c(
    "Cannot read {.field {col_name}} as a {.val datetime}.",
    "x" = "Got {.cls {class(x)}}.",
    "i" = "Supported: POSIXct, Date, numeric epoch seconds, ISO 8601 character."
  ))
}

#' Parse ISO 8601 character to POSIXct in UTC
#' @param x Character vector.
#' @param col_name Column name, for the error message.
#' @return A POSIXct vector in UTC.
#' @keywords internal
#' @noRd
crt_datetime_parse_iso <- function(x, col_name) {
  # Normalise the two ISO spellings R's parser does not take: the "T"
  # separator and a trailing zone designator. Only "Z" (and an explicit
  # +00:00) is accepted -- a non-UTC offset is dropped silently by
  # as.POSIXct(format = ...), which would be a silent hour error, so refuse it.
  trimmed <- trimws(x)
  offset <- grepl("[+-][0-9]{2}:?[0-9]{2}$", trimmed) &
    !grepl("[+-]00:?00$", trimmed)
  if (any(offset, na.rm = TRUE)) {
    bad <- unique(trimmed[which(offset)]) # nolint: object_usage_linter.
    cli::cli_abort(c(
      "{.field {col_name}} carries a non-UTC offset.",
      "x" = "First seen: {.val {bad[[1]]}}.",
      "i" = "Declare the column as {.val string} if the offset must survive; a \\
             {.val datetime} is stored as an instant in UTC."
    ))
  }
  cleaned <- sub("[Zz]$", "", sub("T", " ", trimmed))
  cleaned <- sub("[+-]00:?00$", "", cleaned)
  # as.POSIXct.character throws on an unrecognised string rather than
  # returning NA, and the message it throws ("not in a standard unambiguous
  # format") names neither the column nor the value. Catch it so the abort
  # below is the one the caller sees.
  out <- tryCatch(
    as.POSIXct(cleaned, tz = "UTC"),
    error = function(e) as.POSIXct(rep(NA_real_, length(cleaned)),
                                   origin = "1970-01-01", tz = "UTC")
  )
  unparsed <- is.na(out) & !is.na(trimmed) & nzchar(trimmed)
  if (any(unparsed)) {
    bad <- unique(trimmed[which(unparsed)]) # nolint: object_usage_linter.
    cli::cli_abort(c(
      "{.field {col_name}} is not parseable as ISO 8601.",
      "x" = "First unparseable value: {.val {bad[[1]]}}."
    ))
  }
  out
}
