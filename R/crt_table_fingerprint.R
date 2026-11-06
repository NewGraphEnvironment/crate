#' Fingerprint a table's values
#'
#' Computes the value a provenance receipt stores in `result.fingerprint` for a
#' table: the SHA-256, in lowercase hex, of the table's canonical form. Two tables
#' with the same rows in any order, and the same columns in any order, have the
#' same fingerprint; any changed value changes it, except a double moved less than
#' its declared tolerance's rounding.
#'
#' Not [crt_schema_fingerprint()], which hashes a table's column names and types and
#' never its values.
#'
#' @section The canonical form:
#' The RFC 8785 canonical JSON of `{"columns": [...], "rows": [[...], ...]}`, so any
#' language with a JCS serializer and SHA-256 reproduces it (crate#43):
#'
#' * Columns are sorted by name, as UTF-8 bytes (C collation).
#' * Every cell is a JSON string, or `null` for `NA`.
#' * Character values are their UTF-8 text, not Unicode-normalized; factors are
#'   their labels.
#' * Integers are their decimal digits; logicals are `true` and `false`.
#' * A double with a declared tolerance `10^-k` is written with exactly `k`
#'   decimals, rounding its exact binary value with ties to even, as C's `printf`
#'   and Python's `format(x, ".kf")` do. With no tolerance it is written in
#'   ECMAScript's shortest round-trip form, so it is exact. A zero is written
#'   without a sign. `NaN` and infinite values abort.
#' * Dates are `YYYY-MM-DD`. Datetimes are converted to UTC and written
#'   `YYYY-MM-DDTHH:MM:SSZ`; one with fractional seconds aborts, so round it or
#'   fingerprint it as a number. A subclass of `Date` or `POSIXct`, such as
#'   data.table's `IDate`, is spelled as its base class.
#' * Rows are sorted by the UTF-8 bytes of each row's own canonical JSON.
#'
#' @param x A data frame.
#' @param tolerance A named numeric vector or list: for each double column that is
#'   allowed to move between equivalent builds, its absolute tolerance, a power of
#'   ten from `1` to `1e-15`. Columns not named are fingerprinted exactly.
#'
#' @return A string of 64 lowercase hex digits.
#'
#' @examples
#' a <- data.frame(segment = c("b", "a"), km = c(12.5, 3.0000000001))
#' b <- data.frame(km = c(3.0000000002, 12.5), segment = c("a", "b"))
#'
#' # Different rows order, column order and an 11th-decimal difference
#' crt_table_fingerprint(a) == crt_table_fingerprint(b)
#' crt_table_fingerprint(a, c(km = 1e-9)) == crt_table_fingerprint(b, c(km = 1e-9))
#'
#' @export
crt_table_fingerprint <- function(x, tolerance = NULL) {
  receipt_sha256(table_canonical(x, tolerance))
}

# The canonical JSON itself; tests and the vectors read it to show what was hashed.
table_canonical <- function(x, tolerance = NULL) {
  if (!is.data.frame(x)) {
    cli::cli_abort("{.arg x} must be a data frame, not {.obj_type_friendly {x}}.")
  }
  cols <- names(x)
  if (!length(cols)) {
    cli::cli_abort("{.arg x} has no columns, so there is nothing to fingerprint.")
  }
  if (anyNA(cols) || any(!nzchar(cols))) {
    cli::cli_abort("Every column of {.arg x} needs a name.")
  }
  cols <- jcs_utf8(cols, "names(x)")
  if (anyDuplicated(cols)) {
    cli::cli_abort(c(
      "Column names in {.arg x} must be unique.",
      "x" = "Repeated: {.val {unique(cols[duplicated(cols)])}}."
    ))
  }
  names(x) <- cols
  decimals <- table_decimals(tolerance, x)

  ord <- order(cols, method = "radix")
  cells <- lapply(cols[ord], function(nm) table_cells(x[[nm]], nm, decimals[nm]))
  rows <- if (nrow(x)) {
    paste0("[", do.call(paste, c(cells, sep = ",")), "]")
  } else {
    character()
  }
  rows <- enc2utf8(rows)
  rows <- rows[order(rows, method = "radix")]
  paste0(
    "{\"columns\":[", paste(jcs_string(cols[ord]), collapse = ","), "],",
    "\"rows\":[", paste(rows, collapse = ","), "]}"
  )
}

# Decimals per column (NA where exact), from a tolerance per double column.
table_decimals <- function(tolerance, x) {
  out <- stats::setNames(rep(NA_integer_, ncol(x)), names(x))
  if (is.null(tolerance) || !length(tolerance)) return(out)
  if (is.list(tolerance)) tolerance <- unlist(tolerance)
  tn <- names(tolerance)
  if (!is.numeric(tolerance) || is.null(tn) || anyNA(tn) || any(!nzchar(tn))) {
    cli::cli_abort("{.arg tolerance} must be a named numeric vector, one value per column.")
  }
  tn <- jcs_utf8(tn, "names(tolerance)")
  if (anyDuplicated(tn)) {
    cli::cli_abort("{.arg tolerance} repeats {.val {unique(tn[duplicated(tn)])}}.")
  }
  unknown <- setdiff(tn, names(x))
  if (length(unknown)) {
    cli::cli_abort("{.arg tolerance} names {.val {unknown}}, which {?is/are} not a column of {.arg x}.")
  }
  not_double <- tn[!vapply(tn, function(nm) is.double(x[[nm]]) && !inherits(x[[nm]], c("Date", "POSIXt")), TRUE)]
  if (length(not_double)) {
    cli::cli_abort(c(
      "A tolerance applies to double columns only.",
      "x" = "Not double: {.val {not_double}}."
    ))
  }
  out[tn] <- receipt_decimals(tolerance, "tolerance")
  out
}

#' The decimals a tolerance rounds to
#'
#' A tolerance is an absolute power of ten from 1 to 1e-15, so it names both the
#' rounding of a fingerprint (`k` decimals) and what the comparison accepts.
#'
#' @param tol Numeric vector of tolerances.
#' @param what Where they came from, for the message.
#' @return Integer vector of decimals, `k` for `10^-k`.
#' @noRd
receipt_decimals <- function(tol, what) {
  k <- suppressWarnings(as.integer(round(-log10(tol))))
  ok <- !is.na(tol) & tol > 0 & !is.na(k) & k >= 0L & k <= 15L &
    abs(tol / 10^-k - 1) < 1e-9
  if (!all(ok)) {
    bad <- if (is.null(names(tol))) format(tol[!ok]) else names(tol)[!ok] # nolint: object_usage_linter.
    cli::cli_abort(c(
      "Each {what} must be a power of ten from 1 to 1e-15.",
      "x" = "Not one: {.val {bad}}.",
      "i" = "A tolerance of 1e-9 rounds to 9 decimals; one that is not a power of ten has no rounding that matches it."
    ))
  }
  k
}

# One column's cells, each already a JSON token: a quoted string or null.
table_cells <- function(v, nm, k) {
  # The same whitelist as the JSON serializer: a column's class decides its spelling, so
  # an unknown one (octmode, hexmode, ITime, units, haven_labelled) is refused, not
  # printed through its methods. A matrix column would be flattened into extra rows.
  # A subclass of Date or POSIXct (data.table's IDate, c("IDate", "Date") on integer
  # storage) is the same day count or instant, so it is admitted and rebuilt as its
  # base class below: the base class spells it, never the subclass's methods.
  cls <- oldClass(v)
  is_date <- table_ends_with(cls, "Date") && (is.double(v) || is.integer(v))
  is_time <- table_ends_with(cls, c("POSIXct", "POSIXt")) && is.double(v)
  known <- is.null(cls) || identical(cls, "factor") || is_date || is_time
  # An attribute the spelling does not read (a units attribute on a plain double) would
  # be dropped: 5 km would fingerprint as 5 m.
  extra <- setdiff(names(attributes(v)), c("names", "class", "levels", "tzone"))
  if (!known || !is.null(dim(v)) || is.list(v) || length(extra)) {
    cli::cli_abort(c(
      "Column {.field {nm}} has class {.cls {class(v)}}, which has no canonical form.",
      "i" = paste("Fingerprint character, factor, integer, double, logical, Date or POSIXct columns;",
                  "convert or drop the rest (a geometry as WKT, a matrix as columns).")
    ))
  }
  if (is_date) v <- structure(as.double(unclass(v)), class = "Date")
  if (is_time) v <- structure(as.double(unclass(v)), class = c("POSIXct", "POSIXt"))
  if (is.factor(v)) v <- as.character(v)
  out <- rep("null", length(v))
  na <- is.na(v)
  if (inherits(v, "Date")) {
    if (any(!is.finite(unclass(v)[!na]))) {
      cli::cli_abort("Column {.field {nm}} has an infinite date.")
    }
    txt <- table_ymd(as.POSIXlt(v[!na], tz = "UTC"), nm)
  } else if (inherits(v, "POSIXt")) {
    secs <- unclass(v)[!na]
    if (any(!is.finite(secs))) {
      cli::cli_abort("Column {.field {nm}} has an infinite datetime.")
    }
    if (any(secs != floor(secs))) {
      cli::cli_abort(c(
        "Column {.field {nm}} has fractional seconds.",
        "i" = "Round it to whole seconds, or fingerprint it as a number with a tolerance."
      ))
    }
    lt <- as.POSIXlt(v[!na], tz = "UTC")
    txt <- paste0(table_ymd(lt, nm), sprintf("T%02d:%02d:%02dZ", lt$hour, lt$min, as.integer(lt$sec)))
  } else if (is.character(v)) {
    txt <- jcs_utf8(v[!na], nm)
  } else if (is.logical(v)) {
    txt <- ifelse(v[!na], "true", "false")
  } else if (is.integer(v)) {
    txt <- as.character(v[!na])
  } else if (is.double(v)) {
    vals <- v[!na]
    if (any(is.nan(v) | is.infinite(v))) {
      cli::cli_abort("Column {.field {nm}} has NaN or infinite values, which have no canonical form.")
    }
    if (is.na(k)) {
      txt <- jcs_numbers(vals)
    } else {
      txt <- sprintf(paste0("%.", k, "f"), vals)
      # printf keeps the sign of a value that rounds to zero ("-0.00"); one zero has
      # one spelling.
      txt <- sub("^-(0(\\.0*)?)$", "\\1", txt)
    }
  } else {
    cli::cli_abort(c(
      "Column {.field {nm}} has class {.cls {class(v)}}, which has no canonical form.",
      "i" = paste("Fingerprint character, factor, integer, double, logical, Date or POSIXct columns;",
                  "convert or drop the rest (a geometry as WKT).")
    ))
  }
  out[!na] <- jcs_string(txt)
  out
}

# Whether a class vector ends in `base`, so it is `base` or a subclass of it.
table_ends_with <- function(cls, base) {
  n <- length(cls)
  n >= length(base) && identical(cls[seq(n - length(base) + 1L, n)], base)
}

# YYYY-MM-DD, spelled field by field: format("%Y") does not pad years below 1000 on
# Linux ("999-03-04") where macOS does ("0999-03-04"). R writes year -221 or 10183
# without complaint, Python's datetime holds neither, and a datetime that is epoch
# milliseconds read as seconds lands near year 57,000: refuse what has no YYYY.
table_ymd <- function(lt, nm) {
  year <- lt$year + 1900L
  table_year_check(year, nm)
  sprintf("%04d-%02d-%02d", year, lt$mon + 1L, lt$mday)
}

table_year_check <- function(year, nm) {
  bad <- year < 1L | year > 9999L
  if (any(bad)) {
    cli::cli_abort(c(
      "Column {.field {nm}} has a year outside 1-9999: {.val {unique(year[bad])}}.",
      "i" = "A datetime far in the future is often milliseconds read as seconds."
    ))
  }
}
