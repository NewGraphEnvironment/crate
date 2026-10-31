test_that("crt_schema_read resolves bundled paths and parses YAML", {
  schema <- crt_schema_read("schemas/bcfp/user_habitat_classification.yaml")
  expect_type(schema, "list")
  expect_equal(schema$file, "user_habitat_classification")
  expect_equal(schema$canonical$shape, "wide")
  expect_true(length(schema$canonical$cols) > 0L)
  expect_true(length(schema$upstream_variants) > 0L)
})

test_that("crt_schema_read errors fail-loud on missing path", {
  expect_error(
    crt_schema_read("nonexistent/path.yaml"),
    "Schema YAML not bundled"
  )
})

test_that("crt_schema_read rejects non-string args", {
  expect_error(crt_schema_read(123))
  expect_error(crt_schema_read(NULL))
  expect_error(crt_schema_read(c("a", "b")))
})

test_that("crt_schema_read reads the whole schema whatever the session locale", {
  # The bcfp schema has non-ASCII text in its second variant. Read in a C
  # locale's encoding, the read stopped there and the variant was lost.
  full <- crt_schema_read("schemas/bcfp/user_habitat_classification.yaml")
  withr::local_locale(c(LC_CTYPE = "C"))
  expect_no_warning(c_read <- crt_schema_read("schemas/bcfp/user_habitat_classification.yaml"))
  expect_identical(length(c_read$upstream_variants), length(full$upstream_variants))
  expect_identical(c_read, full)
})
