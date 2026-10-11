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

# The local file of the schema version an example names in `stac_extensions`. Examples
# are not versioned, so each is checked against the version it lists, and older versions
# are left to the publishing guard in pkgdown.yaml.
stac_schema_path <- function(pkg, prefix, x) {
  urls <- unlist(x$stac_extensions)
  url <- urls[grepl(paste0("/stac/", prefix, "/v[^/]+/schema\\.json$"), urls)]
  testthat::expect_length(url, 1)
  rel <- sub(".*/stac/", "", url)
  testthat::expect_equal(stac_url(pkg, rel), url)
  file.path(pkg, "pkgdown", "assets", "stac", rel)
}

# Every object holding a `$ref`. Draft-07 ignores a `$ref`'s siblings, and the two
# validators that read these schemas disagree about it: ajv (these tests) applies them,
# Python jsonschema (pystac) does not. A sibling would be enforced here and skipped in
# every catalogue build.
ref_objects <- function(x) {
  if (!is.list(x)) return(list())
  here <- if (!is.null(names(x)) && "$ref" %in% names(x)) list(x) else list()
  c(here, unlist(lapply(x, ref_objects), recursive = FALSE))
}

test_that("each released schema names its own published URL", {
  pkg <- stac_root()
  rel <- stac_schemas(pkg)
  expect_gt(length(rel), 0)
  # The site and the publishing guard take every schema.json; a misnamed version
  # directory would deploy, be frozen by the guard, and never be tested.
  every <- list.files(file.path(pkg, "pkgdown", "assets", "stac"), pattern = "^schema\\.json$",
                      recursive = TRUE)
  expect_setequal(every, rel)
  for (r in rel) {
    s <- json_read(file.path(pkg, "pkgdown", "assets", "stac", r))
    url <- stac_url(pkg, r)
    expect_equal(s$`$schema`, "http://json-schema.org/draft-07/schema#", info = r)
    expect_equal(s$`$id`, url, info = r)
    expect_equal(s$properties$stac_extensions$contains$const, url, info = r)
    refs <- ref_objects(s)
    expect_gt(length(refs), 0)
    for (o in refs) expect_equal(names(o), "$ref", info = r)
    # Compiling checks every keyword's own type and resolves every $ref. A version no
    # example names is otherwise checked only for the structure above.
    expect_no_error(jsonvalidate::json_schema$new(
      file.path(pkg, "pkgdown", "assets", "stac", r), engine = "ajv"
    ))
  }
})

# Prefixes come from the published tree, not a list here, so a new prefix cannot ship
# without examples. Each prefix's examples name its newest version, so whatever is about
# to be published is the version they exercise.
test_that("each prefix's examples validate against its newest schema", {
  pkg <- stac_root()
  rel <- stac_schemas(pkg)
  for (prefix in unique(sub("/.*", "", rel))) {
    versions <- sub("^[^/]+/v([^/]+)/schema\\.json$", "\\1", rel[startsWith(rel, paste0(prefix, "/"))])
    newest <- paste0(prefix, "/v", as.character(max(package_version(versions))), "/schema.json")
    ex <- list.files(file.path(pkg, "pkgdown", "assets", "stac", prefix, "examples"),
                     pattern = "\\.json$", full.names = TRUE)
    expect_gt(length(ex), 0)
    for (f in ex) {
      x <- json_read(f)
      expect_true(stac_url(pkg, newest) %in% unlist(x$stac_extensions),
                  info = paste(f, "does not name", newest))
      ok <- stac_valid(x, stac_schema_path(pkg, prefix, x))
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
    list("lidarbc", "datetime_unknown as a string",
         function(x) set_prop(x, "lidarbc:datetime_unknown", "true")),
    list("lidarbc", "datetime_unknown as a number",
         function(x) set_prop(x, "lidarbc:datetime_unknown", 1L)),
    list("lidarbc", "unknown lidarbc: field", function(x) set_prop(x, "lidarbc:bogus", "x")),
    list("lidarbc", "extension URL not listed", function(x) {
      x$stac_extensions <- Filter(function(u) !grepl("/stac/lidarbc/", u), x$stac_extensions)
      x
    })
  )
  for (cs in cases) {
    prefix <- cs[[1]]
    path <- stac_schema_path(pkg, prefix, base(prefix))
    expect_true(stac_valid(base(prefix), path), info = paste(prefix, "base example"))
    expect_false(stac_valid(cs[[3]](base(prefix)), path), info = paste(prefix, cs[[2]]))
  }
})

test_that("a collection's summaries are checked against the field types", {
  pkg <- stac_root()
  base <- json_read(file.path(pkg, "pkgdown", "assets", "stac", "lidarbc", "examples",
                              "collection.json"))
  path <- stac_schema_path(pkg, "lidarbc", base)
  expect_true(stac_valid(base, path))
  x <- base
  x$summaries$`lidarbc:datetime_source` <- list("guess")
  expect_false(stac_valid(x, path), info = "summary value outside the enum")
  x <- base
  x$summaries$`lidarbc:datetime_unknown` <- list(TRUE)
  expect_true(stac_valid(x, path), info = "boolean summary")
  x$summaries$`lidarbc:datetime_unknown` <- list("yes")
  expect_false(stac_valid(x, path), info = "summary value not a boolean")
  x <- base
  x$summaries$`lidarbc:bogus` <- list("x")
  expect_false(stac_valid(x, path), info = "unknown lidarbc: summary")
  x <- base
  x$summaries$`lidarbc:product` <- "pointcloud"
  expect_false(stac_valid(x, path), info = "summary not a list")
  x <- base
  x$stac_extensions <- list("https://stac-extensions.github.io/version/v1.2.0/schema.json")
  expect_false(stac_valid(x, path), info = "extension URL not listed")
})

test_that("las summaries take a list or a range of valid values", {
  pkg <- stac_root()
  item <- json_read(file.path(pkg, "pkgdown", "assets", "stac", "las", "examples", "item.json"))
  path <- stac_schema_path(pkg, "las", item)
  coll <- json_read(file.path(pkg, "pkgdown", "assets", "stac", "lidarbc", "examples",
                              "collection.json"))
  coll$stac_extensions <- Filter(function(u) grepl("/stac/las/", u), item$stac_extensions)
  coll$summaries <- list(`las:version` = list("1.2", "1.4"),
                         `las:point_format` = list(minimum = 0L, maximum = 6L))
  expect_true(stac_valid(coll, path))
  x <- coll
  x$summaries$`las:point_format`$maximum <- 11L
  expect_false(stac_valid(x, path), info = "range above 10")
  x <- coll
  x$summaries$`las:point_format` <- list(1L, 11L)
  expect_false(stac_valid(x, path), info = "list value above 10")
  x <- coll
  x$summaries$`las:version` <- list(minimum = "1.0", maximum = "1.4")
  expect_false(stac_valid(x, path), info = "version as a range")
  x <- coll
  x$item_assets <- list(copc = list(`las:point_format` = 11L))
  expect_false(stac_valid(x, path), info = "item_assets value above 10")
})
