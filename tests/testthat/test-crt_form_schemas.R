# The five registered fish passage form schemas (#13), tested against the
# column sets their known versions actually have.
#
# Every frame here is built from a fixture of a real capture shape -- name and
# declared type, as the GeoPackage stores them -- so a property is checked on
# the columns a harvest will meet, not on a toy.

forms <- c("form_pscis", "form_fiss_site", "form_monitoring_fish_passage",
           "form_monitoring_general", "form_monitoring")

fixture_types <- function(form, variant) {
  x <- utils::read.csv(
    testthat::test_path("fixtures", "forms", paste0(form, "__", variant, ".csv")),
    colClasses = "character"
  )
  stats::setNames(x$type, x$name)
}

# A capture as trp_form_read() hands it to crate: the envelope, the position,
# and every capture column filled with a value of its declared type.
capture <- function(form, variant, n = 2, x = rep(1203451, n)) {
  types <- fixture_types(form, variant)
  fill <- function(t) {
    switch(
      t,
      TEXT = rep("text", n), REAL = rep(1.5, n),
      INTEGER = , MEDIUMINT = rep(1L, n),
      DATETIME = rep("2026-09-21T18:00:00Z", n),
      BOOLEAN = rep(TRUE, n),
      stop("no fill for ", t)
    )
  }
  cols <- lapply(types, fill)
  env <- data.frame(
    project = "example_2026", form = form, record_id = seq_len(n),
    source_version = "v1", schema_version = crt_schema_fingerprint(types),
    captured_at = "2026-09-21T18:00:00Z",
    x = x, y = rep(1012345, n), source_epsg = 3005L,
    stringsAsFactors = FALSE
  )
  cbind(env, as.data.frame(cols, stringsAsFactors = FALSE, optional = TRUE))
}

variants_of <- function(form) {
  crt_schema_get("nge", form)$upstream_variants
}

test_that("all five forms are registered", {
  expect_true(all(forms %in% crt_files("nge")$file_name))
})

test_that("every listed fingerprint is recomputed from its variant's columns", {
  # The fingerprints in the YAML are strings; without this they would be
  # trusted rather than checked. Each listed variant must have a fixture, and
  # each fixture must belong to a listed variant.
  dir <- testthat::test_path("fixtures", "forms")
  seen <- character(0)
  for (form in forms) {
    for (v in variants_of(form)) {
      expect_false(is.null(v$fingerprint), info = paste(form, v$id))
      expect_identical(
        crt_schema_fingerprint(fixture_types(form, v$id)), v$fingerprint,
        info = paste(form, v$id)
      )
      seen <- c(seen, paste0(form, "__", v$id, ".csv"))
    }
  }
  expect_setequal(list.files(dir, pattern = "^form_.*__.*[.]csv$"), seen)
})

test_that("every capture column of each build is declared by its schema", {
  for (form in forms) {
    v <- variants_of(form)[[1]]
    declared <- crt_schema_cols("nge", form)$name
    expect_identical(
      setdiff(names(fixture_types(form, v$id)), declared), character(0),
      info = form
    )
  }
})

test_that("a capture of each build conforms and names its version", {
  for (form in forms) {
    v <- variants_of(form)[[1]]
    expect_no_warning(out <- crt_schema_conform(capture(form, v$id), "nge", form))
    expect_identical(crt_schema_variant(out, "nge", form), rep(v$id, 2), info = form)
  }
})

test_that("the two monitoring shapes conform to one table, told apart by schema_version", {
  # They rename rather than nest: each has columns the other lacks. That is the
  # case #14's subset measurement did not cover.
  build <- fixture_types("form_monitoring", "rfp-build-2026-08")
  alt <- fixture_types("form_monitoring", "capture-utm-columns-2025")
  expect_true(length(setdiff(names(build), names(alt))) > 0)
  expect_true(length(setdiff(names(alt), names(build))) > 0)

  a <- crt_schema_conform(capture("form_monitoring", "rfp-build-2026-08"), "nge", "form_monitoring")
  b <- crt_schema_conform(capture("form_monitoring", "capture-utm-columns-2025"), "nge", "form_monitoring")
  both <- dplyr::bind_rows(a, b)

  expect_identical(nrow(both), 4L)
  expect_identical(length(unique(both$schema_version)), 2L)
  expect_identical(
    crt_schema_variant(both, "nge", "form_monitoring"),
    rep(c("rfp-build-2026-08", "capture-utm-columns-2025"), each = 2)
  )
  # A column only one shape has is NA in the other, and schema_version says why.
  expect_true(all(is.na(both$surveyor_1[3:4])))
  expect_true(all(is.na(both$easting[1:2])))
  # Shared columns come back the same type from both, or the stack would fail.
  expect_type(both$easting, "double")
})

test_that("the 2025 monitoring shape validates and is excluded by crew_attributed", {
  alt <- crt_schema_conform(
    capture("form_monitoring", "capture-utm-columns-2025", x = c(1203451, NA)),
    "nge", "form_monitoring"
  )
  build <- crt_schema_conform(
    capture("form_monitoring", "rfp-build-2026-08", x = c(1203451, NA)),
    "nge", "form_monitoring"
  )
  g_alt <- crt_schema_grade(alt, "nge", "form_monitoring")
  g_build <- crt_schema_grade(build, "nge", "form_monitoring")

  # Harvestable turns on position alone: the row with no fix fails in both.
  expect_identical(g_alt$harvestable, c(TRUE, FALSE))
  expect_identical(g_build$harvestable, c(TRUE, FALSE))
  # Crew attribution needs surveyor_1, which only the build has.
  expect_identical(g_alt$crew_attributed, c(FALSE, FALSE))
  expect_identical(g_build$crew_attributed, c(TRUE, FALSE))
})

test_that("a registered form reports a fingerprint it does not list", {
  x <- capture("form_pscis", "rfp-build-2026-08")
  x$schema_version[2] <- "98-0123456789abcdef"
  expect_warning(
    out <- crt_schema_conform(x, "nge", "form_pscis"),
    class = "crate_unknown_fingerprint"
  )
  expect_identical(
    crt_schema_variant(out, "nge", "form_pscis"),
    c("rfp-build-2026-08", NA)
  )
})

test_that("allowed values let a QC rule flag a near-miss and a label stored as a code", {
  # The check itself is #38's; this shows the declaration is enough to write it.
  flag <- function(x, allowed) !is.na(x) & !x %in% allowed

  pscis <- crt_schema_cols("nge", "form_pscis")
  embedded <- pscis$values[[which(pscis$name == "continuous_embeddedment_yes_no")]]
  expect_identical(embedded, c("Yes", "No"))
  expect_identical(flag(c("Yes", "yes", NA), embedded), c(FALSE, TRUE, FALSE))

  mon <- crt_schema_cols("nge", "form_monitoring")
  i <- which(mon$name == "crossing_type")
  expect_identical(mon$values[[i]], c("CBS", "OBS", "OTHER"))
  expect_identical(mon$labels[[i]][1], "Closed Bottom Structure")
  # A reader that wrote the label where the code belongs is caught.
  expect_identical(
    flag(c("CBS", "Closed Bottom Structure"), mon$values[[i]]),
    c(FALSE, TRUE)
  )
})

test_that("a text dropdown declared real upstream is a string here", {
  # fiss_site's method columns were declared `real` by the form builder while
  # their choices are text; typed as double, every value would become NA.
  cols <- crt_schema_cols("nge", "form_fiss_site")
  m <- cols[cols$name == "method_for_temperature", ]
  expect_identical(m$type, "string")
  expect_true("Hydrolab" %in% m$values[[1]])

  x <- capture("form_fiss_site", "rfp-build-2026-08", n = 1)
  x$method_for_temperature <- "Hydrolab"
  out <- crt_schema_conform(x, "nge", "form_fiss_site")
  expect_identical(out$method_for_temperature, "Hydrolab")
})

test_that("units, photo paths and off-form nulls are declared where the forms carry them", {
  fiss <- crt_schema_cols("nge", "form_fiss_site")
  expect_identical(fiss$units[fiss$name == "wetted_width_m"], "m")
  # mS/cm, not centimetres: the suffix rule that would read `_cm` runs after it.
  expect_identical(fiss$units[fiss$name == "conductivity_m_s_cm"], "mS/cm")
  # A scale in parentheses is not a unit.
  pscis <- crt_schema_cols("nge", "form_pscis")
  expect_true(all(is.na(pscis$units[grepl("scale", pscis$notes)])))
  expect_true(any(!is.na(pscis$relative_to)))
  expect_true(any(!is.na(pscis$null)))
})
