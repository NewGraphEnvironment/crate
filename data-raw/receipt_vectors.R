# data-raw/receipt_vectors.R
#
# Writes the receipt test vectors (#43): the hashing vectors to
# inst/extdata/receipt/vectors/v1.0.0/, versioned with the receipt form, and compare.json
# to inst/extdata/receipt/register/v1.0.0/, versioned with the register whose actions it
# records (#58).
#
# The vectors are the contract's executable half: every implementation of the receipt
# (crate in R, stacs in Python, anything else) runs the same files and must produce
# every expected value byte for byte. crate's tests run them in
# tests/testthat/test-crt_receipt_vectors.R; data-raw/receipt_vectors_crosscheck.py
# recomputes them with Python's rfc8785 and an independent implementation of the table
# canonical form.
#
# A released vector set is frozen with its version (the form's, or for compare.json the
# register's): change a vector only by adding a new version directory. Re-running this
# script must leave the files byte for byte as committed, which the vectors test checks
# for the expected values.
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

out_dir <- file.path("inst", "extdata", "receipt", "vectors", paste0("v", crate:::receipt_version()))
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

register_dir <- file.path("inst", "extdata", "receipt", "register",
                          paste0("v", crate:::receipt_register_version()))

# A released file is never rewritten: a regeneration that would change its bytes stops
# here, so a code change that moves an expected value needs a new version directory (a
# new version constant), not an edit (#58).
write_vectors <- function(cases, file, dir = out_dir) {
  path <- file.path(dir, file)
  txt <- jsonlite::toJSON(cases, auto_unbox = TRUE, pretty = TRUE, null = "null",
                          na = "null", digits = NA)
  txt <- gsub("\"__crate_empty_key__\"", "\"\"", txt, fixed = TRUE)
  new <- tempfile(fileext = ".json")
  writeLines(enc2utf8(as.character(txt)), new, useBytes = TRUE)
  if (file.exists(path) && !identical(unname(tools::md5sum(path)), unname(tools::md5sum(new)))) {
    stop(path, " is released and this run would change it. Add a version directory ",
         "(bump the version constant) instead of rewriting a released file.", call. = FALSE)
  }
  file.copy(new, path, overwrite = TRUE)
  message("wrote ", path, " (", length(cases), " cases)")
}

# ---- numbers ---------------------------------------------------------------------
# RFC 8785 Appendix B, the spelling boundaries, 500 random doubles and every power of two.
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
# Every power of two: there the decimals that read back extend twice as far above the
# double as below, and the shortest spelling is sometimes not printf's rounding
# (2^-24 is 5.960464477539063e-8, where printf's 16 digits end in 2).
pow2 <- 2^(-1074:1023)
num_bits <- c(appendix_b, bits_of(boundaries), bits_of(random), bits_of(pow2))
num_names <- c(paste0("rfc8785 appendix B ", appendix_b), paste0("boundary ", sprintf("%.17g", boundaries)),
               paste0("random ", seq_along(random)), paste0("2^", -1074:1023))
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
write_vectors(compare, "compare.json", dir = register_dir)

# ---- stac ------------------------------------------------------------------------
# The STAC rows of the receipt mapping, as crt_receipt_stac() executes them (#59, #60).
# Versioned with the mapping, in inst/extdata/receipt/mapping/v<mapping version>/.
#
#   stac.json         {name, receipt, assets, receipt_asset, receipt_sha256, expected, error}
#                     receipt: a receipt; assets: {<asset key>: <href relative to the item>}
#                     receipt_asset, receipt_sha256: the receipt asset's key and the digest of
#                     the published receipt's bytes, or null
#                     expected: {stac_extensions, properties, assets}, compared as canonical
#                     JSON; null where the case is refused
#                     error: null, or a short code naming what is refused. Implementations'
#                     messages differ, so a runner checks only that the case is refused.
#                     A case refused for a field value carries a receipt invalid in that
#                     field alone; every other case's receipt is valid
mapping_dir <- file.path("inst", "extdata", "receipt", "mapping",
                         paste0("v", crate:::receipt_mapping_version()))
b1_sha256 <- digest::digest(file.path(wc, "build_1", "receipt.json"), algo = "sha256", file = TRUE)
# A receipt edited here keeps a recipe_id that matches its recipe, so every case is a
# valid receipt and only the mapping decides it.
rehash <- function(r) {
  r$recipe$recipe_id <- crate:::crt_receipt_recipe_id(r$recipe)
  r
}
no_link_version <- b1
no_link_version$recipe$code$link["version"] <- list(NULL)
no_link_version <- rehash(no_link_version)
no_versions <- no_link_version
no_versions$recipe$code$knowledge["version"] <- list(NULL)
no_versions <- rehash(no_versions)
migrated_path <- file.path(tempdir(), "migrated_receipt.json")
crt_receipt_migrate(file.path("inst", "extdata", "receipt", "examples", "legacy", "link_manifest.json"),
                    "link manifest.json", path = migrated_path)
migrated_receipt <- crt_receipt_read(migrated_path)
stopifnot(is.null(migrated_receipt$recipe$recipe_id))

# One value set to one the mapping must refuse: NULL deletes the key, json_null writes a
# null. A change inside the recipe gets a recipe_id that matches it, so the case is refused
# for that value alone and not for a stale identity.
json_null <- quote(json_null)
bad <- function(r, path, value) {
  if (is.symbol(value)) {
    n <- length(path)
    if (n == 1) {
      r[path] <- list(NULL)
    } else {
      parent <- r[[path[-n]]]
      parent[path[n]] <- list(NULL)
      r[[path[-n]]] <- parent
    }
  } else {
    r[[path]] <- value
  }
  if (length(path) > 1 && path[1] == "recipe" && !identical(path, c("recipe", "recipe_id"))) r <- rehash(r)
  r
}
no_assets <- stats::setNames(list(), character())
stac_case <- function(name, receipt, assets = NULL, receipt_asset = NULL, receipt_sha256 = NULL,
                      error = NULL) {
  out <- tryCatch(
    crt_receipt_stac(receipt, assets = if (length(assets)) unlist(assets), receipt_asset = receipt_asset,
                     receipt_sha256 = receipt_sha256),
    error = function(e) e
  )
  refused <- inherits(out, "error")
  if (refused != !is.null(error)) {
    stop("stac case '", name, "': ", if (refused) paste("refused:", conditionMessage(out)) else "not refused",
         call. = FALSE)
  }
  list(name = name, receipt = receipt, assets = if (length(assets)) as.list(assets) else no_assets,
       receipt_asset = receipt_asset, receipt_sha256 = receipt_sha256,
       expected = if (!refused) out, error = error)
}
# One case per malformed value of one field, named for the field and the way it is malformed
field_cases <- function(path, error, assets, values) {
  lapply(names(values), function(how) {
    stac_case(paste0(paste(path, collapse = "."), " ", how, ": refused"), bad(b1, path, values[[how]]), assets,
              error = error)
  })
}
# jsonlite writes an empty key as its position ("3"), so the case carries a sentinel that
# write_vectors() turns back into "" in the JSON text
empty_key <- function(case) {
  nm <- names(case$receipt$recipe$code)
  names(case$receipt$recipe$code)[nm == ""] <- "__crate_empty_key__"
  case
}
# A repository added to recipe.code under a name `[[<-` cannot write, such as ""
within_code <- function(r, name, entry) {
  r$recipe$code <- c(r$recipe$code, stats::setNames(list(entry), name))
  r
}
all_parts <- list(access = "access_check.csv", visits_link = "visits_link.csv",
                  visits_species = "visits_species.csv", walks = "walks.csv")
stac <- list(
  stac_case("worked case: every part, and the receipt asset", b1, all_parts, "receipt", b1_sha256),
  stac_case("no assets: no part is mirrored", b1),
  stac_case("a part with no asset is not mirrored", b1, list(access = "access_check.csv")),
  stac_case("two assets name one part", b1, list(a = "walks.csv", b = "walks.csv")),
  stac_case("the receipt asset alone: file:checksum, no file:size", b1, NULL, "receipt", b1_sha256),
  stac_case("a migrated receipt: no receipt:recipe_id, never a null one", migrated_receipt),
  stac_case("a repository with no version is left out of processing:software", no_link_version),
  stac_case("no repository has a version: no processing:software", no_versions),
  stac_case("an asset whose href names no part is refused", b1, list(data = "floodplain.tif"),
            error = "href_not_a_part"),
  stac_case("a receipt asset needs its digest", b1, NULL, "receipt", error = "receipt_asset_without_digest"),
  stac_case("a digest needs a receipt asset", b1, NULL, NULL, b1_sha256, error = "digest_without_receipt_asset"),
  stac_case("the receipt asset's key is not also a part's asset", b1, list(receipt = "walks.csv"), "receipt",
            b1_sha256, error = "receipt_asset_in_assets"),
  stac_case("a digest is 64 lower-case hex", b1, NULL, "receipt", toupper(b1_sha256),
            error = "digest_not_sha256"),
  stac_case("a digest with a trailing newline is not 64 lower-case hex", b1, NULL, "receipt",
            paste0(b1_sha256, "\n"), error = "digest_not_sha256"),
  stac_case("a digest given as a number is not 64 lower-case hex", b1, NULL, "receipt", 1L,
            error = "digest_not_sha256"),
  # A value the item would publish is checked before it is mirrored: these receipts are
  # invalid on purpose, one field each, so an implementation cannot publish what the field
  # schema or a reader would refuse
  # Per value, one case for each way it can be malformed: the wrong type, empty, a trailing
  # newline (which a `$` pattern lets through), non-ASCII digits, upper case, out of range
  field_cases(c("recipe", "recipe_id"), "recipe_id_not_sha256", NULL,
              list(`not a SHA-256` = "abc", `upper case` = toupper(b1$recipe$recipe_id),
                   `followed by a newline` = paste0(b1$recipe$recipe_id, "\n"), `a number` = 1L)),
  # Only a migrated receipt has no recipe identity, and it never has one
  field_cases(c("recipe", "recipe_id"), "recipe_id_missing", NULL,
              list(`missing on a receipt not migrated` = NULL, `null on a receipt not migrated` = json_null)),
  stac_case("recipe.recipe_id set on a migrated receipt: refused",
            bad(migrated_receipt, c("recipe", "recipe_id"), b1$recipe$recipe_id), error = "recipe_id_on_migrated"),
  field_cases(c("context", "time"), "time_not_utc", NULL,
              list(`with a space for T` = "2026-11-04 18:22:05", `with an offset for Z` = "2026-11-04T18:22:05+00:00",
                   `followed by a newline` = "2026-11-04T18:22:05Z\n",
                   `in Arabic-Indic digits` = "\u0662\u0660\u0662\u0666-11-04T18:22:05Z", `a number` = 1L,
                   `missing` = NULL, `null` = json_null)),
  field_cases(c("recipe", "code", "link", "version"), "version_not_string", NULL,
              list(`a number` = 1L, `empty` = "", `true` = TRUE)),
  field_cases(c("result", "parts", "walks.csv", "bytes"), "bytes_not_whole", list(walks = "walks.csv"),
              list(`fractional` = 1.5, `negative` = -1L, `a string` = "124", `true` = TRUE, `missing` = NULL)),
  field_cases(c("result", "parts", "walks.csv", "sha256"), "part_sha256_not_sha256", list(walks = "walks.csv"),
              list(`not hex` = "zz", `upper case` = toupper(b1$result$parts$walks.csv$sha256),
                   `followed by a newline` = paste0(b1$result$parts$walks.csv$sha256, "\n"), `missing` = NULL)),
  # A block or entry that is present but not an object is refused, never read as absent:
  # an item stripped of its identity would pass for one with none
  stac_case("the receipt an array: refused", list(b1$output), error = "block_not_object"),
  stac_case("the receipt null: refused", NULL, error = "block_not_object"),
  field_cases("output", "block_not_object", NULL, list(`an array` = list("x"), `null` = json_null)),
  field_cases("recipe", "block_not_object", NULL, list(`null` = json_null)),
  field_cases("context", "block_not_object", NULL, list(`null` = json_null)),
  field_cases(c("result", "parts"), "block_not_object", NULL, list(`null` = json_null)),
  field_cases(c("recipe", "code", "link"), "block_not_object", NULL, list(`null` = json_null)),
  field_cases(c("result", "parts", "walks.csv"), "block_not_object", list(walks = "walks.csv"),
              list(`null` = json_null)),
  # Published keys: a repository's name keys processing:software, and receipt_asset an asset
  empty_key(stac_case("a repository with an empty name: refused",
                      rehash(within_code(b1, "", list(commit = strrep("c", 40), dirty = FALSE, version = "9.9"))),
                      error = "repo_name_empty")),
  stac_case("an empty receipt_asset: refused", b1, NULL, "", b1_sha256, error = "receipt_asset_empty"),
  field_cases("recipe", "block_not_object", NULL, list(`an array` = list(b1$recipe$recipe_id))),
  field_cases("result", "block_not_object", NULL, list(`a string` = "parts")),
  field_cases(c("recipe", "code"), "block_not_object", NULL,
              list(`an array` = list(b1$recipe$code$link), `a string` = "link", `null` = json_null)),
  field_cases(c("recipe", "code", "link"), "block_not_object", NULL,
              list(`a string` = "0.31.2")),
  field_cases(c("context"), "block_not_object", NULL, list(`a string` = "")),
  field_cases(c("result", "parts"), "block_not_object", NULL, list(`an array` = list())),
  field_cases(c("result", "parts", "walks.csv"), "block_not_object", list(walks = "walks.csv"),
              list(`a string` = "walks.csv"))
)
# field_cases() returns a list of cases: splice each in where it stands
stac <- do.call(c, lapply(stac, function(x) if (is.null(names(x))) x else list(x)))
write_vectors(stac, "stac.json", dir = mapping_dir)
