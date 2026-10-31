#' Name the known version each record was captured with
#'
#' Looks up each row's `schema_version` fingerprint among the upstream variants
#' a registered schema lists, and returns the variant's `id`. A fingerprint the
#' schema does not list comes back `NA`: a capture shape nobody has recorded
#' yet, which is worth looking at rather than guessing at.
#'
#' A fingerprint describes a column set, so on its own it cannot say which
#' build of a form a record came from. Each per-form schema therefore lists
#' its form's known versions as `upstream_variants`, each with the fingerprint a
#' capture of it produces. That names the version of forms already in the field,
#' with no change to the deployed forms.
#'
#' @inheritParams crt_schema_grade
#'
#' @return A character vector, one element per row of `df`: the variant `id`,
#'   or `NA` where the fingerprint is not listed or is missing.
#'
#' @details
#' [crt_schema_conform()] reports unlisted fingerprints as a warning of class
#' `crate_unknown_fingerprint`, for schemas that list any. This function is how
#' to find which rows they were.
#'
#' Throws when `df` has no `schema_version` column, or the schema lists no
#' fingerprints.
#'
#' @examples
#' types <- c(date_time_start = "DATETIME", crew_members = "TEXT")
#' records <- data.frame(record_id = 1L, schema_version = crt_schema_fingerprint(types))
#' crt_schema_variant(records, "nge", "form_monitoring_fish_passage")
#'
#' @seealso [crt_schema_fingerprint()] for how a fingerprint is computed.
#' @export
crt_schema_variant <- function(df, source, file_name) {
  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg df} must be a data frame, not {.cls {class(df)}}.")
  }
  if (!"schema_version" %in% names(df)) {
    cli::cli_abort("{.arg df} has no {.field schema_version} column to look up.")
  }
  crt_schema_variant_match(df[["schema_version"]], crt_schema_get(source, file_name))
}

# Internal: fingerprint -> variant id over a parsed schema.
crt_schema_variant_match <- function(fingerprint, schema) {
  known <- crt_schema_fingerprints(schema)
  if (!length(known)) {
    cli::cli_abort(c(
      "Schema {.val {schema$file}} lists no fingerprint for any upstream variant.",
      "i" = "Only a schema that records its known versions can name one."
    ))
  }
  unname(known[match(as.character(fingerprint), names(known), incomparables = NA)])
}

# Internal: named vector, fingerprint -> variant id, of the variants that
# carry one.
crt_schema_fingerprints <- function(schema) {
  vars <- Filter(function(v) !is.null(v[["fingerprint"]]), schema[["upstream_variants"]])
  stats::setNames(
    vapply(vars, function(v) as.character(v[["id"]]), character(1)),
    vapply(vars, function(v) as.character(v[["fingerprint"]]), character(1))
  )
}

# Internal: called by crt_schema_conform(). Reports, never fails: a new vintage
# is a fact to notice, and refusing it would make the harvest that found it
# the thing that cannot run. Silent for a schema listing no fingerprints, which
# is every schema that does not describe a versioned capture.
crt_schema_fingerprint_check <- function(df, schema) {
  known <- crt_schema_fingerprints(schema)
  if (!length(known) || !"schema_version" %in% names(df)) {
    return(invisible(df))
  }
  fp <- as.character(df[["schema_version"]])
  unknown <- unique(fp[!is.na(fp) & !fp %in% names(known)])
  if (length(unknown)) {
    cli::cli_warn(
      c(
        "{length(unknown)} fingerprint{?s} not listed by schema {.val {schema$file}}: {.val {unknown}}.",
        "i" = "{sum(fp %in% unknown)} row{?s} {?was/were} captured with a form version \\
               nobody has recorded. Add it to the schema's {.field upstream_variants}.",
        "i" = "{.fn crt_schema_variant} returns {.val NA} for these rows."
      ),
      class = "crate_unknown_fingerprint"
    )
  }
  invisible(df)
}
