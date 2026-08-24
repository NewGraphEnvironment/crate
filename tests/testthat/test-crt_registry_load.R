# crt_registry_load() reads inst/extdata/crate_registry.csv and returns it
# as a tibble. Single source of truth for crt_files() (public listing) and
# crt_ingest() (lookup-then-dispatch).

test_that("crt_registry_load returns tibble with expected columns", {
  reg <- crt_registry_load()
  expect_s3_class(reg, "tbl_df")
  expected_cols <- c(
    "source", "file_name", "kind", "handler_fn", "schema_yaml", "canonical_cols"
  )
  expect_equal(names(reg), expected_cols)
})

test_that("crt_registry_load returns non-empty registry", {
  reg <- crt_registry_load()
  expect_gte(nrow(reg), 1L)
})

test_that("crt_registry_load includes the bcfp/user_habitat_classification entry", {
  reg <- crt_registry_load()
  bcfp_uhc <- reg[reg$source == "bcfp" & reg$file_name == "user_habitat_classification", ]
  expect_equal(nrow(bcfp_uhc), 1L)
  expect_equal(bcfp_uhc$handler_fn, "crt_handler_bcfp_user_habitat_classification")
  expect_equal(bcfp_uhc$schema_yaml, "schemas/bcfp/user_habitat_classification.yaml")
})

test_that("crt_registry_load reads all cols as character (no auto-type coercion)", {
  reg <- crt_registry_load()
  for (col in names(reg)) {
    expect_true(is.character(reg[[col]]), info = paste("col:", col))
  }
})
