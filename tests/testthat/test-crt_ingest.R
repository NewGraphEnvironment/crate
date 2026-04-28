wide_fixture <- function() {
  system.file(
    "extdata/examples/bcfp/wide_user_habitat_classification.csv",
    package = "crate"
  )
}

long_fixture <- function() {
  system.file(
    "extdata/examples/bcfp/long_user_habitat_classification.csv",
    package = "crate"
  )
}

canonical_cols <- c(
  "blue_line_key", "downstream_route_measure", "upstream_route_measure",
  "watershed_group_code", "species_code", "spawning", "rearing",
  "reviewer_name", "review_date", "source", "notes"
)

test_that("wide-variant input returns canonical wide tibble (identity)", {
  out <- crt_ingest("bcfp", "user_habitat_classification", wide_fixture())
  expect_s3_class(out, "tbl_df")
  expect_equal(names(out), canonical_cols)
  expect_equal(nrow(out), 6L)
})

test_that("long-variant input returns canonical wide tibble (pivot)", {
  out <- crt_ingest("bcfp", "user_habitat_classification", long_fixture())
  expect_s3_class(out, "tbl_df")
  expect_equal(names(out), canonical_cols)
  # Long fixture has 7 rows covering 5 unique (segment x species) tuples
  expect_equal(nrow(out), 5L)
})

test_that("invariance: long pivoted == wide identity (minus -4 excluded row)", {
  wide <- crt_ingest("bcfp", "user_habitat_classification", wide_fixture())
  long <- crt_ingest("bcfp", "user_habitat_classification", long_fixture())

  # Drop the -4 excluded row from wide for comparison (long fixture predates -4 semantics)
  wide_no_excluded <- dplyr::filter(
    wide,
    !(spawning %in% -4L | rearing %in% -4L)
  )

  wide_sorted <- dplyr::arrange(wide_no_excluded, blue_line_key, species_code)
  long_sorted <- dplyr::arrange(long, blue_line_key, species_code)

  # Compare ignoring integer-vs-double type difference on spawning/rearing
  # (wide reads as double due to blanks; long pivots to int)
  expect_equal(
    dplyr::mutate(
      wide_sorted,
      spawning = as.integer(spawning),
      rearing = as.integer(rearing)
    ),
    long_sorted
  )
})

test_that("wide-variant preserves -4 excluded value", {
  out <- crt_ingest("bcfp", "user_habitat_classification", wide_fixture())
  excluded <- dplyr::filter(out, blue_line_key == 356600333L)
  expect_equal(nrow(excluded), 1L)
  expect_equal(excluded$spawning, -4)
  expect_equal(excluded$rearing, -4)
})

test_that("unknown (source, file_name) pair throws with diagnostic", {
  expect_error(
    crt_ingest("bogus_source", "user_habitat_classification", wide_fixture()),
    "Unknown.*bogus_source"
  )
  expect_error(
    crt_ingest("bcfp", "bogus_file", wide_fixture()),
    "Unknown.*bogus_file"
  )
})

test_that("nonexistent file path throws with diagnostic", {
  expect_error(
    crt_ingest("bcfp", "user_habitat_classification", "/nonexistent/path.csv"),
    "File does not exist"
  )
})

test_that("input with unrecognized shape throws with diagnostic", {
  garbage <- tempfile(fileext = ".csv")
  on.exit(unlink(garbage), add = TRUE)
  writeLines(
    c("col_a,col_b,col_c", "1,2,3"),
    garbage
  )
  expect_error(
    crt_ingest("bcfp", "user_habitat_classification", garbage),
    "does not match any known upstream variant"
  )
})

test_that("non-string args throw chk validation errors", {
  expect_error(crt_ingest(1, "user_habitat_classification", wide_fixture()))
  expect_error(crt_ingest("bcfp", 1, wide_fixture()))
  expect_error(crt_ingest("bcfp", "user_habitat_classification", 1))
})
