# The date type holds calendar days, not instants: it must never move a day,
# and must refuse what has no single day. Run under a zone west of UTC, where a
# conversion through midnight UTC would land on the previous day.

withr::local_timezone("America/Vancouver")

schema_d <- list(canonical = list(cols = list(
  list(name = "d", type = "date", required = TRUE)
)))

test_that("a Date passes through as the same day", {
  x <- as.Date(c("2025-01-01", "1950-12-31", NA))
  out <- crt_schema_apply(data.frame(d = x), schema_d)
  expect_identical(out$d, x)
  expect_identical(class(out$d), "Date")
})

test_that("a Date subclass on integer storage is rebuilt as a plain Date", {
  x <- structure(c(20089L, NA), class = c("IDate", "Date"))
  out <- crt_schema_apply(data.frame(d = I(x)), schema_d)
  expect_identical(class(out$d), "Date")
  expect_identical(format(out$d), c("2025-01-01", NA))
})

test_that("YYYY-MM-DD character is read as that day", {
  out <- crt_schema_apply(data.frame(d = c("2025-01-01", " 2024-02-29 ", NA, "")), schema_d)
  expect_identical(format(out$d), c("2025-01-01", "2024-02-29", NA, NA))
})

test_that("a character value that is not a real day is refused, naming it", {
  expect_error(crt_schema_apply(data.frame(d = c("2025-01-01", "2025-02-30")), schema_d),
               "2025-02-30")
  expect_error(crt_schema_apply(data.frame(d = "2025-01-01T00:00:00Z"), schema_d),
               "not a")
  expect_error(crt_schema_apply(data.frame(d = "01/02/2025"), schema_d), "01/02/2025")
})

test_that("a POSIXct and a number are refused", {
  t <- as.POSIXct("2025-01-01 00:00:00", tz = "UTC")
  expect_error(crt_schema_apply(data.frame(d = t), schema_d), "zone")
  expect_error(crt_schema_apply(data.frame(d = 20089), schema_d), "origin")
})

test_that("an all-NA column is an all-NA Date", {
  out <- crt_schema_apply(data.frame(d = c(NA, NA)), schema_d)
  expect_identical(class(out$d), "Date")
  expect_true(all(is.na(out$d)))
})

test_that("a date column fingerprints as its day", {
  a <- crt_schema_apply(data.frame(d = "2025-01-01"), schema_d)
  b <- data.frame(d = as.Date("2025-01-01"))
  expect_identical(crt_table_fingerprint(a), crt_table_fingerprint(b))
})
