# The table fingerprint (#43): SHA-256 over the RFC 8785 JSON of the table's
# canonical form.

test_that("the canonical form is the JCS of sorted columns and sorted rows", {
  x <- data.frame(b = c("y", "x"), a = c(2L, 1L))
  expect_identical(
    crate:::table_canonical(x),
    '{"columns":["a","b"],"rows":[["1","x"],["2","y"]]}'
  )
  expect_identical(
    crt_table_fingerprint(x),
    digest::digest(charToRaw('{"columns":["a","b"],"rows":[["1","x"],["2","y"]]}'),
                   algo = "sha256", serialize = FALSE)
  )
})

test_that("column order and row order do not move the fingerprint", {
  x <- data.frame(id = c("a", "b", "c"), km = c(1.5, 2.25, 3), n = c(1L, 2L, 3L))
  y <- x[c(3, 1, 2), c("n", "id", "km")]
  rownames(y) <- NULL
  expect_identical(crt_table_fingerprint(x), crt_table_fingerprint(y))
  expect_identical(crt_table_fingerprint(tibble::as_tibble(x)), crt_table_fingerprint(x))
})

test_that("a value change moves it, and a duplicate row counts", {
  x <- data.frame(id = c("a", "b"), km = c(1.5, 2.25))
  y <- x
  y$km[2] <- 2.26
  expect_false(crt_table_fingerprint(x) == crt_table_fingerprint(y))
  expect_false(crt_table_fingerprint(x) == crt_table_fingerprint(x[c(1, 2, 2), ]))
})

# The worked case: a sum that came out 9.5e-11 km apart because the database summed
# in another order.
test_that("a difference within the declared tolerance gives the same fingerprint", {
  a <- data.frame(segment = c("s1", "s2"), km = c(12.3456789012, 7.25))
  b <- a
  b$km[1] <- b$km[1] + 9.5e-11
  expect_false(crt_table_fingerprint(a) == crt_table_fingerprint(b))
  expect_identical(crt_table_fingerprint(a, c(km = 1e-9)), crt_table_fingerprint(b, c(km = 1e-9)))
  expect_identical(crt_table_fingerprint(a, list(km = 1e-9)), crt_table_fingerprint(b, c(km = 1e-9)))
  expect_identical(
    crate:::table_canonical(a, c(km = 1e-9)),
    '{"columns":["km","segment"],"rows":[["12.345678901","s1"],["7.250000000","s2"]]}'
  )
})

test_that("doubles: shortest form when exact, printf rounding when declared", {
  x <- data.frame(v = c(0.1, 1e21, -0, 100, 1e-7))
  expect_identical(crate:::table_canonical(x),
                   '{"columns":["v"],"rows":[["0"],["0.1"],["100"],["1e+21"],["1e-7"]]}')
  # Ties to even on the binary value, as printf does; a rounded zero has no sign
  y <- data.frame(v = c(0.5, 1.5, 2.5, -0.001, -0.4))
  expect_identical(crate:::table_canonical(y, c(v = 1)),
                   '{"columns":["v"],"rows":[["0"],["0"],["0"],["2"],["2"]]}')
  expect_identical(crate:::table_canonical(data.frame(v = -0.001), c(v = 0.01)),
                   '{"columns":["v"],"rows":[["0.00"]]}')
})

test_that("NA and the empty string are different values", {
  expect_identical(crate:::table_canonical(data.frame(s = c(NA, ""))),
                   '{"columns":["s"],"rows":[[""],[null]]}')
  expect_false(crt_table_fingerprint(data.frame(s = NA_character_)) ==
                 crt_table_fingerprint(data.frame(s = "")))
  expect_false(crt_table_fingerprint(data.frame(s = NA_character_)) ==
                 crt_table_fingerprint(data.frame(s = "NA")))
})

test_that("logicals, factors, dates and datetimes have one spelling each", {
  x <- data.frame(
    d = as.Date("2026-11-04"),
    f = factor("CO"),
    l = c(TRUE),
    t = as.POSIXct("2026-11-04 11:22:05", tz = "America/Vancouver")
  )
  expect_identical(
    crate:::table_canonical(x),
    '{"columns":["d","f","l","t"],"rows":[["2026-11-04","CO","true","2026-11-04T18:22:05Z"]]}'
  )
  expect_identical(crt_table_fingerprint(transform(x, f = as.character(f))), crt_table_fingerprint(x))
})

test_that("the fingerprint does not depend on the locale", {
  x <- data.frame(name = c("été", "Zed", "apple"), v = c(1.5, 2, 3))
  a <- crt_table_fingerprint(x)
  b <- withr::with_locale(c(LC_COLLATE = "C", LC_CTYPE = "C"), crt_table_fingerprint(x))
  expect_identical(a, b)
})

test_that("it refuses what has no canonical form", {
  expect_error(crt_table_fingerprint(list(a = 1)), "data frame")
  expect_error(crt_table_fingerprint(data.frame()), "no columns")
  expect_error(crt_table_fingerprint(data.frame(v = NaN)), "NaN or infinite")
  expect_error(crt_table_fingerprint(data.frame(v = Inf)), "NaN or infinite")
  x <- data.frame(t = as.POSIXct("2026-11-04 18:22:05.5", tz = "UTC"))
  expect_error(crt_table_fingerprint(x), "fractional seconds")
  y <- data.frame(id = 1)
  y$g <- list(1:2)
  expect_error(crt_table_fingerprint(y), "no canonical form")
  dup <- data.frame(a = 1, a = 2, check.names = FALSE)
  expect_error(crt_table_fingerprint(dup), "unique")
})

test_that("a tolerance must be a power of ten on a double column", {
  x <- data.frame(id = 1L, km = 1.5)
  expect_error(crt_table_fingerprint(x, c(km = 5e-10)), "power of ten")
  expect_error(crt_table_fingerprint(x, c(km = 0)), "power of ten")
  expect_error(crt_table_fingerprint(x, c(km = 1e-16)), "power of ten")
  expect_error(crt_table_fingerprint(x, c(km = 10)), "power of ten")
  expect_error(crt_table_fingerprint(x, c(mi = 1e-9)), "not a column")
  expect_error(crt_table_fingerprint(x, c(id = 1e-9)), "double columns only")
  expect_error(crt_table_fingerprint(x, 1e-9), "named numeric")
  expect_no_error(crt_table_fingerprint(x, c(km = 1)))
  expect_no_error(crt_table_fingerprint(x, c(km = 1e-15)))
})

test_that("an empty table has a fingerprint over its columns alone", {
  x <- data.frame(a = character(), b = numeric())
  expect_identical(crate:::table_canonical(x), '{"columns":["a","b"],"rows":[]}')
})
