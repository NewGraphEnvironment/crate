# The whole point of the datetime type is that it never moves an instant. These
# assertions are therefore on the epoch (as.numeric), never on the rendering --
# and they run under a non-UTC TZ, because under TZ=UTC a converting
# implementation and a stamping one produce identical output and the test
# proves nothing.

withr::local_timezone("America/Vancouver")

schema_dt <- list(canonical = list(cols = list(
  list(name = "t", type = "datetime", required = TRUE)
)))

test_that("a POSIXct with an empty tzone is stamped, not shifted", {
  # This is exactly what sf returns for a GeoPackage DATETIME: the right
  # instant, carrying no label, so R renders it in the session zone.
  epoch <- 1786818826
  x <- as.POSIXct(epoch, origin = "1970-01-01", tz = "UTC")
  attr(x, "tzone") <- ""
  expect_identical(attr(x, "tzone"), "")

  out <- crt_schema_apply(data.frame(t = x), schema_dt)

  expect_identical(as.numeric(out$t), as.numeric(epoch))
  expect_identical(attr(out$t, "tzone"), "UTC")
  expect_identical(format(out$t, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                   "2026-08-15T18:33:46Z")
})

test_that("a POSIXct already labelled in another zone keeps its instant", {
  x <- as.POSIXct("2026-08-15 11:33:46", tz = "America/Vancouver")
  out <- crt_schema_apply(data.frame(t = x), schema_dt)
  expect_identical(as.numeric(out$t), as.numeric(x))
  expect_identical(attr(out$t, "tzone"), "UTC")
})

test_that("numeric is read as epoch seconds", {
  out <- crt_schema_apply(data.frame(t = 1786818826), schema_dt)
  expect_s3_class(out$t, "POSIXct")
  expect_identical(as.numeric(out$t), 1786818826)
})

test_that("a Date lands on UTC midnight, not local midnight", {
  # as.POSIXct.Date ignores tz= and converts in the system zone. West of UTC
  # the naive call yields the previous day at 17:00Z, which is the bug this
  # asserts against rather than around.
  out <- crt_schema_apply(data.frame(t = as.Date("2026-08-15")), schema_dt)
  expect_identical(format(out$t, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                   "2026-08-15T00:00:00Z")
})

test_that("ISO 8601 character parses, with or without T and Z", {
  out <- crt_schema_apply(
    data.frame(t = c("2026-08-15T18:33:46Z", "2026-08-15 18:33:46")),
    schema_dt
  )
  expect_identical(as.numeric(out$t[[1]]), as.numeric(out$t[[2]]))
  expect_identical(format(out$t[[1]], "%H:%M:%S", tz = "UTC"), "18:33:46")
})

test_that("a non-UTC offset is refused rather than silently dropped", {
  expect_error(
    crt_schema_apply(data.frame(t = "2026-08-15T18:33:46+02:00"), schema_dt),
    "non-UTC offset"
  )
})

test_that("unparseable character fails loud", {
  expect_error(
    crt_schema_apply(data.frame(t = "not a time"), schema_dt),
    "not parseable as ISO 8601"
  )
})

test_that("NA survives without inventing an instant", {
  out <- crt_schema_apply(
    data.frame(t = as.POSIXct(c(NA_real_, 1786818826), origin = "1970-01-01", tz = "UTC")),
    schema_dt
  )
  expect_true(is.na(out$t[[1]]))
  expect_identical(as.numeric(out$t[[2]]), 1786818826)
})

test_that("an all-NA column reads as an empty datetime column", {
  out <- crt_schema_apply(data.frame(t = NA), schema_dt)
  expect_s3_class(out$t, "POSIXct")
  expect_true(all(is.na(out$t)))
})

test_that("an unsupported class fails loud rather than guessing", {
  expect_error(
    crt_schema_apply(data.frame(t = I(list(1))), schema_dt),
    "Cannot read"
  )
})

test_that("an unknown declared type still names the supported set", {
  bad <- list(canonical = list(cols = list(list(name = "t", type = "instant"))))
  expect_error(
    crt_schema_apply(data.frame(t = 1), bad),
    "Supported types: integer, double, string, logical, datetime"
  )
})
