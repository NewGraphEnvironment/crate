# crt_schema_fingerprint(): the one definition of form_capture's schema_version.
#
# The expected values are pinned two independent ways. The digest is checked
# against published XXH64 test vectors, so a change of hash or a slip back to
# hashing R's serialization fails here rather than in a harvest. The whole
# value is checked on a real column set, rfp's shipped form_pscis, whose types
# are the GeoPackage's declared ones.

pscis_types <- function() {
  x <- utils::read.csv(
    testthat::test_path("fixtures", "forms", "form_pscis__rfp-build-2026-08.csv"),
    colClasses = "character"
  )
  stats::setNames(x$type, x$name)
}

test_that("the digest is standard XXH64 over the string's own bytes", {
  # Published vectors for XXH64, seed 0. With serialize = TRUE digest would
  # hash R's serialization of the string instead, and these would not match.
  xxh64 <- function(s) sub("^[0-9]+-", "", crt_schema_fingerprint(stats::setNames(s, "x")))
  expect_identical(
    digest::digest("", algo = "xxhash64", serialize = FALSE),
    "ef46db3751d8e999"
  )
  expect_identical(
    digest::digest("abc", algo = "xxhash64", serialize = FALSE),
    "44bc2cf5ad770999"
  )
  # One column `x` of type `bc` hashes the string "x:BC".
  expect_identical(
    xxh64("bc"),
    digest::digest("x:BC", algo = "xxhash64", serialize = FALSE)
  )
})

test_that("rfp's shipped form_pscis has a pinned fingerprint", {
  types <- pscis_types()
  expect_length(types, 99L)
  expect_identical(crt_schema_fingerprint(types), "99-c084e87fbf17e20e")
})

test_that("the pscis fixture is the column set measured on live captures", {
  # Before crate owned the definition, trap hashed R's serialization of the same
  # string, and wrote 99-36743b027ac0c93f for every 2026 pscis capture measured
  # (2026-10-30). Reproducing that value from the fixture shows the fixture is
  # that column set, not one crate made up, so the new value above describes
  # the forms in the field.
  types <- pscis_types()
  cols <- sort(names(types), method = "radix")
  pairs <- paste0(cols, ":", toupper(types[cols]), collapse = ",")
  expect_identical(
    digest::digest(pairs, algo = "xxhash64", serializeVersion = 2),
    "36743b027ac0c93f"
  )
})

test_that("an unmarked UTF-8 name gives the same value in any locale", {
  # Bytes as a reader that does not mark encodings returns them.
  x <- rawToChar(as.raw(c(0x64, 0xc3, 0xa9, 0x62, 0x69, 0x74)))
  expect_identical(Encoding(x), "unknown")
  marked <- crt_schema_fingerprint(stats::setNames("TEXT", enc2utf8("d\u00e9bit")))
  withr::local_locale(c(LC_CTYPE = "C"))
  expect_identical(crt_schema_fingerprint(stats::setNames("TEXT", x)), marked)
})

test_that("a name in another encoding gives the same value", {
  utf8 <- stats::setNames("TEXT", enc2utf8("d\u00e9bit"))
  latin1 <- stats::setNames("TEXT", iconv(names(utf8), "UTF-8", "latin1"))
  expect_identical(Encoding(names(latin1)), "latin1")
  expect_identical(crt_schema_fingerprint(latin1), crt_schema_fingerprint(utf8))
})

test_that("column order does not move it", {
  types <- pscis_types()
  set.seed(1)
  expect_identical(
    crt_schema_fingerprint(types[sample(length(types))]),
    crt_schema_fingerprint(types)
  )
})

test_that("a changed type moves it, and case does not", {
  types <- pscis_types()
  changed <- replace(types, "pscis_crossing_id", "TEXT")
  expect_false(crt_schema_fingerprint(changed) == crt_schema_fingerprint(types))
  expect_identical(crt_schema_fingerprint(tolower(types) |> stats::setNames(names(types))),
                   crt_schema_fingerprint(types))
})

test_that("an added or dropped column moves it", {
  types <- pscis_types()
  expect_identical(sub("-.*", "", crt_schema_fingerprint(types[-1])), "98")
  expect_false(crt_schema_fingerprint(c(types, extra = "TEXT")) == crt_schema_fingerprint(types))
})

test_that("names sort in C collation whatever the locale", {
  # In most UTF-8 locales "a_b" sorts before "aB"; in C collation uppercase
  # comes first. Hashing in locale order would give one capture two values.
  types <- c(a_b = "TEXT", aB = "TEXT", Z = "REAL")
  withr::local_collate("C")
  in_c <- crt_schema_fingerprint(types)
  withr::local_collate("en_US.UTF-8")
  expect_identical(crt_schema_fingerprint(types), in_c)
  expect_identical(
    in_c,
    paste0("3-", digest::digest("Z:REAL,aB:TEXT,a_b:TEXT", algo = "xxhash64", serialize = FALSE))
  )
})

test_that("it refuses input that would hash a weaker fact", {
  expect_error(crt_schema_fingerprint(character(0)), "non-empty")
  expect_error(crt_schema_fingerprint(c("TEXT", "REAL")), "named")
  expect_error(crt_schema_fingerprint(c(a = "TEXT", a = "REAL")), "unique")
  expect_error(crt_schema_fingerprint(c(a = "TEXT", b = NA)), "No declared type")
  expect_error(crt_schema_fingerprint(c(a = "TEXT", b = " ")), "No declared type")
  expect_error(crt_schema_fingerprint(list(a = "TEXT")), "character")
})
