# data-raw/crate_registry.R
#
# Documents the registry authoring process for `inst/extdata/crate_registry.csv`.
#
# The registry is hand-authored. Each row pairs a (source, file_name) with the
# schema YAML that declares its canonical shape, and -- for entries crate reads
# -- the handler that normalizes an upstream variant into it.
#
# Columns:
#   source          source family code (bcfp, nge, ...)
#   file_name       logical file name (e.g. user_habitat_classification)
#   kind            `file`        crate reads the source file and dispatches to
#                                 handler_fn; crt_ingest() serves it
#                   `schema_only` crate declares the canonical shape and the
#                                 caller supplies the frame via
#                                 crt_schema_conform(); crt_ingest() aborts
#   handler_fn      R function in the crate namespace; empty for schema_only
#   schema_yaml     path under inst/extdata/
#   canonical_cols  comma-separated canonical column names (informational; the
#                   schema YAML is the source of truth)
#
# To add a `file` entry:
#   1. Author the schema YAML at inst/extdata/schemas/<source>/<file_name>.yaml
#   2. Implement R/crt_handler_<source>_<file_name>.R (takes raw data +
#      variant_id; dispatches internally)
#   3. Append a row with kind = file
#   4. Write a decision entry at decisions/<source>/<YYYYMMDD>_<topic>.md
#   5. Cover every known variant in tests/testthat/test-crt_ingest.R
#
# To add a `schema_only` entry: steps 1, 3 (kind = schema_only, handler_fn
# empty) and 4, plus a conform test in tests/testthat/test-crt_schema_conform.R.
#
# Quote any column name YAML 1.1 would resolve to a boolean -- a bare y, Y, n,
# N, yes, no, on, off, true or false stops being a string and silently stops
# being a column. `- name: "y"`, not `- name: y`.
#
# The structural checks that used to live here now run in
# tests/testthat/test-crt_registry_integrity.R, where they execute on every
# push rather than when someone remembers to source this file. What remains
# below is a convenience for authoring: run it after editing the CSV to get the
# same answer without a full test run.

# Unconditionally, and unqualified below. requireNamespace() succeeds against
# whatever version happens to be installed, so a guarded load would validate a
# registry that is not the one in this working tree.
pkgload::load_all(quiet = TRUE)

reg <- crt_registry_load()
stopifnot(nrow(reg) >= 1L)

for (i in seq_len(nrow(reg))) {
  schema_path <- file.path("inst/extdata", reg$schema_yaml[i])
  if (!file.exists(schema_path)) {
    stop("Schema YAML missing for row ", i, ": ", schema_path)
  }
  yaml::read_yaml(schema_path)

  if (identical(reg$kind[i], "file")) {
    fn <- reg$handler_fn[i]
    if (is.na(fn) || !nzchar(fn)) {
      stop("kind = file needs a handler_fn: ", reg$file_name[i])
    }
    if (!exists(fn, mode = "function")) {
      warning("Handler not yet defined: ", fn,
              " (acceptable while scaffolding, before R/ is written)")
    }
  } else if (identical(reg$kind[i], "schema_only")) {
    if (!is.na(reg$handler_fn[i]) && nzchar(reg$handler_fn[i])) {
      stop("kind = schema_only must not name a handler: ", reg$file_name[i])
    }
  } else {
    stop("Unknown kind for ", reg$file_name[i], ": ", reg$kind[i])
  }
}

message("Registry validated: ", nrow(reg), " entries (",
        sum(reg$kind == "file"), " file, ",
        sum(reg$kind == "schema_only"), " schema_only).")
