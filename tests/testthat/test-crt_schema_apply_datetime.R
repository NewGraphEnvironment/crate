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

# --- regressions in the character branch ------------------------------------
#
# All three of these were silent: the suite was green with them present, and
# each moved a real instant rather than erroring.

test_that("mixed precision does not truncate the whole column", {
  # as.POSIXct.character infers ONE format for the vector by finding the first
  # that parses every element, and strptime ignores trailing characters -- so
  # a single date-only value used to force "%Y-%m-%d" onto the lot and every
  # timestamp lost its time of day.
  out <- crt_schema_apply(
    data.frame(t = c("2026-08-15 18:33:46", "2026-08-15 18:34:20", "2026-08-16")),
    schema_dt
  )
  expect_identical(
    format(out$t, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    c("2026-08-15T18:33:46Z", "2026-08-15T18:34:20Z", "2026-08-16T00:00:00Z")
  )
})

test_that("a minute-precision value does not truncate the seconds of its neighbours", {
  out <- crt_schema_apply(
    data.frame(t = c("2026-08-15 18:33", "2026-08-15 18:33:46")),
    schema_dt
  )
  expect_identical(
    format(out$t, "%H:%M:%S", tz = "UTC"),
    c("18:33:00", "18:33:46")
  )
})

test_that("fractional seconds survive", {
  out <- crt_schema_apply(data.frame(t = "2026-08-15T18:33:46.536Z"), schema_dt)
  expect_equal(as.numeric(out$t), 1786818826.536, tolerance = 1e-3)
})

test_that("a two-digit offset is refused like a four-digit one", {
  # Valid ISO 8601, and what Postgres emits for a whole-hour zone. The regex
  # used to require four offset digits, so +02 fell through, was stripped as
  # trailing junk, and the instant moved two hours with nothing reported.
  expect_error(
    crt_schema_apply(data.frame(t = "2026-08-15 18:33:46+02"), schema_dt),
    "non-UTC offset"
  )
  expect_error(
    crt_schema_apply(data.frame(t = "2026-08-15T18:33:46-07"), schema_dt),
    "non-UTC offset"
  )
})

test_that("an explicit zero offset is accepted in every spelling", {
  for (v in c("2026-08-15 18:33:46+00", "2026-08-15 18:33:46+00:00",
              "2026-08-15T18:33:46-0000")) {
    out <- crt_schema_apply(data.frame(t = v), schema_dt)
    expect_identical(as.numeric(out$t), 1786818826, info = v)
  }
})

test_that("a plain date is not mistaken for an offset", {
  # "2026-08-15" ends in "-15", which a naive offset regex reads as a -15 hour
  # zone and refuses.
  out <- crt_schema_apply(data.frame(t = "2026-08-15"), schema_dt)
  expect_identical(format(out$t, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                   "2026-08-15T00:00:00Z")
})

test_that("the unparseable error names the value that actually failed", {
  # The whole vector used to be replaced with NA on the first throw, so the
  # message pointed at element one -- usually a perfectly good timestamp.
  expect_error(
    crt_schema_apply(
      data.frame(t = c("2026-08-15 18:33:46", "not a time")), schema_dt
    ),
    "not a time"
  )
})

test_that("trailing junk after a valid timestamp is refused, not ignored", {
  expect_error(
    crt_schema_apply(data.frame(t = "2026-08-15 18:33:46 and then some"), schema_dt),
    "not parseable"
  )
})

test_that("NA and empty strings survive a mixed column", {
  out <- crt_schema_apply(
    data.frame(t = c("2026-08-15 18:33:46", NA, "")), schema_dt
  )
  expect_identical(as.numeric(out$t[[1]]), 1786818826)
  expect_true(is.na(out$t[[2]]))
  expect_true(is.na(out$t[[3]]))
})

test_that("a length-zero character column yields a length-zero datetime", {
  out <- crt_schema_apply(data.frame(t = character(0)), schema_dt)
  expect_s3_class(out$t, "POSIXct")
  expect_length(out$t, 0L)
})
