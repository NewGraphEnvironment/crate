# The receipt test vectors (#43), the files every implementation of the contract runs.
# Formats are described in data-raw/receipt_vectors.R, which writes them.

vectors_dir <- function() {
  system.file("extdata", "receipt", "vectors", "v1.0.0", package = "crate", mustWork = TRUE)
}

read_vectors <- function(file) {
  jsonlite::read_json(file.path(vectors_dir(), file), simplifyVector = FALSE)
}

vector_bits <- function(hex) {
  readBin(as.raw(strtoi(substring(hex, seq(1, 15, 2), seq(2, 16, 2)), 16L)), "double",
          size = 8, endian = "big")
}

# A vector table back to the data frame it encodes.
decode_table <- function(tbl) {
  cols <- lapply(tbl$columns, function(col) {
    vals <- col$values
    na <- vapply(vals, is.null, TRUE)
    switch(col$type,
      character = { v <- rep(NA_character_, length(vals)); v[!na] <- unlist(vals[!na]); v },
      integer = { v <- rep(NA_integer_, length(vals)); v[!na] <- as.integer(unlist(vals[!na])); v },
      logical = { v <- rep(NA, length(vals)); v[!na] <- unlist(vals[!na]); v },
      double = {
        v <- rep(NA_real_, length(vals))
        v[!na] <- vapply(vals[!na], vector_bits, 0)
        v
      },
      date = { v <- rep(NA_character_, length(vals)); v[!na] <- unlist(vals[!na]); as.Date(v) },
      datetime = {
        v <- rep(NA_character_, length(vals))
        v[!na] <- unlist(vals[!na])
        as.POSIXct(v, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      },
      stop("unknown column type ", col$type)
    )
  })
  as.data.frame(cols, stringsAsFactors = FALSE, check.names = FALSE, optional = TRUE)
}

# A runner per file, so a vector file added with no runner fails here.
test_that("every vector file has a runner", {
  expect_setequal(list.files(vectors_dir()),
                  c("README.md", "numbers.json", "jcs.json", "recipe_id.json", "fingerprint.json"))
})

test_that("numbers.json: RFC 8785 number spelling", {
  cases <- read_vectors("numbers.json")
  expect_gt(length(cases), 500)
  x <- vapply(cases, function(cs) vector_bits(cs$bits), 0)
  want <- vapply(cases, `[[`, "", "expected")
  got <- crate:::jcs_numbers(x)
  expect_identical(got, want)
})

test_that("jcs.json: canonical JSON of each input", {
  for (cs in read_vectors("jcs.json")) {
    value <- jsonlite::parse_json(cs$input_json, simplifyVector = FALSE)
    expect_identical(crate:::crt_receipt_jcs(value), enc2utf8(cs$expected), info = cs$name)
  }
})

test_that("recipe_id.json: canonical recipe and its id", {
  cases <- read_vectors("recipe_id.json")
  for (cs in cases) {
    recipe <- jsonlite::parse_json(cs$recipe_json, simplifyVector = FALSE)
    without <- recipe
    without[["recipe_id"]] <- NULL
    expect_identical(crate:::crt_receipt_jcs(without), enc2utf8(cs$jcs), info = cs$name)
    expect_identical(crate:::crt_receipt_recipe_id(recipe), cs$recipe_id, info = cs$name)
  }
  ids <- stats::setNames(vapply(cases, `[[`, "", "recipe_id"), vapply(cases, `[[`, "", "name"))
  expect_identical(ids[["worked case"]], ids[["worked case, members in another order"]])
  expect_false(ids[["empty recipe"]] == ids[["a seed makes another recipe"]])
})

test_that("fingerprint.json: canonical table and its fingerprint", {
  cases <- read_vectors("fingerprint.json")
  for (cs in cases) {
    df <- decode_table(cs$table)
    tol <- cs$tolerance
    expect_identical(crate:::table_canonical(df, tol), enc2utf8(cs$canonical), info = cs$name)
    expect_identical(crt_table_fingerprint(df, tol), cs$sha256, info = cs$name)
  }
  sha <- stats::setNames(vapply(cases, `[[`, "", "sha256"), vapply(cases, `[[`, "", "name"))
  # The worked case: apart when exact, one fingerprint under the declared tolerance
  expect_false(sha[["worked case, first build, exact"]] == sha[["worked case, second build, exact"]])
  expect_identical(sha[["worked case, first build, km to 1e-9"]],
                   sha[["worked case, second build, km to 1e-9"]])
})
