wide_fixture <- function() {
  system.file(
    "extdata/examples/bcfp/user_habitat_classification_wide.csv",
    package = "crate"
  )
}

long_fixture <- function() {
  system.file(
    "extdata/examples/bcfp/user_habitat_classification_long.csv",
    package = "crate"
  )
}

canonical_cols <- c(
  "blue_line_key", "downstream_route_measure", "upstream_route_measure",
  "watershed_group_code", "species_code", "spawning", "rearing",
  "reviewer_name", "review_date", "source", "notes"
)

test_that("wide-variant input returns canonical wide tibble (identity)", {
  out <- crt_ingest("bcfp", "user_habitat_classification", wide_fixture())
  expect_s3_class(out, "tbl_df")
  expect_equal(names(out), canonical_cols)
  expect_equal(nrow(out), 6L)
})

test_that("long-variant input returns canonical wide tibble (pivot)", {
  out <- crt_ingest("bcfp", "user_habitat_classification", long_fixture())
  expect_s3_class(out, "tbl_df")
  expect_equal(names(out), canonical_cols)
  # Long fixture has 7 rows covering 5 unique (segment x species) tuples
  expect_equal(nrow(out), 5L)
})

test_that("invariance: long pivoted == wide identity (minus -4 excluded row)", {
  wide <- crt_ingest("bcfp", "user_habitat_classification", wide_fixture())
  long <- crt_ingest("bcfp", "user_habitat_classification", long_fixture())

  # Drop the -4 excluded row from wide for comparison (long fixture predates -4 semantics)
  wide_no_excluded <- dplyr::filter(
    wide,
    !(spawning %in% -4L | rearing %in% -4L)
  )

  wide_sorted <- dplyr::arrange(wide_no_excluded, blue_line_key, species_code)
  long_sorted <- dplyr::arrange(long, blue_line_key, species_code)

  # Compare ignoring integer-vs-double type difference on spawning/rearing
  # (wide reads as double due to blanks; long pivots to int)
  expect_equal(
    dplyr::mutate(
      wide_sorted,
      spawning = as.integer(spawning),
      rearing = as.integer(rearing)
    ),
    long_sorted
  )
})

test_that("wide-variant preserves -4 excluded value", {
  out <- crt_ingest("bcfp", "user_habitat_classification", wide_fixture())
  excluded <- dplyr::filter(out, blue_line_key == 356600333L)
  expect_equal(nrow(excluded), 1L)
  expect_equal(excluded$spawning, -4)
  expect_equal(excluded$rearing, -4)
})

test_that("unknown (source, file_name) pair throws with diagnostic", {
  expect_error(
    crt_ingest("bogus_source", "user_habitat_classification", wide_fixture()),
    "Unknown.*bogus_source"
  )
  expect_error(
    crt_ingest("bcfp", "bogus_file", wide_fixture()),
    "Unknown.*bogus_file"
  )
})

test_that("nonexistent file path throws with diagnostic", {
  expect_error(
    crt_ingest("bcfp", "user_habitat_classification", "/nonexistent/path.csv"),
    "File does not exist"
  )
})

test_that("input with unrecognized shape throws with diagnostic", {
  garbage <- tempfile(fileext = ".csv")
  on.exit(unlink(garbage), add = TRUE)
  writeLines(
    c("col_a,col_b,col_c", "1,2,3"),
    garbage
  )
  expect_error(
    crt_ingest("bcfp", "user_habitat_classification", garbage),
    "does not match any known upstream variant"
  )
})

test_that("non-string args throw chk validation errors", {
  expect_error(crt_ingest(1, "user_habitat_classification", wide_fixture()))
  expect_error(crt_ingest("bcfp", 1, wide_fixture()))
  expect_error(crt_ingest("bcfp", "user_habitat_classification", 1))
})

# ---- nge/fish_data: three file shapes, one canonical set (#6) ---------------

nge_fish_fixture <- function(name) {
  system.file("extdata/examples/nge", name, package = "crate")
}

nge_fish_all <- function() {
  files <- c(
    "2023" = "fish_data_2023_peace.csv",
    "2023" = "fish_data_2023_skeena.csv",
    "2024" = "fish_data_2024.csv"
  )
  lapply(files, function(f) crt_ingest("nge", "fish_data", nge_fish_fixture(f)))
}

test_that("every fish_data shape ingests to the same names and types", {
  outs <- nge_fish_all()
  classes <- lapply(outs, function(x) vapply(x, function(col) class(col)[[1]], character(1)))
  expect_identical(classes[[2]], classes[[1]])
  expect_identical(classes[[3]], classes[[1]])
  expect_identical(classes[[1]][["length_mm"]], "numeric")
  expect_identical(classes[[1]][["haul_number_pass_number"]], "integer")
  expect_identical(classes[[1]][["date"]], "character")
})

test_that("fish_data seasons bind, and a tag recaptured from a 2023 comment is found", {
  outs <- nge_fish_all()
  fish <- dplyr::bind_rows(outs, .id = "season")
  expect_identical(nrow(fish), 11L)
  # The recapture query the schema exists for. 3DD.003E190001 is written only in
  # a 2023 comment and in the 2024 pit_tag_id column; the fixtures plant it, as
  # no real 2023 tag recurs in a later season.
  recaptured <- fish |>
    dplyr::filter(!is.na(pit_tag_id)) |>
    dplyr::group_by(pit_tag_id) |>
    dplyr::filter(dplyr::n_distinct(season) > 1L) |>
    dplyr::ungroup()
  expect_identical(unique(recaptured$pit_tag_id), "3DD.003E190001")
  expect_identical(sort(recaptured$length_mm), c(157, 201))
})
