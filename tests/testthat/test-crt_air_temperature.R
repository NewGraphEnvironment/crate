# The nge/air_temperature/fwa/v1/* datasets wet publishes (crate#81).
#
# The registry-integrity guards already walk every schema; this file covers what
# is specific to these: the types a part is written with, and that the Hive
# keys in the path are not declared as columns.

test_that("a segment_cell part conforms, with a missing cell kept as NA", {
  x <- data.frame(
    linear_feature_id = c(701234.0, 701235.0), watershed_group_code = "BULK",
    cell_id = c(1283934, NA), cell_x = c(-126.6, NA), cell_y = c(54.4, NA),
    cell_status = c("own", "outside"), point_x = c(-126.61, -139.9), point_y = c(54.43, 60.1),
    segment_elev_m = c(512.3, 20.1), stringsAsFactors = FALSE
  )
  out <- crt_schema_conform(x, "nge", "air_temperature/fwa/v1/segment_cell")
  expect_type(out$linear_feature_id, "integer")
  expect_type(out$cell_id, "integer")
  expect_identical(out$cell_id, c(1283934L, NA))
  expect_type(out$cell_status, "character")
  expect_type(out$segment_elev_m, "double")
  x$cell_status <- NULL
  expect_error(crt_schema_conform(x, "nge", "air_temperature/fwa/v1/segment_cell"), "cell_status")
})

test_that("a cell_daily part conforms, its day a Date", {
  x <- data.frame(cell_id = c(1283934, 1283934), date = c("2025-01-01", "2025-01-02"),
                  tmean_c = c(-8.25, -7.5), tmax_c = c(-4, -3.5), tmin_c = c(-12, -11))
  out <- crt_schema_conform(x, "nge", "air_temperature/fwa/v1/cell_daily")
  expect_type(out$cell_id, "integer")
  expect_s3_class(out$date, "Date")
  expect_identical(format(out$date), c("2025-01-01", "2025-01-02"))
  expect_type(out$tmean_c, "double")
  x$tmin_c <- NULL
  expect_error(crt_schema_conform(x, "nge", "air_temperature/fwa/v1/cell_daily"), "tmin_c")
})

test_that("the Hive keys are not declared as columns", {
  for (f in c("air_temperature/fwa/v1/segment_cell", "air_temperature/fwa/v1/cell_daily")) {
    entry <- crate:::crt_registry_entry("nge", f)
    cols <- vapply(crt_schema_read(entry$schema_yaml)$canonical$cols, `[[`, character(1), "name")
    expect_length(intersect(cols, c("scenario", "forcing", "source")), 0L)
  }
})
