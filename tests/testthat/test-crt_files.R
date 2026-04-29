test_that("crt_files() returns registry tibble with expected columns", {
  out <- crt_files()
  expect_s3_class(out, "tbl_df")
  expected_cols <- c(
    "source", "file_name", "handler_fn", "schema_yaml", "canonical_cols"
  )
  expect_equal(names(out), expected_cols)
  expect_gte(nrow(out), 1L)
})

test_that("crt_files() includes the bcfp/user_habitat_classification entry", {
  out <- crt_files()
  bcfp_uhc <- out[out$source == "bcfp" & out$file_name == "user_habitat_classification", ]
  expect_equal(nrow(bcfp_uhc), 1L)
  expect_equal(bcfp_uhc$handler_fn, "crt_handler_bcfp_user_habitat_classification")
  expect_equal(bcfp_uhc$schema_yaml, "schemas/bcfp/user_habitat_classification.yaml")
})

test_that("crt_files(source = 'bcfp') filters correctly", {
  out <- crt_files(source = "bcfp")
  expect_true(all(out$source == "bcfp"))
  expect_gte(nrow(out), 1L)
})

test_that("crt_files(source = '<bogus>') returns empty tibble (not error)", {
  out <- crt_files(source = "nonexistent_source")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})

test_that("crt_files() rejects non-string source arg", {
  expect_error(crt_files(source = 1))
  expect_error(crt_files(source = c("bcfp", "edna")))
})
