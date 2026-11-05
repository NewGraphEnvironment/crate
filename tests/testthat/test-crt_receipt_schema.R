# The receipt schema (#43). The installed copy in inst/extdata/receipt/ is what
# crt_receipt_validate() reads; the copy in pkgdown/assets/receipt/ is what the site
# publishes at the schema's $id. The two must be one file.

receipt_schema_path <- function() {
  testthat::skip_if_not_installed("jsonvalidate")
  testthat::skip_if_not_installed("jsonlite")
  system.file("extdata", "receipt", "schema", "v1.0.0", "schema.json", package = "crate",
              mustWork = TRUE)
}

receipt_example <- function() {
  jsonlite::read_json(
    system.file("extdata", "receipt", "examples", "receipt.json", package = "crate",
                mustWork = TRUE),
    simplifyVector = FALSE
  )
}

# TRUE/FALSE, with ajv's errors on the result for a failing message
receipt_valid <- function(x, schema) {
  txt <- as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA))
  jsonvalidate::json_validate(txt, schema, engine = "ajv", verbose = TRUE)
}

errors_text <- function(ok) {
  paste(utils::capture.output(print(attr(ok, "errors"))), collapse = "\n")
}

test_that("the installed schema compiles and names its published URL", {
  schema <- receipt_schema_path()
  expect_no_error(jsonvalidate::json_schema$new(schema, engine = "ajv"))
  s <- jsonlite::read_json(schema, simplifyVector = FALSE)
  expect_equal(s$`$schema`, "http://json-schema.org/draft-07/schema#")
  expect_equal(s$`$id`, "https://newgraphenvironment.github.io/crate/receipt/v1.0.0/schema.json")
  expect_equal(s$definitions$output$properties$receipt_version$const, "1.0.0")
})

# Under R CMD check there is no source tree beside tests/, so this skips there and runs
# under devtools::test() and in the pkgdown workflow.
test_that("the published copy is byte-identical to the installed schema", {
  schema <- receipt_schema_path()
  pkg <- testthat::test_path("..", "..")
  if (!file.exists(file.path(pkg, "_pkgdown.yml"))) {
    testthat::skip("source tree not available (R CMD check)")
  }
  site <- sub("/*$", "/", yaml::read_yaml(file.path(pkg, "_pkgdown.yml"))$url)
  published <- list.files(file.path(pkg, "pkgdown", "assets", "receipt"),
                          pattern = "^schema\\.json$", recursive = TRUE)
  installed <- list.files(file.path(pkg, "inst", "extdata", "receipt", "schema"),
                          pattern = "^schema\\.json$", recursive = TRUE)
  expect_setequal(published, installed)
  expect_true(all(grepl("^v[0-9]+\\.[0-9]+\\.[0-9]+/schema\\.json$", published)))
  for (rel in published) {
    a <- readBin(file.path(pkg, "pkgdown", "assets", "receipt", rel), "raw", 1e6)
    b <- readBin(file.path(pkg, "inst", "extdata", "receipt", "schema", rel), "raw", 1e6)
    expect_identical(a, b, info = rel)
    s <- jsonlite::read_json(file.path(pkg, "pkgdown", "assets", "receipt", rel))
    expect_equal(s$`$id`, paste0(site, "receipt/", rel), info = rel)
  }
})

test_that("the example receipt validates", {
  schema <- receipt_schema_path()
  ok <- receipt_valid(receipt_example(), schema)
  expect_true(ok, info = errors_text(ok))
})

# Each mutation of the valid example must be rejected. A constraint removed from the
# schema turns its row here red, which is what proves the row guards something.
test_that("the schema rejects wrong values, missing fields and unknown keys", {
  schema <- receipt_schema_path()
  hex <- strrep("a", 64)
  cases <- list(
    "output block missing" = function(x) { x$output <- NULL; x },
    "context block missing" = function(x) { x$context <- NULL; x },
    "unknown top-level block" = function(x) { x$extra <- list(); x },
    "unknown output field" = function(x) { x$output$bogus <- "x"; x },
    "receipt_version not 1.0.0" = function(x) { x$output$receipt_version <- "1.1.0"; x },
    "empty output name" = function(x) { x$output$name <- ""; x },
    "recipe_id not 64 hex" = function(x) { x$recipe$recipe_id <- "abc"; x },
    "recipe_id upper-case" = function(x) { x$recipe$recipe_id <- toupper(hex); x },
    "recipe_id null outside a migrated receipt" = function(x) { x$recipe["recipe_id"] <- list(NULL); x },
    "recipe without seed" = function(x) { x$recipe$seed <- NULL; x },
    "seed not whole" = function(x) { x$recipe$seed <- 1.5; x },
    "short commit" = function(x) { x$recipe$code$link$commit <- "a9b8c7d"; x },
    "dirty as a string" = function(x) { x$recipe$code$link$dirty <- "false"; x },
    "input with two identities" = function(x) {
      x$recipe$inputs$flow$sha256 <- hex
      x
    },
    "input with no identity" = function(x) { x$recipe$inputs$flow <- setNames(list(), character()); x },
    "input with an unknown identity" = function(x) { x$recipe$inputs$flow <- list(md5 = "x"); x },
    "config file digest not sha256" = function(x) {
      x$recipe$config$files[[1]] <- "d41d8cd98f00b204e9800998ecf8427e"
      x
    },
    "unknown recipe field" = function(x) { x$recipe$host <- "m4"; x },
    "fingerprint without rows" = function(x) { x$result$fingerprint$access_check$rows <- NULL; x },
    "negative part size" = function(x) { x$result$parts$access_check.csv$bytes <- -1L; x },
    "absolute part path" = function(x) {
      x$result$parts <- list(`/tmp/access_check.csv` = x$result$parts[[1]])
      x
    },
    "tolerance not a power of ten" = function(x) {
      x$result$tolerance$tables$access_check$km <- 5e-10
      x
    },
    "summary tolerance zero" = function(x) { x$result$tolerance$summary$km_total <- 0; x },
    "summary value a string" = function(x) { x$result$summary$km_total <- "47.375"; x },
    "time not UTC" = function(x) { x$context$time <- "2026-11-04T11:22:05-07:00"; x },
    "toolchain version a number" = function(x) { x$context$toolchain$R <- 4.5; x },
    "unknown context field" = function(x) { x$context$machine <- "m4"; x }
  )
  base <- receipt_example()
  for (nm in names(cases)) {
    expect_false(receipt_valid(cases[[nm]](base), schema), info = nm)
  }
})

test_that("a migrated receipt may have a partial recipe and a null recipe_id", {
  schema <- receipt_schema_path()
  x <- receipt_example()
  x$output$migrated_from <- "floodplains provenance.json"
  x$recipe <- list(code = list(link = list(commit = "a9b8c7d")), recipe_id = NULL)
  ok <- receipt_valid(x, schema)
  expect_true(ok, info = errors_text(ok))
  # ...but it must still say it has no identity, rather than claim one.
  x$recipe$recipe_id <- strrep("a", 64)
  expect_false(receipt_valid(x, schema))
})
