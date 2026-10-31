# Direct tests for crt_handler_nge_fish_data and its file-local helpers.
#
# crt_ingest() reaches these through the registry; calling them directly covers
# the variant branching and the PIT tag extraction cases a fixture file cannot
# hold all of at once.

read_nge_fixture <- function(name) {
  readr::read_csv(
    system.file("extdata/examples/nge", name, package = "crate"),
    show_col_types = FALSE
  )
}

canonical_nge_fish <- function() {
  schema <- crt_schema_read("schemas/nge/fish_data.yaml")
  vapply(schema$canonical$cols, function(col) col$name, character(1))
}

test_that("each variant id returns every canonical column, in order", {
  cases <- list(
    "2023-peace-6col" = "fish_data_2023_peace.csv",
    "2023-skeena-7col" = "fish_data_2023_skeena.csv",
    "2024-field-sheet" = "fish_data_2024.csv"
  )
  for (id in names(cases)) {
    raw <- read_nge_fixture(cases[[id]])
    out <- crt_handler_nge_fish_data(raw, id)
    expect_s3_class(out, "tbl_df")
    expect_identical(names(out), canonical_nge_fish(), info = id)
    expect_identical(nrow(out), nrow(raw), info = id)
  }
})

test_that("an unknown variant id aborts", {
  raw <- read_nge_fixture("fish_data_2024.csv")
  expect_error(
    crt_handler_nge_fish_data(raw, "1999-nope"),
    "Unknown variant_id for nge/fish_data"
  )
})

test_that("2023 names map onto the canonical ones", {
  out <- crt_handler_nge_fish_data(
    read_nge_fixture("fish_data_2023_skeena.csv"), "2023-skeena-7col"
  )
  expect_identical(out$species[[2]], "Cutthroat Trout")
  expect_identical(as.integer(out$haul_number_pass_number), c(1L, 1L, 2L))
  expect_identical(as.double(out$length_mm), c(108, 87, 49))
  # A 2023 file carries no effort or date columns: present and null.
  expect_true(all(is.na(out$date)))
  expect_true(all(is.na(out$sampling_method)))
})

test_that("2024 names map onto the canonical ones, and the day is ISO", {
  out <- crt_handler_nge_fish_data(
    read_nge_fixture("fish_data_2024.csv"), "2024-field-sheet"
  )
  expect_identical(as.double(out$length_mm[1:2]), c(201, 62))
  expect_identical(as.double(out$weight_g[[1]]), 92.4)
  expect_identical(as.integer(out$haul_number_pass_number), rep(1L, 4))
  expect_identical(out$pit_tag_id[[1]], "3DD.003E190001")
})

test_that("a 2024 tag typed in lower case is stored upper case", {
  raw <- read_nge_fixture("fish_data_2024.csv")
  raw$pit_tag_id[[1]] <- "3dd.003e190001"
  out <- crt_handler_nge_fish_data(raw, "2024-field-sheet")
  expect_identical(out$pit_tag_id[[1]], "3DD.003E190001")
  expect_true(all(is.na(out$pit_tag_id[2:4])))
  expect_identical(out$date, c("2024-09-06", "2024-09-06", "2024-09-07", "2024-09-07"))
  expect_true(all(is.na(out$reference_number)))
})

test_that("the day is read from a midnight stamp, a Date or ISO text", {
  x <- as.POSIXct(c("2024-09-06", "2024-09-07", NA), tz = "UTC")
  expect_identical(crt_handler_nge_fish_day(x), c("2024-09-06", "2024-09-07", NA))
  expect_identical(crt_handler_nge_fish_day(as.Date("2024-09-06")), "2024-09-06")
  expect_identical(
    crt_handler_nge_fish_day(c("2024-09-06", "2024-09-07T00:00:00Z", NA)),
    c("2024-09-06", "2024-09-07", NA)
  )
})

test_that("a date carrying a time of day aborts rather than losing it", {
  x <- as.POSIXct(c("2024-09-06 00:00:00", "2024-09-06 23:30:00"), tz = "UTC")
  expect_error(crt_handler_nge_fish_day(x), "time of day")
  expect_error(crt_handler_nge_fish_day("2024-09-06T10:00:00Z"), "not a day")
  expect_error(crt_handler_nge_fish_day("6/9/2024"), "not a day")
})

test_that("a 2023 PIT tag is read out of comments, and comments are kept", {
  raw <- read_nge_fixture("fish_data_2023_peace.csv")
  out <- crt_handler_nge_fish_data(raw, "2023-peace-6col")
  expect_identical(
    out$pit_tag_id,
    c(NA, "3DD.003E190001", "3DD.003E190002", NA)
  )
  expect_identical(out$comments, as.character(raw$comments))
})

test_that("tag extraction: one code, none, malformed, ambiguous, NA", {
  comments <- c(
    "3DD.003E192B88. AI photo 12:26:14", # code followed by more text
    "3DD.003E192B98", # code alone
    "3dd.003e192b98", # written lower case: still a full code
    "3DD.003E192B9I photo bute", # malformed: not a full code
    "3DD.003E192B88A", # eleven hex digits: not a code
    "03DD.003E192B88", # a hex digit before 3DD: inside a longer run, not a code
    "3DD.003E192B88 3DD.003E192B99", # two different codes: ambiguous
    "3DD.003E192B88 again 3DD.003E192B88", # one code twice
    "no tag",
    "",
    NA
  )
  expect_identical(
    crt_handler_nge_fish_pit_tag(comments),
    c(
      "3DD.003E192B88", "3DD.003E192B98", "3DD.003E192B98", NA, NA, NA, NA,
      "3DD.003E192B88", NA, NA, NA
    )
  )
})

test_that("an all-blank comments column, read as logical, yields no tags", {
  raw <- read_nge_fixture("fish_data_2023_peace.csv")
  raw$comments <- NA
  out <- crt_handler_nge_fish_data(raw, "2023-peace-6col")
  expect_true(all(is.na(out$pit_tag_id)))
  expect_type(out$pit_tag_id, "character")
})

test_that("every variant the schema lists maps onto canonical columns only", {
  # Enumerated from the YAML, so a variant added there without its rename, or
  # a rename table that misses a column, fails here rather than ingesting a
  # column of NA.
  schema <- crt_schema_read("schemas/nge/fish_data.yaml")
  for (v in schema$upstream_variants) {
    cols <- unlist(v$cols)
    raw <- tibble::as_tibble(stats::setNames(
      rep(list(character(0)), length(cols)), cols
    ))
    out <- crt_handler_nge_fish_data(raw, v$id)
    expect_identical(names(out), canonical_nge_fish(), info = v$id)
  }
})

test_that("a column the rename left unmapped aborts", {
  df <- data.frame(local_name = "a", species = "b", pass_number = 1)
  expect_error(crt_handler_nge_fish_fill(df), "pass_number")
})
