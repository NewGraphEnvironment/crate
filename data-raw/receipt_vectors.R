# data-raw/receipt_vectors.R
#
# Writes the receipt test vectors to inst/extdata/receipt/vectors/v1.0.0/ (#43).
#
# The vectors are the contract's executable half: every implementation of the receipt
# (crate in R, stacs in Python, anything else) runs the same files and must produce
# every expected value byte for byte. crate's tests run them in
# tests/testthat/test-crt_receipt_vectors.R; data-raw/receipt_vectors_crosscheck.py
# recomputes them with Python's rfc8785 and an independent implementation of the table
# canonical form.
#
# A released vector set is frozen with its schema version: change a vector only by
# adding a new version directory. Re-running this script must leave the files byte for
# byte as committed, which the vectors test checks for the expected values.
#
# Formats (all files UTF-8 JSON, one array of cases each):
#
#   numbers.json      {name, bits, expected}
#                     bits: the IEEE 754 double as 16 hex digits, big-endian
#                     expected: its RFC 8785 spelling
#   jcs.json          {name, input_json, expected}
#                     input_json: JSON text to parse with the implementation's own parser
#                     expected: the RFC 8785 serialization of the parsed value
#   recipe_id.json    {name, recipe_json, jcs, recipe_id}
#                     recipe_json: a recipe block as JSON text (it may carry a recipe_id,
#                     which the hash leaves out)
#   compare.json      {name, a, b, verdict, differences}; see the compare section below
#   fingerprint.json  {name, table, tolerance, canonical, sha256}
#                     table: {"columns": {<name>: {"type": <t>, "values": [...]}}}, with
#                     t one of character, integer, double, logical, date, datetime.
#                     Doubles are given as bits (as in numbers.json), dates as
#                     "YYYY-MM-DD", datetimes as "YYYY-MM-DDTHH:MM:SSZ", NA as null.
#                     tolerance: {<column>: <power of ten>}, or {}
#
# Run from the package root: Rscript data-raw/receipt_vectors.R

devtools::load_all(quiet = TRUE)

out_dir <- file.path("inst", "extdata", "receipt", "vectors", "v1.0.0")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

bits_of <- function(x) {
  vapply(x, function(v) {
    paste(as.character(writeBin(v, raw(), size = 8, endian = "big")), collapse = "")
  }, "", USE.NAMES = FALSE)
}

from_bits <- function(hex) {
  vapply(hex, function(h) {
    readBin(as.raw(strtoi(substring(h, seq(1, 15, 2), seq(2, 16, 2)), 16L)), "double",
            size = 8, endian = "big")
  }, 0, USE.NAMES = FALSE)
}

write_vectors <- function(cases, file) {
  path <- file.path(out_dir, file)
  txt <- jsonlite::toJSON(cases, auto_unbox = TRUE, pretty = TRUE, null = "null",
                          na = "null", digits = NA)
  writeLines(enc2utf8(as.character(txt)), path, useBytes = TRUE)
  message("wrote ", path, " (", length(cases), " cases)")
}

# ---- numbers ---------------------------------------------------------------------
# RFC 8785 Appendix B, the spelling boundaries, and 500 random doubles.
appendix_b <- c(
  "0000000000000000", "8000000000000000", "0000000000000001", "8000000000000001",
  "7fefffffffffffff", "ffefffffffffffff", "4340000000000000", "c340000000000000",
  "4430000000000000", "44b52d02c7e14af5", "44b52d02c7e14af6", "44b52d02c7e14af7",
  "444b1ae4d6e2ef4e", "444b1ae4d6e2ef4f", "444b1ae4d6e2ef50", "3eb0c6f7a0b5ed8c",
  "3eb0c6f7a0b5ed8d", "41b3de4355555553", "41b3de4355555554", "41b3de4355555555",
  "41b3de4355555556", "41b3de4355555557", "becbf647612f3696", "43143ff3c1cb0959"
)
boundaries <- c(1, -1, 0.1, 100, 1e20, 1e21, 1e-6, 1e-7, 2^53, 2^53 + 2, 2^60,
                0.5, 4.5, 1 / 3, 2.2250738585072014e-308)
set.seed(43)
random <- local({
  r <- readBin(as.raw(sample(0:255, 8 * 600, replace = TRUE)), "double", n = 600,
               size = 8, endian = "big")
  head(r[is.finite(r)], 500)
})
num_bits <- c(appendix_b, bits_of(boundaries), bits_of(random))
num_names <- c(paste0("rfc8785 appendix B ", appendix_b), paste0("boundary ", sprintf("%.17g", boundaries)),
               paste0("random ", seq_along(random)))
numbers <- Map(function(n, b, e) list(name = n, bits = b, expected = e),
               num_names, num_bits, crate:::jcs_numbers(from_bits(num_bits)))
write_vectors(unname(numbers), "numbers.json")

# ---- jcs -------------------------------------------------------------------------
jcs_inputs <- list(
  "rfc8785 3.2.2 sample" = paste0(
    '{"numbers":[333333333.33333329,1E30,4.50,2e-3,0.000000000000000000000000001],',
    '"string":"\\u20ac$\\u000F\\u000aA\'\\u0042\\u0022\\u005c\\\\\\"\\/",',
    '"literals":[null,true,false]}'
  ),
  "rfc8785 3.2.3 key order" = paste0(
    '{"\\u20ac":"Euro Sign","\\r":"Carriage Return","\\ufb33":"Hebrew Letter Dalet With Dagesh",',
    '"1":"One","\\ud83d\\ude00":"Emoji: Grinning Face","\\u0080":"Control",',
    '"\\u00f6":"Latin Small Letter O With Diaeresis"}'
  ),
  "escaping" = '{"s":"\\u0001\\u001f\\u007f\\u2028\\b\\t\\n\\f\\r\\"\\\\/"}',
  "empty containers and literals" = '{"a":{},"b":[],"c":null,"d":true,"e":false,"f":""}',
  "nested, unsorted at every level" = '{"z":{"b":[{"d":1,"c":2}],"a":0},"y":[3,[2,[1]]]}',
  "integers and whole doubles" = '{"n":[0,-0,1,-1,100,1.0,4.50,1e2,9007199254740992]}',
  "number spelling boundaries" = '{"n":[1e20,1e21,1e-6,1e-7,0.1,1152921504606846976,5e-324]}',
  "non-ASCII text" = '{"caf\\u00e9":"\\u00e9t\\u00e9","emoji":"\\ud83d\\ude00","cjk":"\\u6c34"}',
  "scalar string" = '"top-level string"',
  "scalar number" = "333333333.33333329"
)
jcs <- Map(function(n, txt) {
  list(name = n, input_json = txt,
       expected = crate:::crt_receipt_jcs(jsonlite::parse_json(txt, simplifyVector = FALSE)))
}, names(jcs_inputs), jcs_inputs)
write_vectors(unname(jcs), "jcs.json")

# ---- recipe_id -------------------------------------------------------------------
recipe_inputs <- list(
  "empty recipe" =
    '{"code":{},"config":{"files":{},"settings":{}},"inputs":{},"seed":null}',
  "worked case" = paste0(
    '{"code":{"knowledge":{"commit":"3f1c2a9e8b7d6c5f4e3d2c1b0a9f8e7d6c5b4a39","version":"0.14.0","dirty":false},',
    '"link":{"commit":"a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0","version":"0.31.2","dirty":false}},',
    '"config":{"files":{"inst/method/settings.csv":',
    '"5d41402abc4b2a76b9719d911017c592ae2f7c1b7b0c3c1b2f6d4e5a6b7c8d9e"},',
    '"settings":{"species":["CO","CH","ST"],"watershed_group":"BULK"}},',
    '"inputs":{"flow":{"recipe_id":"0d6f1c9a8e7b5d4c3a2f1e0d9c8b7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e2d1c0b"},',
    '"fwa_stream_networks":{"version_id":"3HL4kqtJlcpXroDTDmJ.rmSpXd3dIbrHY"}},',
    '"seed":null}'
  ),
  "worked case, members in another order" = paste0(
    '{"seed":null,"inputs":{"fwa_stream_networks":{"version_id":"3HL4kqtJlcpXroDTDmJ.rmSpXd3dIbrHY"},',
    '"flow":{"recipe_id":"0d6f1c9a8e7b5d4c3a2f1e0d9c8b7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e2d1c0b"}},',
    '"config":{"settings":{"watershed_group":"BULK","species":["CO","CH","ST"]},',
    '"files":{"inst/method/settings.csv":"5d41402abc4b2a76b9719d911017c592ae2f7c1b7b0c3c1b2f6d4e5a6b7c8d9e"}},',
    '"code":{"link":{"dirty":false,"version":"0.31.2","commit":"a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0"},',
    '"knowledge":{"version":"0.14.0","dirty":false,"commit":"3f1c2a9e8b7d6c5f4e3d2c1b0a9f8e7d6c5b4a39"}}}'
  ),
  "worked case carrying its own recipe_id, which the hash leaves out" = paste0(
    '{"code":{},"config":{"files":{},"settings":{}},"inputs":{},"seed":null,',
    '"recipe_id":"0000000000000000000000000000000000000000000000000000000000000000"}'
  ),
  "a seed makes another recipe" =
    '{"code":{},"config":{"files":{},"settings":{}},"inputs":{},"seed":20261105}',
  "inputs with no receipt" = paste0(
    '{"code":{},"config":{"files":{},"settings":{}},"inputs":{',
    '"dem":{"sha256":"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"},',
    '"lulc":{"none":"live Planetary Computer collection, not versioned"}},"seed":null}'
  ),
  "settings with numbers and non-ASCII keys" = paste0(
    '{"code":{},"config":{"files":{},"settings":{"r\\u00e9gion":"Skeena","threshold":0.1,',
    '"max_km":1e21,"orders":[3,4,5],"dry_run":false,"label":null}},"inputs":{},"seed":null}'
  )
)
recipes <- Map(function(n, txt) {
  r <- jsonlite::parse_json(txt, simplifyVector = FALSE)
  rr <- r
  rr[["recipe_id"]] <- NULL
  list(name = n, recipe_json = txt, jcs = crate:::crt_receipt_jcs(rr),
       recipe_id = crate:::crt_receipt_recipe_id(r))
}, names(recipe_inputs), recipe_inputs)
write_vectors(unname(recipes), "recipe_id.json")

# ---- fingerprint -----------------------------------------------------------------
# Each case is built as an R data frame, then encoded in the language-neutral form.
encode_table <- function(df) {
  cols <- lapply(df, function(v) {
    if (inherits(v, "Date")) {
      list(type = "date", values = as.list(ifelse(is.na(v), NA, format(v, "%Y-%m-%d"))))
    } else if (inherits(v, "POSIXct")) {
      list(type = "datetime",
           values = as.list(ifelse(is.na(v), NA, format(v, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))))
    } else if (is.character(v)) {
      list(type = "character", values = as.list(v))
    } else if (is.integer(v)) {
      list(type = "integer", values = as.list(v))
    } else if (is.logical(v)) {
      list(type = "logical", values = as.list(v))
    } else if (is.double(v)) {
      list(type = "double", values = as.list(ifelse(is.na(v), NA, bits_of(v))))
    } else {
      stop("no vector encoding for ", class(v)[1])
    }
  })
  list(columns = cols)
}

worked_a <- data.frame(segment = c("s1", "s2", "s3"), km = c(12.3456789012, 7.25, 0.0400000001),
                       n = c(3L, 0L, 12L))
worked_b <- worked_a[c(2, 3, 1), c("n", "km", "segment")]
worked_b$km[worked_b$segment == "s1"] <- worked_b$km[worked_b$segment == "s1"] + 9.5e-11

fp_cases <- list(
  list("mixed types", data.frame(
    id = c("b", "a", "c"), n = c(2L, NA, 1L), v = c(1.5, 0.1, NA), ok = c(TRUE, FALSE, NA),
    d = as.Date(c("2026-11-04", NA, "1999-12-31")),
    t = as.POSIXct(c("2026-11-04 18:22:05", "1970-01-01 00:00:00", NA), tz = "UTC")
  ), list()),
  list("worked case, first build, exact", worked_a, list()),
  list("worked case, second build, exact", worked_b, list()),
  list("worked case, first build, km to 1e-9", worked_a, list(km = 1e-9)),
  list("worked case, second build, km to 1e-9", worked_b, list(km = 1e-9)),
  list("rounding ties to even on the binary value",
       data.frame(v = c(0.5, 1.5, 2.5, 0.125, 0.375, 1.0000000005, 2.675)), list(v = 1)),
  list("same, to 2 decimals",
       data.frame(v = c(0.5, 1.5, 2.5, 0.125, 0.375, 1.0000000005, 2.675)), list(v = 0.01)),
  list("signed zeros", data.frame(v = c(-0, 0, -0.001, -0.4)), list()),
  list("signed zeros, rounded", data.frame(v = c(-0, 0, -0.001, -0.4)), list(v = 1)),
  list("NA, empty and the string NA", data.frame(s = c(NA, "", "NA", "null")), list()),
  list("row order is byte order", data.frame(
    s = c("été", "Zed", "apple", "\U0001F600", "水", "a b", "a")
  ), list()),
  list("number spellings without a tolerance",
       data.frame(v = c(1e21, 1e20, 1e-7, 1e-6, 2^60, 1 / 3, 100)), list()),
  list("an empty table", data.frame(a = character(), b = numeric()), list())
)
fingerprints <- lapply(fp_cases, function(cs) {
  tol <- cs[[3]]
  list(name = cs[[1]], table = encode_table(cs[[2]]),
       tolerance = if (length(tol)) tol else setNames(list(), character()),
       canonical = crate:::table_canonical(cs[[2]], tol),
       sha256 = crt_table_fingerprint(cs[[2]], tol))
})
write_vectors(fingerprints, "fingerprint.json")

# ---- compare ---------------------------------------------------------------------
# Receipt pairs and what crt_receipt_compare() makes of them from the receipts alone.
# Built from the worked case, so run data-raw/receipt_examples.R first.
#
#   compare.json      {name, a, b, verdict, differences}
#                     a, b: receipts; differences: [{field, action}], sorted by field.
#                     A field is block.member, with a key in a keyed collection in
#                     brackets: result.parts[access_check.csv].sha256
wc <- file.path("inst", "extdata", "receipt", "examples", "worked_case")
b1 <- crt_receipt_read(file.path(wc, "build_1"))
b2 <- crt_receipt_read(file.path(wc, "build_2"))
pair <- function(name, a, b) {
  x <- crt_receipt_compare(a, b)
  d <- x$differences[order(x$differences$field, method = "radix"), c("field", "action")]
  list(name = name, a = a, b = b, verdict = x$verdict,
       differences = lapply(seq_len(nrow(d)), function(i) as.list(d[i, ])))
}
other_setting <- b2
other_setting$recipe$config$settings$watershed_group <- "MORR"
other_setting$recipe$recipe_id <- crate:::crt_receipt_recipe_id(other_setting$recipe)
other_seed <- b1
other_seed$recipe$seed <- 20261105L
other_seed$recipe$recipe_id <- crate:::crt_receipt_recipe_id(other_seed$recipe)
untabled <- function(r) {
  r$result$parts$access_check.csv$table <- NULL
  r
}
past_tolerance <- b2
past_tolerance$result$summary$km_total <- b2$result$summary$km_total + 0.01
moved_fingerprint <- b2
moved_fingerprint$result$fingerprint$access_check$sha256 <-
  crt_table_fingerprint(data.frame(segment = "S010", accessible = TRUE, km = 1), list(km = 1e-9))
migrated <- b2
migrated$output$migrated_from <- "manifest.json"
migrated$recipe <- list(code = list(link = list(commit = "a9b8c7d")), recipe_id = NULL)
toolchain <- b1
toolchain$context$toolchain$GDAL <- "3.9.2"

compare <- list(
  pair("worked case: one recipe, km within tolerance", b1, b2),
  pair("a receipt and itself", b1, b1),
  pair("toolchain only", b1, toolchain),
  pair("another run setting", b1, other_setting),
  pair("another seed", b1, other_seed),
  pair("bytes moved in a file that names no table", untabled(b1), untabled(b2)),
  pair("summary value past its tolerance", b1, past_tolerance),
  pair("fingerprints differ, receipts only", b1, moved_fingerprint),
  pair("a migrated receipt", b1, migrated)
)
write_vectors(compare, "compare.json")
