#' Fingerprint a capture's column set
#'
#' Computes the `schema_version` value the `nge/form_capture` schema declares:
#' `<n>-<digest>`, where `n` is the number of columns and `digest` is the 64-bit
#' xxHash, in hex, of the columns' `name:TYPE` pairs sorted by name and joined
#' with commas.
#'
#' The rule lives here so that every producer computes it the same way. Two
#' producers that differed would give two different vintages the same version,
#' or one vintage two versions, and nothing downstream could tell.
#'
#' @section What goes in:
#' Pass the capture's **own** columns with the types the file declares, as a
#' named character vector: `c(date_time_start = "DATETIME", gravel = "REAL")`.
#' For a GeoPackage that is `PRAGMA table_info()`'s `type`. Leave out the
#' geometry column and any surrogate row id the reader supplies rather than the
#' capture carrying, such as a GeoPackage `fid`.
#'
#' Types are part of the pair because a column that changes type between
#' vintages is a real schema change, and a fingerprint of names alone would
#' report it as none. They are upper-cased first, so `real` and `REAL` agree.
#' Names are sorted in C collation, so the value does not depend on the
#' machine's locale, and column order does not move it.
#'
#' @section What gets hashed:
#' The bytes of the joined string, not R's serialization of it. A hash of a
#' serialized object depends on the serialization format, which R can change
#' without any schema change behind it, and no other language could reproduce
#' it. The digest is the standard XXH64 with seed 0, so any implementation of
#' it gives the same value from the same string.
#'
#' @param types Named character vector of declared column types, one element
#'   per column, names being the column names.
#'
#' @return A string, `<n>-<16 hex digits>`.
#'
#' @examples
#' types <- c(date_time_start = "DATETIME", wetted_width_m = "REAL",
#'            crew_members = "TEXT")
#' crt_schema_fingerprint(types)
#'
#' # Column order does not matter; a changed type does.
#' crt_schema_fingerprint(rev(types))
#' crt_schema_fingerprint(replace(types, "wetted_width_m", "TEXT"))
#'
#' @export
crt_schema_fingerprint <- function(types) {
  if (!is.character(types) || length(types) == 0L) {
    cli::cli_abort(
      "{.arg types} must be a non-empty named character vector of declared types."
    )
  }
  cols <- names(types)
  if (is.null(cols) || anyNA(cols) || any(!nzchar(cols))) {
    cli::cli_abort("Every element of {.arg types} must be named with its column.")
  }
  if (anyDuplicated(cols)) {
    cli::cli_abort(c(
      "Column names in {.arg types} must be unique.",
      "x" = "Repeated: {.val {unique(cols[duplicated(cols)])}}."
    ))
  }
  # NA or blank would hash as "name:NA" or "name:", quietly reducing the
  # fingerprint to one over names alone, which is blind to the change it exists
  # to catch.
  bad <- cols[is.na(types) | !nzchar(trimws(types))]
  if (length(bad)) {
    cli::cli_abort(c(
      "No declared type for {.val {bad}}.",
      "i" = "The fingerprint covers {.code name:type} pairs, so every column needs a type."
    ))
  }

  # The digest is over bytes, so the same name in two encodings would give two
  # values. UTF-8 is the one every other producer will use. A name whose bytes
  # are already UTF-8 but carry no mark is marked first: enc2utf8() reads an
  # unmarked string in the session's locale, so under C it would escape the
  # bytes and one column set would get two fingerprints.
  unmarked <- Encoding(cols) == "unknown" & validUTF8(cols)
  Encoding(cols)[unmarked] <- "UTF-8"
  names(types) <- enc2utf8(cols)
  cols <- sort(names(types), method = "radix")
  pairs <- enc2utf8(paste0(cols, ":", toupper(unname(types[cols])), collapse = ","))
  paste0(length(cols), "-", digest::digest(pairs, algo = "xxhash64", serialize = FALSE))
}
