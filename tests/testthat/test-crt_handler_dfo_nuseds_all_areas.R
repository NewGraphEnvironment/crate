# DFO's NuSEDS All Areas file (#74). The fixture is 51 rows of the 2026-06-01
# release as received (Latin-1): every Maxan Creek chinook year and one Francois
# Lake sockeye row whose local name carries a C-cedilla.
nuseds_fixture <- function() {
  system.file("extdata/examples/dfo/nuseds_all_areas_2026-06-01.csv", package = "crate")
}

test_that("NuSEDS ingests to lower-case names typed by the schema", {
  x <- crt_ingest("dfo", "nuseds_all_areas", nuseds_fixture())
  expect_identical(nrow(x), 51L)
  expect_identical(names(x), tolower(names(x)))
  expect_true(all(c("fwa_watershed_cde", "pop_id", "full_cu_in") %in% names(x)))
  expect_type(x$analysis_yr, "integer")
  expect_type(x$pop_id, "character")
  expect_type(x$act_id, "character")
  expect_type(x$gfe_id, "character")
  expect_type(x$natural_adult_spawners, "double")
  expect_type(x$total_return_to_river, "double")
  expect_type(x$start_spawn_dt_from, "character")
})

test_that("NuSEDS keeps Maxan Creek chinook's records as DFO wrote them", {
  x <- crt_ingest("dfo", "nuseds_all_areas", nuseds_fixture())
  m <- x[x$waterbody == "MAXAN CREEK", ]
  y1988 <- m[m$analysis_yr == 1988L, ]
  expect_identical(y1988$total_return_to_river, 50)
  expect_identical(y1988$enumeration_methods, "Walk")
  expect_identical(y1988$start_spawn_dt_from, "15-AUG-88")
  expect_identical(m$estimate_method[m$analysis_yr == 2008L], "Expert Opinion")
  expect_identical(
    sort(m$analysis_yr[m$adult_presence == "NONE OBSERVED"]),
    c(1986L, 2007L)
  )
})

test_that("a Latin-1 variant reads its accented names as UTF-8 text", {
  x <- crt_ingest("dfo", "nuseds_all_areas", nuseds_fixture())
  nm <- x$local_name_1[x$species == "Sockeye"]
  expect_identical(nm, "FRANÇOIS LAKE")
  expect_true(validUTF8(nm))
})

test_that("NuSEDS is read from the zip DFO publishes", {
  skip_if_not(nzchar(Sys.which("zip")))
  dir <- withr::local_tempdir()
  csv <- file.path(dir, "All Areas NuSEDS_20260601.csv")
  file.copy(nuseds_fixture(), csv)
  zipped <- file.path(dir, "nuseds.zip")
  withr::with_dir(dir, utils::zip(zipped, basename(csv), flags = "-q"))
  expect_identical(nrow(crt_ingest("dfo", "nuseds_all_areas", zipped)), 51L)
})

test_that("bytes that are not UTF-8, read as UTF-8, are refused", {
  bad <- tibble::tibble(a = c("ok", rawToChar(as.raw(c(0x46, 0xc7, 0x4f)))))
  expect_error(
    crt_ingest_check_utf8(bad, "UTF-8", "dfo", "nuseds_all_areas", "v"),
    "not UTF-8"
  )
  expect_silent(crt_ingest_check_utf8(bad, "latin1", "dfo", "nuseds_all_areas", "v"))
})

test_that("a release with the Latin-1 variant's columns but written in UTF-8 is refused", {
  utf8 <- withr::local_tempfile(fileext = ".csv")
  txt <- iconv(readLines(nuseds_fixture(), encoding = "latin1"), from = "latin1", to = "UTF-8")
  writeLines(txt, utf8, useBytes = TRUE)
  expect_error(crt_ingest("dfo", "nuseds_all_areas", utf8), "file is UTF-8")
  ascii <- withr::local_tempfile(fileext = ".csv")
  writeLines(iconv(txt, from = "UTF-8", to = "ASCII", sub = "C"), ascii, useBytes = TRUE)
  expect_identical(nrow(crt_ingest("dfo", "nuseds_all_areas", ascii)), 51L)
})
