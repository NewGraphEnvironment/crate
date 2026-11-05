# RFC 8785 canonical JSON and recipe_id (#43). Expected strings are RFC 8785's own
# examples, and agree with Python's rfc8785 0.1.4.

# A double from its IEEE 754 bits. Never from a 17-digit R literal: R's parser is not
# correctly rounded on every platform (on arm64 macOS it misreads most of them).
from_bits <- function(hex) {
  readBin(as.raw(strtoi(substring(hex, seq(1, 15, 2), seq(2, 16, 2)), 16L)), "double",
          size = 8, endian = "big")
}

test_that("numbers follow RFC 8785 Appendix B", {
  samples <- c(
    "0000000000000000" = "0",
    "8000000000000000" = "0",
    "0000000000000001" = "5e-324",
    "8000000000000001" = "-5e-324",
    "7fefffffffffffff" = "1.7976931348623157e+308",
    "ffefffffffffffff" = "-1.7976931348623157e+308",
    "4340000000000000" = "9007199254740992",
    "c340000000000000" = "-9007199254740992",
    "4430000000000000" = "295147905179352830000",
    "44b52d02c7e14af5" = "9.999999999999997e+22",
    "44b52d02c7e14af6" = "1e+23",
    "44b52d02c7e14af7" = "1.0000000000000001e+23",
    "444b1ae4d6e2ef4e" = "999999999999999700000",
    "444b1ae4d6e2ef4f" = "999999999999999900000",
    "444b1ae4d6e2ef50" = "1e+21",
    "3eb0c6f7a0b5ed8c" = "9.999999999999997e-7",
    "3eb0c6f7a0b5ed8d" = "0.000001",
    "41b3de4355555553" = "333333333.3333332",
    "41b3de4355555554" = "333333333.33333325",
    "41b3de4355555555" = "333333333.3333333",
    "41b3de4355555556" = "333333333.3333334",
    "41b3de4355555557" = "333333333.33333343",
    "becbf647612f3696" = "-0.0000033333333333333333",
    "43143ff3c1cb0959" = "1424953923781206.2"
  )
  x <- vapply(names(samples), from_bits, 0)
  expect_identical(crate:::jcs_numbers(unname(x)), unname(samples))
  # One at a time too, through the serializer
  for (h in names(samples)) expect_identical(crate:::crt_receipt_jcs(from_bits(h)), samples[[h]], info = h)
})

test_that("whole numbers and integers", {
  expect_identical(crate:::crt_receipt_jcs(100), "100")
  expect_identical(crate:::crt_receipt_jcs(100L), "100")
  expect_identical(crate:::crt_receipt_jcs(-7L), "-7")
  expect_identical(crate:::crt_receipt_jcs(4.50), "4.5")
  # Above 2^53, the shortest digits padded with zeros, not the exact integer
  expect_identical(crate:::crt_receipt_jcs(2^60), "1152921504606847000")
  expect_identical(crate:::crt_receipt_jcs(1e-7), "1e-7")
  expect_identical(crate:::crt_receipt_jcs(1e-6), "0.000001")
})

test_that("object keys sort by UTF-16 code units (RFC 8785 3.2.3)", {
  x <- list(
    "\u20ac" = "Euro Sign",
    "\r" = "Carriage Return",
    "\ufb33" = "Hebrew Letter Dalet With Dagesh",
    "1" = "One",
    "\U0001F600" = "Emoji: Grinning Face",
    "\u0080" = "Control",
    "\u00f6" = "Latin Small Letter O With Diaeresis"
  )
  want <- paste0(
    "{\"\\r\":\"Carriage Return\",\"1\":\"One\",\"\u0080\":\"Control\",",
    "\"\u00f6\":\"Latin Small Letter O With Diaeresis\",\"\u20ac\":\"Euro Sign\",",
    "\"\U0001F600\":\"Emoji: Grinning Face\",\"\ufb33\":\"Hebrew Letter Dalet With Dagesh\"}"
  )
  expect_identical(crate:::crt_receipt_jcs(x), enc2utf8(want))
  # The emoji sorts below U+FB33 only in UTF-16 order; code-point order puts it last.
  expect_lt(regexpr("\U0001F600", crate:::crt_receipt_jcs(x)),
            regexpr("\ufb33", crate:::crt_receipt_jcs(x)))
})

test_that("strings escape only what JSON requires", {
  s <- "\u0001\u001f\u007f\u2028\b\t\n\f\r\"\\/"
  want <- "\"\\u0001\\u001f\u007f\u2028\\b\\t\\n\\f\\r\\\"\\\\/\""
  expect_identical(crate:::crt_receipt_jcs(s), enc2utf8(want))
  expect_identical(crate:::crt_receipt_jcs("caf\u00e9"), enc2utf8("\"caf\u00e9\""))
})

test_that("R values map as jsonlite's auto_unbox does", {
  expect_identical(crate:::crt_receipt_jcs(NULL), "null")
  expect_identical(crate:::crt_receipt_jcs(NA), "null")
  expect_identical(crate:::crt_receipt_jcs(c(TRUE, FALSE)), "[true,false]")
  expect_identical(crate:::crt_receipt_jcs(I("a")), "[\"a\"]")
  expect_identical(crate:::crt_receipt_jcs(character()), "[]")
  expect_identical(crate:::crt_receipt_jcs(list()), "[]")
  expect_identical(crate:::crt_receipt_jcs(setNames(list(), character())), "{}")
  expect_identical(crate:::crt_receipt_jcs(list(b = list(d = 1L, c = NA), a = list(1, "x"))),
                   "{\"a\":[1,\"x\"],\"b\":{\"c\":null,\"d\":1}}")
  expect_identical(crate:::crt_receipt_jcs(factor("lvl")), "\"lvl\"")
})

test_that("the serializer refuses what has no single JSON spelling", {
  expect_error(crate:::crt_receipt_jcs(NaN), "NaN or infinite")
  expect_error(crate:::crt_receipt_jcs(list(a = Inf)), "NaN or infinite")
  expect_error(crate:::crt_receipt_jcs(list(a = 1, a = 2)), "repeated key")
  expect_error(crate:::crt_receipt_jcs(Sys.Date()), "ISO 8601")
  expect_error(crate:::crt_receipt_jcs(list(f = mean)), "no JSON form")
  expect_error(crate:::crt_receipt_jcs(rawToChar(as.raw(0xff))), "not valid UTF-8")
})

test_that("values that would lose meaning are refused, not written", {
  # An integer64's storage is its bits read as a double: 42 would be 2.07e-322
  expect_error(crate:::crt_receipt_jcs(list(rows = structure(2.0750757125332355e-322, class = "integer64"))),
               "integer64")
  # Names would be dropped, so two different settings would hash alike
  expect_error(crate:::crt_receipt_jcs(list(t = c(CO = 0.05, CH = 0.07))), "named vector")
  expect_error(crate:::crt_receipt_jcs(c(a = 1)), "named vector")
  expect_identical(crate:::crt_receipt_jcs(list(t = as.list(c(CO = 0.05, CH = 0.07)))),
                   "{\"t\":{\"CH\":0.07,\"CO\":0.05}}")
})

# Validity is decided before any conversion, so a C session cannot turn a bad byte
# into the text "<e9>" and hash that.
test_that("a string that is not UTF-8 is refused in every locale; latin1 marked is converted", {
  bad <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xe9)))
  for (loc in c("C", "en_US.UTF-8")) {
    expect_error(withr::with_locale(c(LC_CTYPE = loc), crate:::crt_receipt_jcs(bad)), "not valid UTF-8",
                 info = loc)
  }
  marked <- bad
  Encoding(marked) <- "latin1"
  for (loc in c("C", "en_US.UTF-8")) {
    expect_identical(withr::with_locale(c(LC_CTYPE = loc), charToRaw(crate:::crt_receipt_jcs(marked))),
                     charToRaw(enc2utf8("\"caf\u00e9\"")), info = loc)
  }
})

test_that("the serialization does not depend on the locale", {
  x <- list(b = "\u00e9", "\u00e9" = 1.5, a = c(0.1, 1e21))
  a <- crate:::crt_receipt_jcs(x)
  b <- withr::with_locale(c(LC_COLLATE = "C", LC_CTYPE = "C"), crate:::crt_receipt_jcs(x))
  expect_identical(a, b)
})

test_that("recipe_id hashes the recipe without its own recipe_id", {
  recipe <- list(code = setNames(list(), character()), config = list(
    files = setNames(list(), character()), settings = setNames(list(), character())
  ), inputs = setNames(list(), character()), seed = NULL)
  id <- crate:::crt_receipt_recipe_id(recipe)
  expect_match(id, "^[0-9a-f]{64}$")
  # The JCS bytes are {"code":{},"config":{"files":{},"settings":{}},"inputs":{},"seed":null}
  expect_identical(
    id,
    digest::digest(charToRaw('{"code":{},"config":{"files":{},"settings":{}},"inputs":{},"seed":null}'),
                   algo = "sha256", serialize = FALSE)
  )
  recipe$recipe_id <- strrep("0", 64)
  expect_identical(crate:::crt_receipt_recipe_id(recipe), id)
  # Member order does not matter; a value does.
  expect_identical(crate:::crt_receipt_recipe_id(rev(recipe)), id)
  recipe$seed <- 1L
  expect_false(identical(crate:::crt_receipt_recipe_id(recipe), id))
  expect_error(crate:::crt_receipt_recipe_id(list(1)), "named list")
})
