# The nge/form_capture envelope.
#
# The registry-integrity guards in test-crt_registry_integrity.R already walk
# every schema, so this file covers only what is specific to this entry: the
# floor-not-ceiling behaviour the whole design rests on, and the two-vintage
# case it exists to make possible.

envelope <- function(n = 2, ...) {
  base <- data.frame(
    project = rep("newgraph/example_2026", n),
    form = rep("form_vri_qa", n),
    record_id = seq_len(n),
    schema_version = rep("abc12345", n),
    captured_at = paste0("2026-07-2", seq_len(n), "T21:04:28Z"),
    stringsAsFactors = FALSE
  )
  extra <- list(...)
  if (length(extra)) base <- cbind(base, as.data.frame(extra, stringsAsFactors = FALSE))
  base
}

test_that("a form record conforms and its own columns pass through untouched", {
  # This is the property the whole envelope depends on: crate declares a floor,
  # so a form's columns ride along unvalidated until #13 defines them. If this
  # ever stops being true, the envelope stops being usable and every harvest
  # breaks at once.
  x <- envelope(2, obs_cover_type = c("treed", "shrub"), obs_dead_pct = c(10, 25))
  out <- crt_schema_conform(x, "nge", "form_capture")

  expect_true(all(c("obs_cover_type", "obs_dead_pct") %in% names(out)))
  expect_identical(out$obs_cover_type, c("treed", "shrub"))
  expect_identical(out$obs_dead_pct, c(10, 25))
})

test_that("captured_at is stamped to UTC, not converted", {
  # The failure this guards is silent and seven hours wide. A GeoPackage stores
  # `2026-07-21T21:04:28Z`; a reader that returns it with an empty timezone
  # attribute renders 14:04:28 on a UTC-7 machine, and writing what is rendered
  # moves the instant.
  #
  # Asserted as an epoch rather than as a formatted string, because a formatted
  # comparison would agree with a wrong answer whenever the test machine
  # happens to run in UTC.
  withr::local_timezone("America/Vancouver")
  out <- crt_schema_conform(envelope(1), "nge", "form_capture")

  expect_s3_class(out$captured_at, "POSIXct")
  expect_identical(attr(out$captured_at, "tzone"), "UTC")
  expect_identical(
    as.numeric(out$captured_at),
    as.numeric(as.POSIXct("2026-07-21 21:04:28", tz = "UTC"))
  )
})

test_that("two vintages of one form conform to the same envelope", {
  # The narrower vintage is missing a column the wider one has. Both must
  # conform, and the envelope columns must come back the same type from each --
  # otherwise stacking them produces a column that is character in one half and
  # integer in the other.
  narrow <- envelope(2, obs_cover_type = c("treed", "shrub"))
  wide <- envelope(2, obs_cover_type = c("treed", "treed"),
                   obs_confidence = c("high", "medium"))
  wide$schema_version <- "def67890"

  a <- crt_schema_conform(narrow, "nge", "form_capture")
  b <- crt_schema_conform(wide, "nge", "form_capture")

  cols <- c("project", "form", "record_id", "schema_version", "captured_at")
  expect_identical(
    lapply(a[cols], class),
    lapply(b[cols], class)
  )
  # The distinction has to actually be present, or this test compares a thing
  # with itself.
  expect_false(identical(a$schema_version[[1]], b$schema_version[[1]]))
  expect_false("obs_confidence" %in% names(a))
})

test_that("a record missing an envelope column is refused", {
  # Premise asserted alongside the property: this test is only meaningful while
  # schema_version is required. If a future edit makes it optional, this line
  # fails and names the real cause instead of blaming the code under test.
  schema <- yaml::read_yaml(system.file(
    "extdata/schemas/nge/form_capture.yaml", package = "crate"
  ))
  required <- vapply(schema$canonical$cols, function(col) isTRUE(col$required), logical(1))
  names(required) <- vapply(schema$canonical$cols, function(col) col$name, character(1))
  expect_true(required[["schema_version"]])

  x <- envelope(2)
  x$schema_version <- NULL
  expect_error(crt_schema_conform(x, "nge", "form_capture"), "schema_version")
})

test_that("harvested_at is declared forward-incompatible with a reason", {
  # A column deliberately not declared leaves no trace in the canonical set, so
  # the decision is invisible and gets re-proposed. This asserts the reason is
  # recorded where the next reader will find it.
  schema <- yaml::read_yaml(system.file(
    "extdata/schemas/nge/form_capture.yaml", package = "crate"
  ))
  declared <- vapply(schema$canonical$cols, function(col) col$name, character(1))
  expect_false("harvested_at" %in% declared)

  flagged <- unlist(lapply(schema$forward_compat, function(f) f$cols))
  expect_true("harvested_at" %in% flagged)
  note <- schema$forward_compat[[
    which(vapply(schema$forward_compat, function(f) "harvested_at" %in% f$cols, logical(1)))
  ]]$note
  expect_true(nzchar(note))
})
