# Writing, reading and validating receipts (#43).

worked_case <- function(build) {
  system.file("extdata", "receipt", "examples", "worked_case", build, package = "crate",
              mustWork = TRUE)
}

# A minimal valid set of blocks, written into a fresh directory with one part.
receipt_args <- function(dir) {
  writeLines(c("a,b", "1,2"), file.path(dir, "out.csv"))
  list(
    dir = dir,
    output = list(name = "out"),
    recipe = list(
      code = list(crate = list(commit = strrep("c", 40), version = "0.12.0", dirty = FALSE)),
      config = list(settings = list(threshold = 0.1, species = I("CO"))),
      inputs = list(dem = list(sha256 = strrep("d", 64)))
    ),
    result = list(
      tables = list(out = data.frame(a = 1L, b = 2.5)),
      parts = "out.csv",
      summary = list(rows = 1L),
      tolerance = list(tables = list(out = list(b = 1e-6)))
    ),
    context = list(time = "2026-11-05T00:00:00Z"),
    lockfile = NULL
  )
}

# Arguments merged into the defaults (modifyList: nested lists merge, NULL deletes).
write_with <- function(args, ...) {
  args <- utils::modifyList(args, list(...))
  do.call(crt_receipt_write, args)
}

# The defaults with recipe$inputs replaced outright rather than merged.
write_inputs <- function(args, inputs, ...) {
  args$recipe$inputs <- inputs
  write_with(args, ...)
}

test_that("the worked case's receipts validate and share one recipe", {
  skip_if_not_installed("jsonvalidate")
  a <- crt_receipt_read(worked_case("build_1"))
  b <- crt_receipt_read(worked_case("build_2"))
  expect_true(crt_receipt_validate(a))
  expect_true(crt_receipt_validate(worked_case("build_2")))
  expect_identical(a$recipe$recipe_id, b$recipe$recipe_id)
  expect_identical(a$result$fingerprint, b$result$fingerprint)
  expect_false(identical(a$result$parts$access_check.csv, b$result$parts$access_check.csv))
})

test_that("the worked case's files match their receipts", {
  for (build in c("build_1", "build_2")) {
    dir <- worked_case(build)
    r <- crt_receipt_read(dir)
    for (part in names(r$result$parts)) {
      f <- file.path(dir, part)
      expect_identical(file.size(f), as.numeric(r$result$parts[[part]]$bytes), info = part)
      expect_identical(digest::digest(f, algo = "sha256", file = TRUE),
                       r$result$parts[[part]]$sha256, info = part)
    }
  }
})

test_that("a written receipt reads back to the same canonical bytes and validates", {
  skip_if_not_installed("jsonvalidate")
  dir <- withr::local_tempdir()
  r <- write_with(receipt_args(dir))
  expect_true(file.exists(file.path(dir, "receipt.json")))
  back <- crt_receipt_read(dir)
  expect_identical(crate:::crt_receipt_jcs(back), crate:::crt_receipt_jcs(r))
  expect_true(crt_receipt_validate(back))
  expect_identical(back$recipe$recipe_id, crate:::crt_receipt_recipe_id(back$recipe))
  # Written atomically: no temporary file left beside it
  expect_setequal(list.files(dir), c("out.csv", "receipt.json"))
  # The fields it computed
  expect_identical(r$result$parts[["out.csv"]]$sha256,
                   digest::digest(file.path(dir, "out.csv"), algo = "sha256", file = TRUE))
  expect_identical(r$result$fingerprint$out$sha256,
                   crt_table_fingerprint(data.frame(a = 1L, b = 2.5), c(b = 1e-6)))
  expect_identical(r$context$toolchain$R, paste(R.version$major, R.version$minor, sep = "."))
})

test_that("publish = TRUE leaves the host out", {
  dir <- withr::local_tempdir()
  private <- write_with(receipt_args(dir))
  expect_true("host" %in% names(private$context))
  public <- write_with(receipt_args(dir), publish = TRUE)
  expect_false("host" %in% names(public$context))
  expect_false("host" %in% names(crt_receipt_read(dir)$context))
})

test_that("file names the receipt, so outputs sharing a directory keep one each", {
  dir <- withr::local_tempdir()
  args <- receipt_args(dir)
  write_with(args)
  write_with(args, output = list(name = "out_b"), file = "out_b_receipt.json")
  expect_identical(crt_receipt_read(dir)$output$name, "out")
  b <- crt_receipt_read(file.path(dir, "out_b_receipt.json"))
  expect_identical(b$output$name, "out_b")
  expect_identical(b$result$parts, crt_receipt_read(dir)$result$parts)
  for (bad in c("sub/out.json", "sub\\out.json", "../out.json", "out.txt", "receipt", ".json", "")) {
    expect_error(write_with(args, file = bad), "bare file name", info = bad)
  }
  # a name that is a file the receipt hashes would overwrite the bytes it records: a part however spelled,
  # a part linked to the name, a config file or the lockfile
  writeLines("{}", file.path(dir, "out.json"))
  before <- readLines(file.path(dir, "out.json"))
  refused <- "is a file the receipt hashes"
  for (part in c("out.json", "./out.json", ".//out.json", "././out.json", "OUT.json")) {
    expect_error(write_with(args, result = list(parts = c("out.csv", part)), file = "out.json"), refused, info = part)
  }
  file.symlink(file.path(dir, "out.json"), file.path(dir, "link.json"))
  expect_error(write_with(args, result = list(parts = c("out.csv", "link.json")), file = "out.json"), refused)
  # and the other way: the target name is a link to a hashed file
  expect_error(write_with(args, result = list(parts = c("out.csv", "out.json")), file = "link.json"), refused)
  unlink(file.path(dir, "link.json"))
  # a Unicode form the filesystem folds (macOS keeps one entry for the NFC and NFD spellings)
  nfd <- "cafe\u0301.json"
  nfc <- "caf\u00e9.json"
  writeLines("{}", file.path(dir, nfd))
  if (file.exists(file.path(dir, nfc))) {
    expect_error(write_with(args, result = list(parts = c("out.csv", nfd)), file = nfc), refused)
    expect_identical(readLines(file.path(dir, nfd)), "{}")
  }
  unlink(file.path(dir, nfd))
  expect_error(write_with(args, recipe = list(config = list(files = c(cfg = file.path(dir, "out.json")))),
                          file = "out.json"), refused)
  expect_error(write_with(args, lockfile = file.path(dir, "out.json"), file = "out.json"), refused)
  withr::with_dir(dir, expect_error(write_with(args, dir = ".", lockfile = "out.json", file = "out.json"), refused))
  expect_identical(readLines(file.path(dir, "out.json")), before)
  expect_setequal(list.files(dir), c("out.csv", "out.json", "receipt.json", "out_b_receipt.json"))
})

test_that("context never moves recipe_id; every recipe field does", {
  dir <- withr::local_tempdir()
  args <- receipt_args(dir)
  id <- write_with(args)$recipe$recipe_id
  ctx <- list(time = "2030-01-01T00:00:00Z", host = "elsewhere", run = list(job = "9"),
              session = "rebuild", toolchain = list(GDAL = "3.9.0"), inputs = list(dem = list(rows = 3L)))
  expect_identical(write_with(args, context = ctx)$recipe$recipe_id, id)

  moved <- list(
    seed = list(recipe = list(seed = 7L)),
    setting = list(recipe = list(config = list(settings = list(threshold = 0.2, species = I("CO"))))),
    commit = list(recipe = list(code = list(crate = list(commit = strrep("e", 40), version = "0.12.0",
                                                         dirty = FALSE)))),
    dirty = list(recipe = list(code = list(crate = list(commit = strrep("c", 40), version = "0.12.0", dirty = TRUE)))),
    input = list(recipe = list(inputs = list(dem = list(sha256 = strrep("f", 64))))),
    input_kind = list(recipe = list(inputs = list(dem = NULL, dem_v = list(version_id = "v1"))))
  )
  for (nm in names(moved)) {
    expect_false(identical(do.call(write_with, c(list(args), moved[[nm]]))$recipe$recipe_id, id), info = nm)
  }
  # A config file's bytes are part of the recipe
  cfg <- file.path(dir, "settings.yaml")
  writeLines("a: 1", cfg)
  a <- write_with(args, recipe = list(config = list(files = c(settings.yaml = cfg))))$recipe$recipe_id
  writeLines("a: 2", cfg)
  b <- write_with(args, recipe = list(config = list(files = c(settings.yaml = cfg))))$recipe$recipe_id
  expect_false(identical(a, b))
  # The key, not where the checkout sits, enters recipe_id: an absolute path must be named
  expect_error(write_with(args, recipe = list(config = list(files = cfg))), "Name each config file")
  other <- file.path(withr::local_tempdir(), "settings.yaml")
  writeLines("a: 2", other)
  expect_identical(write_with(args, recipe = list(config = list(files = c(settings.yaml = other))))$recipe$recipe_id, b)
})

test_that("tolerances are written as exact powers of ten", {
  dir <- withr::local_tempdir()
  r <- write_with(receipt_args(dir), result = list(tolerance = list(tables = list(out = list(b = "1e-6")))))
  expect_identical(r$result$tolerance$tables$out$b, 1e-6)
  expect_match(paste(readLines(file.path(dir, "receipt.json")), collapse = "\n"), "\"b\": 0.000001")
})

test_that("it refuses what would give a wrong or ambiguous identity", {
  dir <- withr::local_tempdir()
  args <- receipt_args(dir)
  short <- list(crate = list(commit = "ccccccc", dirty = FALSE))
  expect_error(write_with(args, recipe = list(code = short)),
               "40-character")
  expect_error(write_inputs(args, list(dem = list(sha256 = strrep("d", 64), none = "x"))),
               "exactly one identity")
  expect_error(write_inputs(args, list(dem = list(md5 = "x"))), "exactly one identity")
  expect_error(write_inputs(args, list(dem = list(recipe_id = "abc"))), "64 lower-case")
  expect_error(write_inputs(args, list(dem = list(none = ""))), "empty")
  expect_error(write_with(args, recipe = list(seed = 1.5)), "whole number")
  expect_error(write_with(args, recipe = list(host = "m4")), "does not hold")
  expect_error(write_with(args, result = list(parts = "../out.csv")), "inside it")
  expect_error(write_with(args, result = list(parts = "/etc/hosts")), "inside it")
  expect_error(write_with(args, result = list(parts = "nope.csv")), "not found")
  expect_error(write_with(args, result = list(tolerance = list(tables = list(out = list(b = 5e-7))))), "power of ten")
  expect_error(write_with(args, result = list(tolerance = list(tables = list(other = list(b = 1e-6))))),
               "not among the tables")
  expect_error(write_with(args, result = list(tolerance = list(summary = list(km = 1e-6)))), "not in")
  expect_error(write_with(args, context = list(time = "2026-11-05 00:00:00")), "trailing")
  expect_error(write_with(args, context = list(toolchain = list(Python = NA_character_))), "version string")
  expect_error(write_with(args, output = list(name = "")), "must not be empty")
  for (h in list("", 5, NA_character_)) {
    expect_error(write_with(args, context = list(host = h)), "host name")
  }
  expect_error(write_with(args, dir = file.path(dir, "missing")), "does not exist")
})

test_that("a declaration supplies the tolerances and checks what is supplied", {
  keys <- crt_receipt_keys(system.file("extdata", "receipt", "examples", "receipt_keys.yaml",
                                       package = "crate", mustWork = TRUE))
  expect_s3_class(keys, "crt_receipt_keys")
  expect_identical(keys$tolerance$tables$access_check$km, 1e-9)
  expect_identical(keys$tolerance$summary$km_total, 1e-6)
  expect_identical(keys$inputs, c("flow", "fwa_stream_networks"))

  dir <- withr::local_tempdir()
  yml <- file.path(dir, "keys.yaml")
  writeLines(c("receipt_keys: 1", "output: out", "recipe:", "  settings: [threshold, species]",
               "  inputs: [dem]", "result:", "  tables:", "    out:", "      tolerance: {b: 1e-3}",
               "  summary:", "    rows: {}"), yml)
  k <- crt_receipt_keys(yml)
  args <- receipt_args(dir)
  args$result$tolerance <- NULL
  r <- write_with(args, keys = k)
  expect_identical(r$result$tolerance$tables$out$b, 1e-3)
  expect_error(write_inputs(args, list(dem = list(sha256 = strrep("d", 64)), extra = list(none = "x")), keys = k),
               "Supplied but not declared")
  expect_error(write_inputs(args, setNames(list(), character()), keys = k), "Declared but not supplied")
  expect_error(write_with(args, keys = k, recipe = list(seed = 3L)), "says it has none")
  expect_error(write_with(args, keys = list()), "crt_receipt_keys")
})

test_that("a declaration is refused when malformed", {
  dir <- withr::local_tempdir()
  yml <- file.path(dir, "keys.yaml")
  bad <- list(
    "begin with" = c("output: out"),
    "recipe fields" = c("receipt_keys: 1", "output: out", "register:", "  recipe.seed: warn"),
    "refuse, warn or record" = c("receipt_keys: 1", "output: out", "register:", "  output.schema: ignore"),
    "power of ten" = c("receipt_keys: 1", "output: out", "result:", "  tables:", "    t:", "      tolerance: {x: 0.5}"),
    "does not hold" = c("receipt_keys: 1", "output: out", "recipe:", "  host: m4")
  )
  for (msg in names(bad)) {
    writeLines(bad[[msg]], yml)
    expect_error(crt_receipt_keys(yml), msg, info = msg)
  }
})

test_that("validation catches a recipe_id that does not match its recipe", {
  skip_if_not_installed("jsonvalidate")
  r <- crt_receipt_read(worked_case("build_1"))
  r$recipe$config$settings$watershed_group <- "MORR"
  expect_error(crt_receipt_validate(r), "hashes to")
  res <- crt_receipt_validate(r, error = FALSE)
  expect_false(res)
  expect_match(attr(res, "errors"), "recipe_id")
  r2 <- crt_receipt_read(worked_case("build_1"))
  r2$output$receipt_version <- "9.9.9"
  expect_error(crt_receipt_validate(r2), "not valid")
})

test_that("reading refuses what is not a receipt", {
  dir <- withr::local_tempdir()
  expect_error(crt_receipt_read(dir), "No receipt")
  f <- file.path(dir, "receipt.json")
  file.create(f)
  expect_error(crt_receipt_read(f), "empty")
  writeLines("{not json", f)
  expect_error(crt_receipt_read(f), "not JSON")
  writeLines('{"a": 1}', f)
  expect_error(crt_receipt_read(f), "no .*output")
  writeLines('{"output": {"receipt_version": "2.0.0"}}', f)
  expect_error(crt_receipt_read(f), "receipt version")
})
