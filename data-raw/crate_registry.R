# data-raw/crate_registry.R
#
# Documents the registry authoring process for `inst/extdata/crate_registry.csv`.
#
# v0.0.1: registry is hand-authored. Each row pairs a (source, file_name)
# with the R handler function name (per-(source, file_name); takes raw
# data + variant_id), the schema YAML path (relative to inst/extdata/),
# and the canonical column list.
#
# Future: when crate has > 5 source families, consider auto-generating
# the registry from `inst/extdata/schemas/<source>/*.yaml` filenames
# + introspection of R/internal_*.R function names. For v0.0.1 the
# overhead doesn't earn its place.
#
# To add an entry:
#   1. Author the schema YAML at `inst/extdata/schemas/<source>/<file_name>.yaml`
#   2. Implement the handler in `R/internal_<source>_<file_name>.R`
#      (function takes raw data + variant_id; dispatches internally)
#   3. Append a row to `inst/extdata/crate_registry.csv` with:
#        source             = source family code (bcfp, edna, etc.)
#        file_name          = logical file name (e.g. user_habitat_classification)
#        handler_fn         = R function name in crate namespace
#        schema_yaml        = path under inst/extdata/ (e.g. schemas/bcfp/user_habitat_classification.yaml)
#        canonical_cols     = comma-separated canonical column names (informational; full schema lives in YAML)
#   4. Add tests in `tests/testthat/test-crt_ingest.R` covering all known variants

# Sanity-check: registry parses cleanly and all referenced schema YAMLs exist
reg <- read.csv("inst/extdata/crate_registry.csv", stringsAsFactors = FALSE)
stopifnot(nrow(reg) >= 1L)
for (i in seq_len(nrow(reg))) {
  schema_path <- file.path("inst/extdata", reg$schema_yaml[i])
  if (!file.exists(schema_path)) {
    stop("Schema YAML missing for row ", i, ": ", schema_path)
  }
  handler_exists <- exists(reg$handler_fn[i], envir = asNamespace("crate"), inherits = FALSE)
  if (!handler_exists) {
    warning("Handler not exported in crate namespace yet: ", reg$handler_fn[i],
            " (acceptable during initial scaffolding before R/ files are written)")
  }
}
message("Registry validated: ", nrow(reg), " entries.")
