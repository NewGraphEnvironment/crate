# The nge/photo_files and nge/photo_links tables (crate#67).
#
# The registry-integrity guards already walk every schema; this file covers what
# is specific to these: a photo is told apart by its bytes, a copy names its
# original, a time with no offset is never an instant, and one photo can show
# several records.

sha <- function(ch) strrep(ch, 64)

photos <- function() {
  data.frame(
    path = c("photos/site_1/IMG_0001.JPG", "resized/site_1/IMG_0001.JPG"),
    checksum = c(sha("a"), sha("b")),
    size = c(4321987, 312004),
    time = as.POSIXct(c("2024-07-14 17:32:05", "2024-07-14 17:32:05"), tz = "UTC"),
    time_local = c("2024-07-14T10:32:05", "2024-07-14T10:32:05"),
    time_offset = c("-07:00", "-07:00"),
    gps_lon = c(-126.6612, -126.6612),
    gps_lat = c(54.3921, 54.3921),
    width = c(4032, 1008),
    height = c(3024, 756),
    media_type = c("image/jpeg", "image/jpeg"),
    camera = c("Apple iPhone 13", "Apple iPhone 13"),
    derived_from = c(NA, sha("a")),
    stringsAsFactors = FALSE
  )
}

links <- function() {
  data.frame(
    checksum = c(sha("a"), sha("a")),
    project = c("example", "example"),
    form = c("form_pscis", "form_fiss_site"),
    source_version = c("v12", "v12"),
    record_id = c(3, 7),
    site = c("125000", "125000"),
    view = c("upstream", NA),
    stringsAsFactors = FALSE
  )
}

test_that("a photo_files frame conforms to its declared types", {
  out <- crt_schema_conform(photos(), "nge", "photo_files")
  expect_type(out$path, "character")
  expect_type(out$checksum, "character")
  expect_type(out$size, "double")
  expect_s3_class(out$time, "POSIXct")
  expect_identical(attr(out$time, "tzone"), "UTC")
  expect_type(out$time_local, "character")
  expect_type(out$time_offset, "character")
  expect_type(out$gps_lon, "double")
  expect_type(out$gps_lat, "double")
  expect_type(out$width, "integer")
  expect_type(out$height, "integer")
  expect_type(out$media_type, "character")
  expect_type(out$camera, "character")
  expect_type(out$derived_from, "character")
})

test_that("a size past the integer limit is kept exactly", {
  x <- photos()
  x$size[1] <- 2^31 + 5
  out <- crt_schema_conform(x, "nge", "photo_files")
  expect_identical(out$size[1], 2^31 + 5)
})

test_that("a time with no offset keeps its wall clock and has no instant", {
  x <- photos()
  x$time <- NA
  x$time_offset <- NA_character_
  out <- crt_schema_conform(x, "nge", "photo_files")
  expect_true(all(is.na(out$time)))
  expect_s3_class(out$time, "POSIXct")
  expect_identical(out$time_local, photos()$time_local)
})

test_that("a resized copy sharing its original's name is a second row naming it", {
  out <- crt_schema_conform(photos(), "nge", "photo_files")
  expect_identical(basename(out$path[1]), basename(out$path[2]))
  expect_false(out$checksum[1] == out$checksum[2])
  expect_true(is.na(out$derived_from[1]))
  expect_identical(out$derived_from[2], out$checksum[1])
})

test_that("only path, checksum and size are required on photo_files", {
  x <- photos()[c("path", "checksum", "size")]
  out <- crt_schema_conform(x, "nge", "photo_files")
  expect_identical(nrow(out), 2L)
  for (col in c("path", "checksum", "size")) {
    y <- photos()
    y[[col]] <- NULL
    expect_error(crt_schema_conform(y, "nge", "photo_files"), col)
  }
})

test_that("a photo_links frame conforms, one row per record a photo shows", {
  out <- crt_schema_conform(links(), "nge", "photo_links")
  expect_type(out$checksum, "character")
  expect_type(out$project, "character")
  expect_type(out$form, "character")
  expect_type(out$source_version, "character")
  expect_type(out$record_id, "integer")
  expect_type(out$site, "character")
  expect_type(out$view, "character")
  expect_identical(nrow(out), 2L)
  expect_identical(out$checksum[1], out$checksum[2])
})

test_that("photo_links refuses a row without checksum or project", {
  for (col in c("checksum", "project")) {
    y <- links()
    y[[col]] <- NULL
    expect_error(crt_schema_conform(y, "nge", "photo_links"), col)
  }
})

test_that("a link meets the record grade only when it names a form record in full", {
  x <- links()
  x <- rbind(x, x[1, ], x[1, ])
  x$source_version[3] <- NA
  x$form[4] <- NA
  out <- crt_schema_conform(x, "nge", "photo_links")
  g <- crt_schema_grade(out, "nge", "photo_links")
  expect_identical(g$record, c(TRUE, TRUE, FALSE, FALSE))
  # A site-only link, such as a camera trap's, conforms without a record.
  site_only <- out[, c("checksum", "project", "site", "view")]
  expect_identical(crt_schema_grade(site_only, "nge", "photo_links")$record, c(FALSE, FALSE, FALSE, FALSE))
})
