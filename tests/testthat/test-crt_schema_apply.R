# crt_schema_apply() coerces handler output to the types declared in the
# schema YAML. Schema is the source of truth; handlers don't encode type
# knowledge.

test_that("crt_ingest enforces integer types declared in schema", {
  wide_path <- system.file(
    "extdata/examples/bcfp/user_habitat_classification_wide.csv",
    package = "crate"
  )
  out <- crt_ingest("bcfp", "user_habitat_classification", wide_path)
  # Schema declares blue_line_key, spawning, rearing as integer
  expect_true(is.integer(out$blue_line_key))
  expect_true(is.integer(out$spawning))
  expect_true(is.integer(out$rearing))
  # Schema declares downstream_route_measure, upstream_route_measure as double
  expect_true(is.double(out$downstream_route_measure))
  expect_true(is.double(out$upstream_route_measure))
  # Schema declares review_date as string (resists readr's Date parsing)
  expect_true(is.character(out$review_date))
})

test_that("crt_ingest enforces types on long-variant pivot output too", {
  long_path <- system.file(
    "extdata/examples/bcfp/user_habitat_classification_long.csv",
    package = "crate"
  )
  out <- crt_ingest("bcfp", "user_habitat_classification", long_path)
  expect_true(is.integer(out$blue_line_key))
  expect_true(is.integer(out$spawning))
  expect_true(is.integer(out$rearing))
})

test_that("crt_schema_apply is a no-op for schemas without canonical.cols", {
  df <- data.frame(a = 1:3, b = c("x", "y", "z"), stringsAsFactors = FALSE)
  out <- crt_schema_apply(df, list())
  expect_equal(out$a, 1:3)
  expect_equal(out$b, c("x", "y", "z"))
})

test_that("crt_schema_apply skips columns absent from the schema", {
  df <- data.frame(
    known = c(1.5, 2.5),
    extra = c("a", "b"),
    stringsAsFactors = FALSE
  )
  schema <- list(canonical = list(cols = list(
    list(name = "known", type = "integer")
  )))
  out <- crt_schema_apply(df, schema)
  expect_true(is.integer(out$known))
  expect_equal(out$extra, c("a", "b"))   # untouched
})

test_that("crt_schema_apply errors on unknown type declarations", {
  df <- data.frame(x = 1:3)
  schema <- list(canonical = list(cols = list(
    list(name = "x", type = "complex")
  )))
  expect_error(
    crt_schema_apply(df, schema),
    "Unknown canonical type"
  )
})

test_that("crt_schema_apply coerces logical and string", {
  df <- data.frame(flag = c(0L, 1L), label = c(2024L, 2025L))
  schema <- list(canonical = list(cols = list(
    list(name = "flag", type = "logical"),
    list(name = "label", type = "string")
  )))
  out <- crt_schema_apply(df, schema)
  expect_equal(out$flag, c(FALSE, TRUE))
  expect_equal(out$label, c("2024", "2025"))
})
