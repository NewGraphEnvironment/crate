# The bcfp fixture is the only registered file, so it doubles as the proof that
# crt_ingest() and crt_schema_conform() cannot disagree -- they are one path.

fixture_wide <- function() {
  readr::read_csv(
    system.file(
      "extdata/examples/bcfp/user_habitat_classification_wide.csv",
      package = "crate"
    ),
    show_col_types = FALSE
  )
}

test_that("conform applies canonical types", {
  raw <- fixture_wide()
  out <- crt_schema_conform(raw, "bcfp", "user_habitat_classification")

  expect_s3_class(out, "tbl_df")
  expect_true(is.integer(out$blue_line_key))
  expect_true(is.double(out$downstream_route_measure))
  expect_true(is.character(out$watershed_group_code))
})

test_that("conform and ingest return identical output for the same file", {
  path <- system.file(
    "extdata/examples/bcfp/user_habitat_classification_wide.csv",
    package = "crate"
  )
  via_ingest <- crt_ingest("bcfp", "user_habitat_classification", path)
  via_conform <- crt_schema_conform(fixture_wide(), "bcfp", "user_habitat_classification")

  # The wide variant's handler is an identity passthrough, so any difference
  # here is validation or typing drifting between the two entry points.
  expect_identical(via_conform, via_ingest)
})

test_that("conform fails loud on a missing required column", {
  raw <- fixture_wide()
  raw$species_code <- NULL
  expect_error(
    crt_schema_conform(raw, "bcfp", "user_habitat_classification"),
    "required canonical columns missing"
  )
})

test_that("conform rejects an unknown registry pair", {
  expect_error(
    crt_schema_conform(fixture_wide(), "nope", "nothing"),
    "Unknown \\(source, file_name\\) pair"
  )
})

test_that("conform rejects a non-data-frame", {
  expect_error(
    crt_schema_conform(1:3, "bcfp", "user_habitat_classification"),
    "must be a data frame"
  )
})

test_that("columns the schema does not declare pass through untouched", {
  raw <- fixture_wide()
  raw$extra_col <- "kept"
  out <- crt_schema_conform(raw, "bcfp", "user_habitat_classification")
  expect_true("extra_col" %in% names(out))
  expect_identical(out$extra_col, raw$extra_col)
})
