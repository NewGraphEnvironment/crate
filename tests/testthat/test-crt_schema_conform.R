# The bcfp fixture is the only registered file, so it doubles as the proof that
# crt_ingest() and crt_schema_conform() cannot disagree -- they are one path.

fixture_wide <- function() {
  readr::read_csv(
    system.file(
      "extdata/examples/bcfp/user_habitat_classification_wide.csv",
      package = "crate"
    ),
    show_col_types = FALSE
  )
}

test_that("conform applies canonical types", {
  raw <- fixture_wide()
  out <- crt_schema_conform(raw, "bcfp", "user_habitat_classification")

  expect_s3_class(out, "tbl_df")
  expect_true(is.integer(out$blue_line_key))
  expect_true(is.double(out$downstream_route_measure))
  expect_true(is.character(out$watershed_group_code))
})

test_that("conform and ingest return identical output for the same file", {
  path <- system.file(
    "extdata/examples/bcfp/user_habitat_classification_wide.csv",
    package = "crate"
  )
  via_ingest <- crt_ingest("bcfp", "user_habitat_classification", path)
  via_conform <- crt_schema_conform(fixture_wide(), "bcfp", "user_habitat_classification")

  # The wide variant's handler is an identity passthrough, so any difference
  # here is validation or typing drifting between the two entry points.
  expect_identical(via_conform, via_ingest)
})

test_that("conform fails loud on a missing required column", {
  raw <- fixture_wide()
  raw$species_code <- NULL
  expect_error(
    crt_schema_conform(raw, "bcfp", "user_habitat_classification"),
    "required canonical columns missing"
  )
})

test_that("conform rejects an unknown registry pair", {
  expect_error(
    crt_schema_conform(fixture_wide(), "nope", "nothing"),
    "Unknown \\(source, file_name\\) pair"
  )
})

test_that("conform rejects a non-data-frame", {
  expect_error(
    crt_schema_conform(1:3, "bcfp", "user_habitat_classification"),
    "must be a data frame"
  )
})

test_that("columns the schema does not declare pass through untouched", {
  raw <- fixture_wide()
  raw$extra_col <- "kept"
  out <- crt_schema_conform(raw, "bcfp", "user_habitat_classification")
  expect_true("extra_col" %in% names(out))
  expect_identical(out$extra_col, raw$extra_col)
})

# The nge/track_* entries are the first schema_only registrations: crate says
# what the columns mean, the caller supplies the frame.

test_that("crt_ingest refuses a schema_only entry and points at conform", {
  path <- system.file(
    "extdata/examples/bcfp/user_habitat_classification_wide.csv",
    package = "crate"
  )
  expect_error(
    crt_ingest("nge", "track_sessions", path),
    "registered .*schema_only"
  )
  expect_error(
    crt_ingest("nge", "track_sessions", path),
    "crt_schema_conform"
  )
})

test_that("the schema_only check fires before the file is even looked at", {
  # A caller at the wrong entry point should be told so, not told their path is
  # wrong -- "file does not exist" would send them looking in the wrong place.
  expect_error(
    crt_ingest("nge", "track_vertices", "/no/such/file.csv"),
    "schema_only"
  )
})

test_that("a sessions frame conforms, with the timestamps landing in UTC", {
  withr::local_timezone("America/Vancouver")

  # An empty tzone is what a GeoPackage DATETIME read through sf returns.
  t_attr <- as.POSIXct(1786818827, origin = "1970-01-01", tz = "UTC")
  attr(t_attr, "tzone") <- ""

  sessions <- data.frame(
    project = "example/collection",
    session_id = 2,
    tracked_by = "example_user",
    time_start = t_attr,
    time_end = t_attr + 600,
    time_start_m = 1786818826,     # epoch seconds, as carried per vertex
    time_end_m = 1786819426,
    clock_delta_start_s = -1L,
    clock_delta_end_s = 0L,
    total_distance = 136.14,
    n_vertices = 67L
  )

  out <- crt_schema_conform(sessions, "nge", "track_sessions")

  for (col in c("time_start", "time_end", "time_start_m", "time_end_m")) {
    expect_s3_class(out[[col]], "POSIXct")
    expect_identical(attr(out[[col]], "tzone"), "UTC", info = col)
  }
  # The instant is untouched: stamping the attribute clock did not move it, and
  # the epoch column resolves to the same second.
  expect_identical(as.numeric(out$time_start), 1786818827)
  expect_identical(as.numeric(out$time_start_m), 1786818826)
  expect_true(is.double(out$clock_delta_start_s))
  expect_true(is.integer(out$n_vertices))
})

# A sessions frame in the shape the tracking plugin writes on its own: none of
# the four crew-supplied naming columns. The case that must keep conforming.
sessions_plugin_shape <- function() {
  data.frame(
    project = "example/collection",
    session_id = 2L,
    tracked_by = "example_user",
    time_start = 1786818827,
    time_end = 1786819427,
    time_start_m = 1786818826,
    time_end_m = 1786819426,
    clock_delta_start_s = -1,
    clock_delta_end_s = -1,
    total_distance = 136.14,
    n_vertices = 67L
  )
}

cols_naming <- c("track_name", "track_type", "track_description", "named_by")

test_that("the crew-supplied naming columns conform when present, typed as strings", {
  named <- sessions_plugin_shape()
  named$track_name <- "hodda main"
  named$track_type <- "stream survey"
  named$track_description <- NA
  named$named_by <- factor("example_user")

  out <- crt_schema_conform(named, "nge", "track_sessions")

  for (col in cols_naming) {
    expect_true(is.character(out[[col]]), info = col)
  }
  expect_identical(out$track_name, "hodda main")
  expect_identical(out$named_by, "example_user")
  expect_identical(out$track_description, NA_character_)
})

test_that("a plugin-shaped frame without the naming columns still conforms", {
  # Optional means absent is fine. crt_schema_conform() does not invent the
  # columns either -- a reader producing the canonical table supplies the NA.
  input <- sessions_plugin_shape()
  out <- crt_schema_conform(input, "nge", "track_sessions")
  expect_identical(names(out), names(input))
  expect_false(any(cols_naming %in% names(out)))
  expect_identical(nrow(out), 1L)
})

test_that("the naming columns are declared optional, and required would refuse the plugin shape", {
  schema <- crt_schema_read("schemas/nge/track_sessions.yaml")
  names_declared <- vapply(schema$canonical$cols, function(col) col$name, character(1))

  # The premise, asserted so a future flip to required: true fails here, naming
  # the cause, rather than in the behaviour test below blaming the validator.
  idx <- match(cols_naming, names_declared)
  expect_false(anyNA(idx))
  for (i in idx) {
    expect_false(isTRUE(schema$canonical$cols[[i]]$required),
                 info = schema$canonical$cols[[i]]$name)
  }

  expect_no_error(crt_schema_validate(sessions_plugin_shape(), schema))

  # Restore the bug: with one of the four required, the plugin's own layer
  # would be refused. That is the failure required: false exists to prevent.
  broken <- schema
  broken$canonical$cols[[idx[[1]]]]$required <- TRUE
  expect_error(
    crt_schema_validate(sessions_plugin_shape(), broken),
    "track_name"
  )
})

test_that("a vertices frame conforms, including the columns YAML would boolean", {
  vertices <- data.frame(
    project = "example/collection", session_id = 2L, vertex_seq = 1L,
    x = -124.6, y = 49.5, z = 31.2,
    time = 1786818826
  )
  out <- crt_schema_conform(vertices, "nge", "track_vertices")
  expect_true(is.double(out$y))
  expect_s3_class(out$time, "POSIXct")
  expect_identical(attr(out$time, "tzone"), "UTC")
})

test_that("an annotations frame conforms, and a missing fingerprint fails loud", {
  ann <- data.frame(
    project = "example/collection", session_id = 2L,
    time_start_m = 1786818826,
    track_name = "example", track_type = NA_character_,
    track_description = NA_character_
  )
  out <- crt_schema_conform(ann, "nge", "track_annotations")
  expect_s3_class(out$time_start_m, "POSIXct")

  ann$time_start_m <- NULL
  expect_error(
    crt_schema_conform(ann, "nge", "track_annotations"),
    "time_start_m"
  )
})

test_that("an annotations frame missing an override column is refused, not narrowed", {
  # The table is ours, so its shape is fixed: a writer that drops a column has
  # changed the contract, and the coalesce downstream would silently never fire.
  ann <- data.frame(
    project = "example/collection", session_id = 2L,
    time_start_m = 1786818826, track_name = "example"
  )
  expect_error(
    crt_schema_conform(ann, "nge", "track_annotations"),
    "track_type, track_description"
  )
})

test_that("every annotation override column has a captured twin of the same type", {
  # The read-time rule is coalesce(annotation, captured), keyed on the name. It
  # is only well-typed while every non-key annotation column exists in
  # track_sessions with the same type, so that invariant is asserted from the
  # two YAMLs rather than trusted. A column renamed in one file, retyped in one
  # file, or added to annotations without a captured counterpart all fail here.
  spec <- function(rel) {
    schema <- crt_schema_read(rel)
    stats::setNames(
      vapply(schema$canonical$cols, function(col) col$type, character(1)),
      vapply(schema$canonical$cols, function(col) col$name, character(1))
    )
  }
  captured <- spec("schemas/nge/track_sessions.yaml")
  annotated <- spec("schemas/nge/track_annotations.yaml")

  # The join key and the fingerprint share names with track_sessions too and
  # are not overrides; the YAML rule excludes them by name, and so does this.
  keys <- c("project", "session_id", "time_start_m")
  non_key <- setdiff(names(annotated), keys)
  # An override is a non-key column that shares a name; a non-key column that
  # does not (annotated_by, when it lands) is annotation-only, not drift. The
  # absolute set below is what makes a rename fail loudly rather than drop out
  # of the intersection unnoticed.
  overrides <- intersect(non_key, names(captured))

  expect_setequal(overrides, c("track_name", "track_type", "track_description"))
  expect_identical(annotated[overrides], captured[overrides])
  # Who corrected a session is annotated_by (reserved), not an override of
  # who named it at capture.
  expect_false("named_by" %in% overrides)
})
