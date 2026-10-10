# STAC extension schemas for the catalogues' custom field prefixes (#23).
#
# They live in pkgdown/assets/stac/ and are published by the pkgdown site, not shipped
# in the package, so these tests read the source tree. Under R CMD check the tests run
# from a copy of tests/ with no source tree beside it, and skip.

stac_root <- function() {
  pkg <- testthat::test_path("..", "..")
  if (!file.exists(file.path(pkg, "_pkgdown.yml"))) {
    testthat::skip("source tree not available (R CMD check)")
  }
  testthat::skip_if_not_installed("jsonvalidate")
  testthat::skip_if_not_installed("jsonlite")
  pkg
}

# Every released schema: <prefix>/v<X.Y.Z>/schema.json
stac_schemas <- function(pkg) {
  root <- file.path(pkg, "pkgdown", "assets", "stac")
  files <- list.files(root, pattern = "^schema\\.json$", recursive = TRUE)
  files[grepl("^[a-z][a-z0-9_]*/v[0-9]+\\.[0-9]+\\.[0-9]+/schema\\.json$", files)]
}

stac_url <- function(pkg, rel) {
  site <- sub("/*$", "/", yaml::read_yaml(file.path(pkg, "_pkgdown.yml"))$url)
  paste0(site, "stac/", rel)
}

json_read <- function(path) jsonlite::read_json(path, simplifyVector = FALSE)

json_text <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA))
}

# TRUE/FALSE, with ajv's errors carried on the result for a failing message
stac_valid <- function(x, schema_path) {
  jsonvalidate::json_validate(json_text(x), schema_path, engine = "ajv", verbose = TRUE)
}

stac_schema_path <- function(pkg, prefix) {
  rel <- stac_schemas(pkg)
  rel <- rel[startsWith(rel, paste0(prefix, "/"))]
  testthat::expect_length(rel, 1)
  file.path(pkg, "pkgdown", "assets", "stac", rel)
}

test_that("each released schema names its own published URL", {
  pkg <- stac_root()
  rel <- stac_schemas(pkg)
  expect_gt(length(rel), 0)
  expect_setequal(sub("/.*", "", rel), c("lidarbc", "las"))
  for (r in rel) {
    s <- json_read(file.path(pkg, "pkgdown", "assets", "stac", r))
    url <- stac_url(pkg, r)
    expect_equal(s$`$schema`, "http://json-schema.org/draft-07/schema#", info = r)
    expect_equal(s$`$id`, url, info = r)
    expect_equal(s$properties$stac_extensions$contains$const, url, info = r)
  }
})

test_that("each prefix's examples validate against its schema", {
  pkg <- stac_root()
  for (prefix in c("lidarbc", "las")) {
    ex <- list.files(file.path(pkg, "pkgdown", "assets", "stac", prefix, "examples"),
                     pattern = "\\.json$", full.names = TRUE)
    expect_gt(length(ex), 0)
    for (f in ex) {
      ok <- stac_valid(json_read(f), stac_schema_path(pkg, prefix))
      expect_true(ok, info = paste(f, paste(capture.output(print(attr(ok, "errors"))),
                                            collapse = "\n")))
    }
  }
})

# Each mutation of a valid example must be rejected. A constraint removed from a schema
# turns its row here red, which is what proves the row is guarding something.
test_that("the schemas reject wrong values and unknown fields", {
  pkg <- stac_root()
  base <- function(prefix) {
    json_read(file.path(pkg, "pkgdown", "assets", "stac", prefix, "examples", "item.json"))
  }
  set_prop <- function(x, k, v) {
    x$properties[[k]] <- v
    x
  }
  cases <- list(
    list("las", "point_format above 10", function(x) set_prop(x, "las:point_format", 11L)),
    list("las", "point_format as a string", function(x) set_prop(x, "las:point_format", "6")),
    list("las", "point_format not whole", function(x) set_prop(x, "las:point_format", 6.5)),
    list("las", "version not a LAS version", function(x) set_prop(x, "las:version", "1.5")),
    list("las", "version as a number", function(x) set_prop(x, "las:version", 1.4)),
    list("las", "unknown las: field", function(x) set_prop(x, "las:bogus", "x")),
    list("las", "bad version on the copc asset", function(x) {
      x$assets$copc$`las:version` <- "2.0"
      x
    }),
    list("las", "extension URL not listed", function(x) {
      x$stac_extensions <- Filter(function(u) !grepl("/stac/las/", u), x$stac_extensions)
      x
    }),
    list("lidarbc", "datetime_source not filename or path",
         function(x) set_prop(x, "lidarbc:datetime_source", "guess")),
    list("lidarbc", "delivery without the year",
         function(x) set_prop(x, "lidarbc:delivery", "092/092g")),
    list("lidarbc", "delivery with an upper-case sheet",
         function(x) set_prop(x, "lidarbc:delivery", "092/092G/2019")),
    list("lidarbc", "empty product", function(x) set_prop(x, "lidarbc:product", "")),
    list("lidarbc", "empty filename_date", function(x) set_prop(x, "lidarbc:filename_date", "")),
    list("lidarbc", "unknown lidarbc: field", function(x) set_prop(x, "lidarbc:bogus", "x")),
    list("lidarbc", "extension URL not listed", function(x) {
      x$stac_extensions <- Filter(function(u) !grepl("/stac/lidarbc/", u), x$stac_extensions)
      x
    })
  )
  for (cs in cases) {
    prefix <- cs[[1]]
    expect_true(stac_valid(base(prefix), stac_schema_path(pkg, prefix)),
                info = paste(prefix, "base example"))
    expect_false(stac_valid(cs[[3]](base(prefix)), stac_schema_path(pkg, prefix)),
                 info = paste(prefix, cs[[2]]))
  }
})

test_that("a collection's summaries are checked against the field types", {
  pkg <- stac_root()
  coll <- json_read(file.path(pkg, "pkgdown", "assets", "stac", "lidarbc", "examples",
                              "collection.json"))
  path <- stac_schema_path(pkg, "lidarbc")
  expect_true(stac_valid(coll, path))
  coll$summaries$`lidarbc:datetime_source` <- list("guess")
  expect_false(stac_valid(coll, path))
})
