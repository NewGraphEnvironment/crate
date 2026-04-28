# data-raw/example_fixtures_bcfp_user_habitat_classification.R
#
# Documents the example fixture CSVs at:
#   inst/extdata/examples/bcfp/wide_user_habitat_classification.csv
#   inst/extdata/examples/bcfp/long_user_habitat_classification.csv
#
# These are hand-authored synthetic fixtures designed to:
#   - Be small enough to inspect in one screen (~6 rows wide, ~7 rows long)
#   - Cover the test cases that exercise both adapter paths:
#       * wide-variant identity (spawning-only / rearing-only / both / -4 excluded)
#       * long-variant pivot to wide (each truthy habitat_type entry → wide row)
#   - Have the long fixture be SEMANTICALLY EQUIVALENT to a SUBSET of the wide
#     fixture (specifically, the wide fixture rows MINUS the -4 excluded row,
#     since the historical long format did not encode -4 semantics).
#
# Invariance test:
#   crt_ingest("bcfp", "user_habitat_classification", path = <long-fixture>)
#   should equal
#   crt_ingest("bcfp", "user_habitat_classification", path = <wide-fixture-without-excluded-row>)
#
# To regenerate (no script — fixtures are hand-authored CSVs). To modify:
#   1. Edit both CSVs together to keep them semantically equivalent
#   2. Update tests/testthat/test-crt_ingest.R if cases change
#   3. Note: the wide fixture's -4 excluded row has NO long-fixture equivalent
#      (long historical format predates the -4 encoding)
#
# Usage in tests + examples:
#   system.file("extdata/examples/bcfp/wide_user_habitat_classification.csv", package = "crate")
#   system.file("extdata/examples/bcfp/long_user_habitat_classification.csv", package = "crate")

# Sanity-check fixtures parse and have expected shape
wide_path <- "inst/extdata/examples/bcfp/wide_user_habitat_classification.csv"
long_path <- "inst/extdata/examples/bcfp/long_user_habitat_classification.csv"

stopifnot(file.exists(wide_path), file.exists(long_path))

wide <- read.csv(wide_path, stringsAsFactors = FALSE)
long <- read.csv(long_path, stringsAsFactors = FALSE)

stopifnot(
  all(c("spawning", "rearing") %in% names(wide)),
  all(c("habitat_type", "habitat_ind") %in% names(long))
)

message(sprintf("Wide fixture: %d rows", nrow(wide)))
message(sprintf("Long fixture: %d rows", nrow(long)))
