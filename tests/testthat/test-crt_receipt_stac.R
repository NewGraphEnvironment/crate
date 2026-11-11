# The receipt's fields as a STAC item mirrors them (#59), and the receipt asset (#60).

wc <- function(build = "build_1") {
  system.file("extdata", "receipt", "examples", "worked_case", build, package = "crate",
              mustWork = TRUE)
}

url_file <- "https://stac-extensions.github.io/file/v2.1.0/schema.json"
url_processing <- "https://stac-extensions.github.io/processing/v1.2.0/schema.json"
url_receipt <- "https://newgraphenvironment.github.io/crate/stac/receipt/v1.0.0/schema.json"

test_that("a receipt's identity fields reach the item, each part under its asset", {
  r <- crt_receipt_read(wc())
  s <- crt_receipt_stac(wc(), assets = c(access = "access_check.csv", walks = "walks.csv"))
  expect_identical(names(s), c("stac_extensions", "properties", "assets"))
  expect_identical(unclass(s$stac_extensions), c(url_file, url_processing, url_receipt))
  expect_identical(s$properties$`receipt:recipe_id`, r$recipe$recipe_id)
  expect_identical(s$properties$`processing:datetime`, "2026-11-04T18:22:05Z")
  expect_identical(s$properties$`processing:software`, list(knowledge = "0.14.0", link = "0.31.2"))
  expect_setequal(names(s$assets), c("access", "walks"))
  part <- r$result$parts$access_check.csv
  expect_identical(s$assets$access$`file:checksum`, paste0("1220", part$sha256))
  expect_equal(s$assets$access$`file:size`, part$bytes)
  # A path and the list it reads to give the same fields
  expect_identical(crt_receipt_stac(r, assets = c(access = "access_check.csv", walks = "walks.csv")), s)
  # An array, however many URLs, so a JSON writer cannot unbox it
  expect_match(crate:::crt_receipt_jcs(list(e = crt_receipt_stac(r)$stac_extensions)), "^\\{\"e\":\\[")
})

test_that("a part with no asset is not mirrored, and two assets may name one part", {
  s <- crt_receipt_stac(wc())
  expect_length(s$assets, 0)
  expect_identical(crate:::crt_receipt_jcs(s$assets), "{}")
  # No asset field, so no file extension
  expect_false(url_file %in% s$stac_extensions)
  two <- crt_receipt_stac(wc(), assets = c(a = "walks.csv", b = "walks.csv"))
  expect_identical(two$assets$a, two$assets$b)
})

test_that("a migrated receipt publishes no recipe identity, never a null one", {
  m <- crt_receipt_migrate(system.file("extdata", "receipt", "examples", "legacy", "link_manifest.json",
                                       package = "crate", mustWork = TRUE),
                           "link manifest.json")
  expect_null(m$recipe$recipe_id)
  s <- crt_receipt_stac(m)
  expect_false("receipt:recipe_id" %in% names(s$properties))
  expect_false(url_receipt %in% s$stac_extensions)
  expect_true(url_processing %in% s$stac_extensions)
})

test_that("a repository with no version is left out of processing:software", {
  r <- crt_receipt_read(wc())
  r$recipe$code$link$version <- NULL
  expect_identical(crt_receipt_stac(r)$properties$`processing:software`, list(knowledge = "0.14.0"))
  r$recipe$code$knowledge$version <- NA_character_
  s <- crt_receipt_stac(r)
  expect_false("processing:software" %in% names(s$properties))
  # the time still needs the processing extension
  expect_true(url_processing %in% s$stac_extensions)
})

test_that("the receipt asset carries the digest it was written with, and no size", {
  dig <- digest::digest(file.path(wc(), "receipt.json"), algo = "sha256", file = TRUE)
  s <- crt_receipt_stac(wc(), assets = c(data = "walks.csv"), receipt_asset = "receipt",
                        receipt_sha256 = dig)
  expect_identical(s$assets$receipt, list(`file:checksum` = paste0("1220", dig)))
  expect_true(url_file %in% s$stac_extensions)
})

test_that("what the mapping cannot place is refused, never guessed", {
  dig <- strrep("a", 64)
  expect_error(crt_receipt_stac(wc(), assets = c(data = "nope.csv")), "not a part")
  expect_error(crt_receipt_stac(wc(), receipt_asset = "receipt"), "receipt_sha256")
  expect_error(crt_receipt_stac(wc(), receipt_sha256 = dig), "receipt_asset")
  expect_error(crt_receipt_stac(wc(), assets = c(receipt = "walks.csv"), receipt_asset = "receipt",
                                receipt_sha256 = dig), "both")
  for (bad in c("A", strrep("A", 64), strrep("a", 63), paste0("1220", dig))) {
    expect_error(crt_receipt_stac(wc(), receipt_asset = "receipt", receipt_sha256 = bad), "64 lower-case",
                 info = bad)
  }
  expect_error(crt_receipt_stac(wc(), assets = "walks.csv"), "named")
  expect_error(crt_receipt_stac(wc(), assets = c(a = "walks.csv", a = "access_check.csv")), "named")
  expect_error(crt_receipt_stac(wc(), assets = c(a = NA_character_)), "href")
  expect_error(crt_receipt_stac(list(1)), "receipt")
})

test_that("a field the item would publish is checked before it is mirrored", {
  r <- crt_receipt_read(wc())
  bad <- r
  bad$recipe$recipe_id <- "abc"
  expect_error(crt_receipt_stac(bad), "recipe_id")
  bad <- r
  bad$context$time <- "2026-11-04 18:22:05"
  expect_error(crt_receipt_stac(bad), "context.time")
  bad <- r
  bad$recipe$code$link$version <- 1
  expect_error(crt_receipt_stac(bad), "version")
  bad <- r
  bad$result$parts$walks.csv$bytes <- 1.5
  expect_error(crt_receipt_stac(bad, assets = c(w = "walks.csv")), "bytes")
  bad <- r
  bad$result$parts$walks.csv$sha256 <- "zz"
  expect_error(crt_receipt_stac(bad, assets = c(w = "walks.csv")), "sha256")
})

# The published field schema is what #59 says defines a conforming item, so an item built
# from each vector case must pass it. The schema is published from the source tree.
test_that("an item built from each case passes the receipt field schema", {
  pkg <- testthat::test_path("..", "..")
  if (!file.exists(file.path(pkg, "_pkgdown.yml"))) {
    testthat::skip("source tree not available (R CMD check)")
  }
  testthat::skip_if_not_installed("jsonvalidate")
  stac <- file.path(pkg, "pkgdown", "assets", "stac", "receipt")
  base <- jsonlite::read_json(file.path(stac, "examples", "item.json"), simplifyVector = FALSE)
  schema <- file.path(stac, "v1.0.0", "schema.json")
  cases <- jsonlite::read_json(system.file("extdata", "receipt", "mapping",
                                           paste0("v", crate:::receipt_mapping_version()), "stac.json",
                                           package = "crate", mustWork = TRUE),
                               simplifyVector = FALSE)
  n <- 0
  for (cs in cases[vapply(cases, function(cs) is.null(cs$error), TRUE)]) {
    s <- crt_receipt_stac(cs$receipt, assets = if (length(cs$assets)) unlist(cs$assets),
                          receipt_asset = cs$receipt_asset, receipt_sha256 = cs$receipt_sha256)
    item <- base
    item$stac_extensions <- as.list(s$stac_extensions)
    item$properties <- c(list(datetime = base$properties$datetime), s$properties)
    item$assets <- lapply(s$assets, function(a) c(list(href = "x", roles = list("data")), a))
    # The schema applies to an item that lists it; one with no receipt field (a migrated
    # receipt's) lists it not, and carries no receipt: field it would check
    url <- "https://newgraphenvironment.github.io/crate/stac/receipt/v1.0.0/schema.json"
    if (!url %in% s$stac_extensions) {
      expect_false(any(startsWith(names(s$properties), "receipt:")), info = cs$name)
      next
    }
    txt <- crate:::crt_receipt_jcs(item)
    ok <- jsonvalidate::json_validate(txt, schema, engine = "ajv", verbose = TRUE)
    expect_true(ok, info = cs$name)
    n <- n + 1
  }
  expect_gt(n, 5)
})
