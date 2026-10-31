# The keys a schema uses to say what a column means, and the three accessors
# that read them: crt_schema_cols(), crt_schema_grade() and
# crt_schema_variant(). Each is tested on an inline schema through its internal
# worker, so a property is pinned by a schema built to exercise it rather than
# by whatever a registered form happens to contain; the registered forms are
# covered in test-crt_form_schemas.R.

meaning_schema <- function() {
  list(
    file = "form_example",
    canonical = list(
      shape = "long",
      cols = list(
        list(name = "record_id", type = "integer", required = TRUE),
        list(name = "x", type = "double", required = TRUE),
        list(name = "y", type = "double", required = TRUE),
        list(name = "wetted_width_m", type = "double", required = FALSE,
             units = "m", range = list(0, 100), notes = "Wetted width."),
        list(name = "barrier_result", type = "string", required = FALSE,
             values = list("Passable", "Potential", "Barrier"),
             null = "Office field: null until scored after the visit."),
        list(name = "cover_class", type = "integer", required = FALSE,
             values = list(list(value = "1", label = "Ferns/Grasses"),
                           list(value = "4", label = "Coniferous Trees"))),
        list(name = "photo_road", type = "string", required = FALSE,
             relative_to = "project root"),
        list(name = "surveyor_1", type = "string", required = FALSE)
      )
    ),
    grades = list(
      list(name = "harvestable", requires = list("record_id", "x", "y")),
      list(name = "crew_attributed", requires = list("record_id", "x", "y", "surveyor_1"))
    ),
    upstream_variants = list(
      list(id = "build-a", fingerprint = "3-aaaaaaaaaaaaaaaa"),
      list(id = "capture-b", fingerprint = "2-bbbbbbbbbbbbbbbb"),
      list(id = "unfingerprinted")
    )
  )
}

# ---- crt_schema_cols -------------------------------------------------------

test_that("column declarations come back one row per column, in schema order", {
  out <- crt_schema_cols_tbl(meaning_schema())
  expect_s3_class(out, "tbl_df")
  expect_identical(
    out$name,
    c("record_id", "x", "y", "wetted_width_m", "barrier_result", "cover_class",
      "photo_road", "surveyor_1")
  )
  expect_identical(
    names(out),
    c("name", "type", "required", "units", "values", "labels", "range_min",
      "range_max", "relative_to", "null", "notes")
  )
  expect_identical(out$required[1:4], c(TRUE, TRUE, TRUE, FALSE))
})

test_that("an absent key reads as NA or an empty vector, never a guess", {
  out <- crt_schema_cols_tbl(meaning_schema())
  r <- out[out$name == "surveyor_1", ]
  expect_identical(r$units, NA_character_)
  expect_identical(r$values[[1]], character(0))
  expect_identical(r$range_min, NA_real_)
  expect_identical(r$null, NA_character_)
})

test_that("allowed values are the stored values, with labels alongside", {
  out <- crt_schema_cols_tbl(meaning_schema())
  plain <- out[out$name == "barrier_result", ]
  expect_identical(plain$values[[1]], c("Passable", "Potential", "Barrier"))
  # A plain vocabulary displays what it stores.
  expect_identical(plain$labels[[1]], plain$values[[1]])

  coded <- out[out$name == "cover_class", ]
  expect_identical(coded$values[[1]], c("1", "4"))
  expect_identical(coded$labels[[1]], c("Ferns/Grasses", "Coniferous Trees"))
})

test_that("units, range, relative_to and null come through", {
  out <- crt_schema_cols_tbl(meaning_schema())
  w <- out[out$name == "wetted_width_m", ]
  expect_identical(w$units, "m")
  expect_identical(c(w$range_min, w$range_max), c(0, 100))
  expect_identical(out$relative_to[out$name == "photo_road"], "project root")
  expect_match(out$null[out$name == "barrier_result"], "^Office field")
})

test_that("crt_schema_cols() resolves a registered entry", {
  out <- crt_schema_cols("nge", "form_capture")
  expect_true(all(c("project", "form", "record_id", "schema_version") %in% out$name))
  expect_error(crt_schema_cols("nge", "nope"), "Unknown")
})

# ---- crt_schema_grade ------------------------------------------------------

grade_rows <- function() {
  data.frame(
    record_id = 1:4,
    x = c(1, NA, 3, 4),
    y = c(1, 2, 3, 4),
    surveyor_1 = c("AI", "AI", NA, "MW"),
    stringsAsFactors = FALSE
  )
}

test_that("a row meets a grade only when every required value is present", {
  # The fixture has rows that fail each grade for a different reason, so a
  # predicate that answered TRUE everywhere -- or only checked column
  # presence -- fails here.
  g <- crt_schema_grade_eval(grade_rows(), meaning_schema())
  expect_identical(names(g), c("harvestable", "crew_attributed"))
  expect_identical(g$harvestable, c(TRUE, FALSE, TRUE, TRUE))
  expect_identical(g$crew_attributed, c(TRUE, FALSE, FALSE, TRUE))
})

test_that("a column the vintage never had fails the grade for every row", {
  narrow <- grade_rows()
  narrow$surveyor_1 <- NULL
  g <- crt_schema_grade_eval(narrow, meaning_schema())
  expect_identical(g$crew_attributed, rep(FALSE, 4))
  expect_identical(g$harvestable, c(TRUE, FALSE, TRUE, TRUE))
})

test_that("an empty frame gives zero-row logical grades", {
  g <- crt_schema_grade_eval(grade_rows()[0, ], meaning_schema())
  expect_identical(nrow(g), 0L)
  expect_type(g$harvestable, "logical")
})

test_that("a schema with no grades is an error, not an empty answer", {
  s <- meaning_schema()
  s$grades <- NULL
  expect_error(crt_schema_grade_eval(grade_rows(), s), "declares no grades")
})

# ---- crt_schema_variant ----------------------------------------------------

test_that("a fingerprint names its variant and an unknown one is NA", {
  out <- crt_schema_variant_match(
    c("3-aaaaaaaaaaaaaaaa", "2-bbbbbbbbbbbbbbbb", "9-cccccccccccccccc", NA),
    meaning_schema()
  )
  expect_identical(out, c("build-a", "capture-b", NA, NA))
})

test_that("a schema listing no fingerprints cannot name a variant", {
  s <- meaning_schema()
  s$upstream_variants <- list(list(id = "unfingerprinted"))
  expect_error(crt_schema_variant_match("3-aaaaaaaaaaaaaaaa", s), "no fingerprint")
})

test_that("conform reports an unknown fingerprint without failing", {
  df <- data.frame(record_id = 1:2, x = 1, y = 1,
                   schema_version = c("3-aaaaaaaaaaaaaaaa", "9-cccccccccccccccc"))
  expect_warning(
    out <- crt_schema_fingerprint_check(df, meaning_schema()),
    class = "crate_unknown_fingerprint"
  )
  expect_identical(out, df)
  expect_warning(
    crt_schema_fingerprint_check(df, meaning_schema()),
    "9-cccccccccccccccc"
  )
})

test_that("known fingerprints, and schemas listing none, pass quietly", {
  df <- data.frame(record_id = 1, schema_version = "3-aaaaaaaaaaaaaaaa")
  expect_no_warning(crt_schema_fingerprint_check(df, meaning_schema()))
  # form_capture lists no fingerprints, so every existing caller stays quiet.
  s <- meaning_schema()
  s$upstream_variants <- NULL
  df$schema_version <- "9-cccccccccccccccc"
  expect_no_warning(crt_schema_fingerprint_check(df, s))
  expect_no_warning(crt_schema_fingerprint_check(data.frame(a = 1), meaning_schema()))
})
