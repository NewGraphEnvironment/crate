# The receipt test vectors (#43), the files every implementation of the contract runs.
# Formats are described in data-raw/receipt_vectors.R, which writes them.

vectors_dir <- function() {
  system.file("extdata", "receipt", "vectors", "v1.0.0", package = "crate", mustWork = TRUE)
}

# compare.json tests the register, so it is versioned with the register, not the form (#58).
register_dir <- function() {
  system.file("extdata", "receipt", "register", paste0("v", crate:::receipt_register_version()),
              package = "crate", mustWork = TRUE)
}

read_vectors <- function(file) {
  dir <- if (file == "compare.json") register_dir() else vectors_dir()
  jsonlite::read_json(file.path(dir, file), simplifyVector = FALSE)
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
    # NA where the vector holds null, the values elsewhere
    fill <- function(empty, got) {
      v <- rep(empty, length(vals))
      v[!na] <- got
      v
    }
    switch(col$type,
      character = fill(NA_character_, unlist(vals[!na])),
      integer = fill(NA_integer_, as.integer(unlist(vals[!na]))),
      logical = fill(NA, unlist(vals[!na])),
      double = fill(NA_real_, vapply(vals[!na], vector_bits, 0)),
      date = as.Date(fill(NA_character_, unlist(vals[!na]))),
      datetime = as.POSIXct(fill(NA_character_, unlist(vals[!na])), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      stop("unknown column type ", col$type)
    )
  })
  as.data.frame(cols, stringsAsFactors = FALSE, check.names = FALSE, optional = TRUE)
}

# A runner per file, so a vector file added with no runner fails here.
test_that("every vector file has a runner", {
  expect_setequal(list.files(vectors_dir()),
                  c("README.md", "numbers.json", "jcs.json", "recipe_id.json", "fingerprint.json"))
  expect_setequal(list.files(register_dir()), c("README.md", "register.csv", "compare.json"))
})

test_that("numbers.json: RFC 8785 number spelling", {
  cases <- read_vectors("numbers.json")
  expect_gt(length(cases), 2600)
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

test_that("compare.json: verdict and the fields that differed", {
  cases <- read_vectors("compare.json")
  expect_gt(length(cases), 5)
  for (cs in cases) {
    x <- crt_receipt_compare(cs$a, cs$b)
    expect_identical(x$verdict, cs$verdict, info = cs$name)
    d <- x$differences[order(x$differences$field, method = "radix"), ]
    want <- do.call(rbind, lapply(cs$differences, as.data.frame))
    if (is.null(want)) want <- data.frame(field = character(), action = character())
    expect_identical(d$field, want$field, info = cs$name)
    expect_identical(d$action, want$action, info = cs$name)
  }
  verdicts <- vapply(cases, `[[`, "", "verdict")
  expect_setequal(unique(verdicts), c("identical", "equivalent", "different"))
})
