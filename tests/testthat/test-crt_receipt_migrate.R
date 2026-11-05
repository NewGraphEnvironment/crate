# Reading older records as receipts through the mapping table (#43).

legacy_path <- function(file) {
  system.file("extdata", "receipt", "examples", "legacy", file, package = "crate", mustWork = TRUE)
}

test_that("link's manifest migrates to a receipt with no recipe identity", {
  skip_if_not_installed("jsonvalidate")
  expect_no_warning(r <- crt_receipt_migrate(legacy_path("link_manifest.json"), "link manifest.json"))
  expect_true(crt_receipt_validate(r))
  expect_identical(r$output$name, "habitat/fwa/v1")
  expect_identical(r$output$migrated_from, "link manifest.json")
  expect_null(r$recipe$recipe_id)
  expect_true("recipe_id" %in% names(r$recipe))
  expect_identical(r$recipe$code$link[c("commit", "version", "dirty")],
                   list(commit = "a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0", version = "0.31.2", dirty = FALSE))
  expect_identical(r$context$time, "2026-11-01T17:04:12Z")
  # Parts carry md5, not sha256, so they stay whole in legacy rather than half-mapped
  expect_setequal(names(r$context$legacy), c("manifest_version", "datasets", "configs", "parts", "files"))
  expect_identical(r$context$legacy$parts[[1]]$md5, "92eb5ffee6ae2fec3ad71c777531578f")
})

test_that("a floodplains section migrates with its settings, input digest and counts", {
  skip_if_not_installed("jsonvalidate")
  f <- crt_receipt_migrate(legacy_path("floodplains_provenance.json"), "floodplains provenance.json",
                           section = "floodplain/all_ff02")
  expect_true(crt_receipt_validate(f))
  expect_identical(f$output$name, "floodplain/all_ff02")
  expect_identical(f$output$scope, "BULK")
  expect_identical(f$recipe$code$flooded$commit, "698042e15fad5ac4d93ec0bd2353b68c45729046")
  expect_match(f$recipe$inputs$dem$sha256, "^[0-9a-f]{64}$")
  expect_identical(f$recipe$config$settings$scenario, "all_ff02")
  expect_identical(f$result$summary$valley_cells, 678786L)
  expect_identical(f$context$toolchain$gdal, "3.8.5")
  expect_identical(f$context$time, "2026-10-14T12:42:04Z")
  # Its own hashes are kept, never taken for a recipe_id or a fingerprint
  expect_match(f$context$legacy$inputs_hash, "^sha256:")
  expect_match(f$context$legacy$outputs.floodplain_content_sha256, "^sha256:")
  expect_identical(f$context$legacy$outputs.floodplain_raster, "floodplain_all_ff02.tif")
})

test_that("a network section migrates, and link's log row lands where it belongs", {
  skip_if_not_installed("jsonvalidate")
  fx <- legacy_path("floodplains_provenance.json")
  sec <- paste0("network/", names(jsonlite::read_json(fx)$network)[1])
  expect_no_warning(n <- crt_receipt_migrate(fx, "floodplains provenance.json", section = sec))
  expect_true(crt_receipt_validate(n))
  expect_true(all(c("link_run_id", "link_run_uid") %in% names(n$context$run)))
  expect_true("link_log.config_hash" %in% names(n$context$legacy))
  expect_true("habitat" %in% names(n$context$legacy))
  expect_match(n$recipe$inputs$network$sha256, "^[0-9a-f]{64}$")
})

test_that("a migrated receipt written with path reads back and validates", {
  skip_if_not_installed("jsonvalidate")
  dir <- withr::local_tempdir()
  r <- crt_receipt_migrate(legacy_path("link_manifest.json"), "link manifest.json", path = dir)
  back <- crt_receipt_read(dir)
  expect_identical(crate:::crt_receipt_jcs(back), crate:::crt_receipt_jcs(r))
  expect_true(crt_receipt_validate(back))
})

test_that("an unknown field is reported and kept, never dropped", {
  rec <- jsonlite::read_json(legacy_path("link_manifest.json"))
  rec$surprise <- list(answer = 42L)
  expect_warning(r <- crt_receipt_migrate(rec, "link manifest.json"), class = "crate_receipt_unmapped")
  expect_identical(r$context$legacy$surprise.answer, 42L)
})

test_that("two fields mapped to one key keep the first and do not lose the second", {
  rec <- jsonlite::read_json(legacy_path("link_manifest.json"))
  rec$link_sha <- "0000000000000000000000000000000000000000"
  r <- crt_receipt_migrate(rec, "link manifest.json")
  expect_identical(r$recipe$code$link$commit, "a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0")
  expect_identical(r$context$legacy$link_sha, "0000000000000000000000000000000000000000")
})

test_that("a value that cannot take its key's form goes to legacy", {
  rec <- jsonlite::read_json(legacy_path("link_manifest.json"))
  rec$provenance$link_sha <- "unresolved"
  r <- crt_receipt_migrate(rec, "link manifest.json")
  expect_null(r$recipe$code$link)
  expect_identical(r$context$legacy$recipe.code.link$commit, "unresolved")
})

test_that("a migrated receipt compares as recipe unknown", {
  a <- crt_receipt_read(system.file("extdata", "receipt", "examples", "worked_case", "build_1",
                                    package = "crate"))
  m <- crt_receipt_migrate(legacy_path("link_manifest.json"), "link manifest.json")
  x <- crt_receipt_compare(a, m)
  expect_identical(x$verdict, "different")
  expect_match(x$differences$detail[x$differences$field == "recipe.recipe_id"], "recipe unknown")
})

test_that("a migrated value the schema would refuse goes to legacy, and the receipt validates", {
  skip_if_not_installed("jsonvalidate")
  rec <- jsonlite::read_json(legacy_path("link_manifest.json"))
  rec$built <- "2026-11-01 17:04:12"
  rec$seed <- "42"
  rec$host <- ""
  r <- crt_receipt_migrate(rec, "link manifest.json", time = "2026-11-01T17:04:12Z")
  expect_true(crt_receipt_validate(r))
  expect_identical(r$context$time, "2026-11-01T17:04:12Z")
  expect_identical(r$context$legacy$context.time, "2026-11-01 17:04:12")
  expect_identical(r$context$legacy$recipe.seed, "42")
  expect_false("host" %in% names(r$context))
  expect_error(crt_receipt_migrate(rec, "link manifest.json"), "pass `time`")
  expect_error(crt_receipt_migrate(rec, "link manifest.json", time = "yesterday"), "trailing")
})

test_that("it refuses what it cannot read", {
  expect_error(crt_receipt_migrate(legacy_path("link_manifest.json"), "provenance.json"), "not a format")
  expect_error(crt_receipt_migrate(legacy_path("link_manifest.json"), "STAC item"), "not a format")
  expect_error(crt_receipt_migrate(legacy_path("floodplains_provenance.json"), "floodplains provenance.json",
                                   section = "floodplain/nope"), "no section")
  rec <- jsonlite::read_json(legacy_path("link_manifest.json"))
  rec$built <- NULL
  expect_error(crt_receipt_migrate(rec, "link manifest.json"), "pass `time`")
  expect_identical(crt_receipt_migrate(rec, "link manifest.json", time = "2026-01-01T00:00:00Z")$context$time,
                   "2026-01-01T00:00:00Z")
  expect_error(crt_receipt_migrate(list(1, 2), "link manifest.json"), "JSON object")
})

test_that("every mapping row points at a receipt field", {
  m <- utils::read.csv(system.file("extdata", "receipt", "mapping.csv", package = "crate"),
                       stringsAsFactors = FALSE, na.strings = character())
  expect_identical(names(m), c("source_format", "source_field", "receipt_key", "transform", "stac_key", "note"))
  expect_false(anyDuplicated(paste(m$source_format, m$source_field)) > 0)
  reg <- utils::read.csv(system.file("extdata", "receipt", "register.csv", package = "crate"),
                         stringsAsFactors = FALSE)$field
  for (k in m$receipt_key) {
    p <- gsub("\\[[^]]*\\]", ".*", k)
    segs <- strsplit(p, ".", fixed = TRUE)[[1]]
    prefixes <- vapply(seq_along(segs), function(i) paste(segs[seq_len(i)], collapse = "."), "")
    expect_true(p %in% reg || any(prefixes %in% reg), info = k)
  }
  expect_true(all(m$transform %in% c("", "strip_prefix", "multihash", "number")))
  # STAC's own keys sit beside the receipt keys they mirror
  for (key in c("file:checksum", "file:size", "processing:software", "processing:datetime")) {
    expect_true(key %in% m$stac_key, info = key)
  }
})
