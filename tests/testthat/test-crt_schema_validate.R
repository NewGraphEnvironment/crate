# crt_schema_validate() checks required canonical cols are present in
# handler output. Runs in crt_ingest() before crt_schema_apply() so missing
# required cols fail loud rather than silently coerce to NA.

test_that("crt_schema_validate is silent when all required cols present", {
  schema <- list(canonical = list(cols = list(
    list(name = "a", type = "integer", required = TRUE),
    list(name = "b", type = "string", required = FALSE)
  )))
  df <- data.frame(a = 1:3, b = c("x", "y", "z"), stringsAsFactors = FALSE)
  result <- crt_schema_validate(df, schema)
  expect_null(result)
})

test_that("crt_schema_validate throws listing all missing required cols", {
  schema <- list(canonical = list(cols = list(
    list(name = "a", type = "integer", required = TRUE),
    list(name = "b", type = "integer", required = TRUE),
    list(name = "c", type = "string", required = FALSE)
  )))
  df <- data.frame(c = c("x", "y", "z"), stringsAsFactors = FALSE)
  expect_error(
    crt_schema_validate(df, schema),
    "Missing: a, b"
  )
})

test_that("crt_schema_validate skips required: false cols", {
  schema <- list(canonical = list(cols = list(
    list(name = "a", type = "integer", required = TRUE),
    list(name = "b", type = "string", required = FALSE)
  )))
  df <- data.frame(a = 1:3)   # b absent but optional
  expect_null(crt_schema_validate(df, schema))
})

test_that("crt_schema_validate skips cols without required key", {
  schema <- list(canonical = list(cols = list(
    list(name = "a", type = "integer"),                        # no required key
    list(name = "b", type = "string", required = TRUE)
  )))
  df <- data.frame(b = c("x", "y"), stringsAsFactors = FALSE)  # a absent, no req key → skip
  expect_null(crt_schema_validate(df, schema))
})

test_that("crt_schema_validate is no-op for schemas without canonical.cols", {
  expect_null(crt_schema_validate(data.frame(x = 1), list()))
})

test_that("crt_schema_validate runs end-to-end via crt_ingest (success path)", {
  wide_path <- system.file(
    "extdata/examples/bcfp/user_habitat_classification_wide.csv",
    package = "crate"
  )
  expect_no_error(
    crt_ingest("bcfp", "user_habitat_classification", wide_path)
  )
})
