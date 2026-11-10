# Extracted from test-crt_receipt_stac.R:131

# prequel ----------------------------------------------------------------------
wc <- function(build = "build_1") {
  system.file("extdata", "receipt", "examples", "worked_case", build, package = "crate",
              mustWork = TRUE)
}
url_file <- "https://stac-extensions.github.io/file/v2.1.0/schema.json"
url_processing <- "https://stac-extensions.github.io/processing/v1.2.0/schema.json"
url_receipt <- "https://newgraphenvironment.github.io/crate/stac/receipt/v1.0.0/schema.json"

# test -------------------------------------------------------------------------
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
    txt <- crate:::crt_receipt_jcs(item)
    ok <- jsonvalidate::json_validate(txt, schema, engine = "ajv", verbose = TRUE)
    expect_true(ok, info = cs$name)
    n <- n + 1
  }
