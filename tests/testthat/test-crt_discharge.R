# The nge/discharge/fwa/v1/* datasets wet publishes (crate#31).
#
# The registry-integrity guards already walk every schema; this file covers what
# is specific to these: the types a published part is written with, and that
# the Hive keys in the path are not declared as columns.

segment <- function() {
  data.frame(
    linear_feature_id = c(701234.0, 701234.0),
    watershed_group_code = c("BULK", "BULK"),
    month = c(0, 1),
    runoff_mm = c(512.3, NA),
    q_m3s = c(3.1, 0.8),
    coverage = c(NA, NA),
    period = c("1951-2012", "1951-2012"),
    pick = c(TRUE, TRUE),
    stringsAsFactors = FALSE
  )
}

test_that("a segment part conforms to its declared types", {
  out <- crt_schema_conform(segment(), "nge", "discharge/fwa/v1/segment_monthly")
  expect_type(out$linear_feature_id, "integer")
  expect_type(out$month, "integer")
  expect_type(out$runoff_mm, "double")
  expect_type(out$coverage, "double")
  expect_type(out$period, "character")
  expect_type(out$pick, "logical")
})

test_that("a segment part missing pick is refused", {
  x <- segment()
  x$pick <- NULL
  expect_error(
    crt_schema_conform(x, "nge", "discharge/fwa/v1/segment_monthly"),
    "pick"
  )
})

test_that("a watershed part conforms", {
  x <- data.frame(
    watershed_feature_id = 1234.0, watershed_group_code = "SALR", month = 0,
    runoff_mm = 400, q_m3s = 2, coverage = 1, bc_fraction = 1, period = "1981-2010"
  )
  out <- crt_schema_conform(x, "nge", "discharge/fwa/v1/watershed_monthly")
  expect_type(out$watershed_feature_id, "integer")
  expect_type(out$period, "character")
})

test_that("the Hive keys are not declared as columns", {
  # They live in the path; declaring them would make every written part carry a
  # second copy that can disagree with the directory it sits in.
  for (f in c("discharge/fwa/v1/segment_monthly", "discharge/fwa/v1/watershed_monthly")) {
    entry <- crate:::crt_registry_entry("nge", f)
    cols <- vapply(crt_schema_read(entry$schema_yaml)$canonical$cols, `[[`, character(1), "name")
    expect_length(intersect(cols, c("scenario", "forcing", "source")), 0L)
  }
})
