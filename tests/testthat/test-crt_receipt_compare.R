# The three-way comparison and the register it reads (#43).

wc_dir <- function(build) {
  system.file("extdata", "receipt", "examples", "worked_case", build, package = "crate",
              mustWork = TRUE)
}

read_build <- function(build) {
  dir <- wc_dir(build)
  nms <- c("access_check", "visits_link", "visits_species", "walks")
  stats::setNames(lapply(nms, function(n) utils::read.csv(file.path(dir, paste0(n, ".csv")))), nms)
}

# One small output written twice, the second build changed by `change`.
two_builds <- function(km_a, km_b, tolerance = list(km = 1e-9), part_table = TRUE) {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  one <- function(name, km) {
    dir <- file.path(root, name)
    dir.create(dir)
    df <- data.frame(segment = paste0("s", seq_along(km)), km = km)
    utils::write.csv(df, file.path(dir, "t.csv"), row.names = FALSE)
    parts <- if (part_table) c(t = "t.csv") else "t.csv"
    r <- crt_receipt_write(
      dir, output = list(name = "out"),
      recipe = list(code = list(crate = list(commit = strrep("c", 40), dirty = FALSE))),
      result = list(tables = list(t = df), parts = parts,
                    tolerance = list(tables = if (length(tolerance)) list(t = tolerance))),
      context = list(time = "2026-11-05T00:00:00Z"), lockfile = NULL, publish = TRUE
    )
    list(receipt = r, table = df)
  }
  list(a = one("a", km_a), b = one("b", km_b))
}

test_that("the worked case is equivalent, and names what moved", {
  x <- crt_receipt_compare(wc_dir("build_1"), wc_dir("build_2"))
  expect_s3_class(x, "crt_receipt_comparison")
  expect_identical(x$verdict, "equivalent")
  expect_identical(x$mode, "receipts")
  d <- x$differences
  expect_false(any(d$action == "refuse"))
  expect_setequal(d$field[d$action == "within"], c(
    "result.parts[access_check.csv].bytes", "result.parts[access_check.csv].sha256",
    "result.summary[km_total]"
  ))
  expect_setequal(d$field[d$action == "record"], c("context.run", "context.time"))
  expect_match(d$detail[d$field == "result.summary[km_total]"], "within 1e-06")
  expect_output(print(x), "equivalent")
})

test_that("a receipt compared with itself is identical", {
  x <- crt_receipt_compare(wc_dir("build_1"), wc_dir("build_1"))
  expect_identical(x$verdict, "identical")
  expect_identical(nrow(x$differences), 0L)
})

test_that("re-reading the worked case's tables agrees, and says it re-read them", {
  x <- crt_receipt_compare(wc_dir("build_1"), wc_dir("build_2"),
                           tables = list(a = read_build("build_1"), b = read_build("build_2")))
  expect_identical(x$verdict, "equivalent")
  expect_identical(x$mode, "bytes")
})

# The receipts agree, but the table on disk is not what they claim.
test_that("a supplied table is checked against its receipt even when the fingerprints agree", {
  b <- read_build("build_2")
  b$walks$segments[1] <- 99L
  x <- crt_receipt_compare(wc_dir("build_1"), wc_dir("build_2"),
                           tables = list(a = read_build("build_1"), b = b))
  expect_identical(x$verdict, "different")
  hit <- x$differences[x$differences$field == "result.fingerprint[walks].sha256", ]
  expect_identical(hit$action, "refuse")
  expect_match(hit$detail, "supplied for b is not the one its receipt fingerprinted")
})

# Restore the bug: without the tolerance on km the same rebuild is different, and the
# report says where.
test_that("without its tolerance the worked case reads different", {
  wc <- read_build("build_1")$access_check
  b <- read_build("build_2")$access_check
  builds <- two_builds(wc$km, b$km, tolerance = NULL)
  x <- crt_receipt_compare(builds$a$receipt, builds$b$receipt)
  expect_identical(x$verdict, "different")
  hit <- x$differences[x$differences$field == "result.fingerprint[t].sha256", ]
  expect_identical(hit$action, "refuse")
  expect_match(hit$detail, "receipts only")
})

test_that("a value at a rounding edge differs in receipts and agrees on re-reading", {
  builds <- two_builds(c(0.0000000014, 5), c(0.0000000016, 5))
  expect_false(identical(builds$a$receipt$result$fingerprint, builds$b$receipt$result$fingerprint))
  x <- crt_receipt_compare(builds$a$receipt, builds$b$receipt)
  expect_identical(x$verdict, "different")
  y <- crt_receipt_compare(builds$a$receipt, builds$b$receipt,
                           tables = list(a = list(t = builds$a$table), b = list(t = builds$b$table)))
  expect_identical(y$verdict, "equivalent")
  expect_identical(y$mode, "bytes")
  expect_match(y$differences$detail[y$differences$field == "result.fingerprint[t].sha256"],
               "within tolerance")
})

test_that("re-reading refuses past the tolerance, and a table that is not its receipt's", {
  builds <- two_builds(c(1, 5), c(1.1, 5))
  tbl <- list(a = list(t = builds$a$table), b = list(t = builds$b$table))
  x <- crt_receipt_compare(builds$a$receipt, builds$b$receipt, tables = tbl)
  expect_identical(x$verdict, "different")
  expect_match(x$differences$detail[x$differences$field == "result.fingerprint[t].sha256"],
               "column km, 1 row past 1e-09")
  wrong <- tbl
  wrong$b$t$km[2] <- 6
  y <- crt_receipt_compare(builds$a$receipt, builds$b$receipt, tables = wrong)
  expect_match(y$differences$detail[y$differences$field == "result.fingerprint[t].sha256"],
               "not the one its receipt fingerprinted")
})

# read.csv() brings back whole numbers as integer and an all-NA column as logical.
test_that("re-read tolerance columns of another numeric type still compare", {
  builds <- two_builds(c(12, 4), c(12, 4.0001), tolerance = list(km = 1e-3))
  a <- builds$a$table
  a$km <- as.integer(a$km)
  x <- crt_receipt_compare(builds$a$receipt, builds$b$receipt,
                           tables = list(a = list(t = a), b = list(t = builds$b$table)))
  expect_identical(x$verdict, "equivalent")
  expect_identical(x$mode, "bytes")
  na_builds <- two_builds(c(NA_real_, NA_real_), c(NA_real_, NA_real_))
  na_a <- na_builds$a$table
  na_a$km <- c(NA, NA)
  y <- crt_receipt_compare(na_builds$a$receipt, na_builds$b$receipt,
                           tables = list(a = list(t = na_a), b = list(t = na_builds$b$table)))
  expect_identical(y$verdict, "identical")
})

test_that("a file whose bytes moved is equivalent only when it names an agreeing table", {
  builds <- two_builds(c(1.00000000001, 5), c(1.00000000002, 5), part_table = FALSE)
  x <- crt_receipt_compare(builds$a$receipt, builds$b$receipt)
  expect_identical(x$verdict, "different")
  expect_match(x$differences$detail[x$differences$field == "result.parts[t.csv].sha256"],
               "names no table")
  named <- two_builds(c(1.00000000001, 5), c(1.00000000002, 5))
  expect_identical(crt_receipt_compare(named$a$receipt, named$b$receipt)$verdict, "equivalent")
})

test_that("another recipe is different and names the field", {
  a <- crt_receipt_read(wc_dir("build_1"))
  b <- a
  b$recipe$config$settings$watershed_group <- "MORR"
  b$recipe$recipe_id <- crate:::crt_receipt_recipe_id(b$recipe)
  x <- crt_receipt_compare(a, b)
  expect_identical(x$verdict, "different")
  expect_true("recipe.config.settings[watershed_group]" %in% x$differences$field)
  expect_true("recipe.recipe_id" %in% x$differences$field)
  expect_true(all(x$differences$action[x$differences$side == "recipe"] == "refuse"))
})

test_that("a migrated receipt has no recipe to agree with", {
  a <- crt_receipt_read(wc_dir("build_1"))
  b <- a
  b$output$migrated_from <- "manifest.json"
  b$recipe$recipe_id <- NULL
  x <- crt_receipt_compare(a, b)
  expect_identical(x$verdict, "different")
  expect_match(x$differences$detail[x$differences$field == "recipe.recipe_id"], "recipe unknown: b")
})

test_that("a declaration's register changes what a difference does outside the recipe", {
  a <- crt_receipt_read(wc_dir("build_1"))
  b <- a
  b$output$schema <- "nge/link/evidence"
  expect_identical(crt_receipt_compare(a, b)$verdict, "identical")
  dir <- withr::local_tempdir()
  yml <- file.path(dir, "keys.yaml")
  writeLines(c("receipt_keys: 1", "output: link_evidence", "register:", "  output.schema: refuse"), yml)
  expect_identical(crt_receipt_compare(a, b, keys = crt_receipt_keys(yml))$verdict, "different")
  writeLines(c("receipt_keys: 1", "output: link_evidence", "register:", "  output.bogus: refuse"), yml)
  expect_error(crt_receipt_compare(a, b, keys = crt_receipt_keys(yml)), "does not have|not have")
})

test_that("it refuses arguments it cannot compare", {
  a <- crt_receipt_read(wc_dir("build_1"))
  expect_error(crt_receipt_compare(a, list(1)), "receipts")
  expect_error(crt_receipt_compare(a, a, tables = list(x = 1)), "list\\(a")
  expect_error(crt_receipt_compare(a, a, keys = list()), "crt_receipt_keys")
})

# ---- the register ----------------------------------------------------------------

register <- function() {
  utils::read.csv(system.file("extdata", "receipt", "register.csv", package = "crate",
                              mustWork = TRUE), stringsAsFactors = FALSE)
}

# Every field path in the receipt schema: a keyed collection contributes its own path
# (a key on one side only) and its children under `*`.
schema_fields <- function() {
  s <- jsonlite::read_json(system.file("extdata", "receipt", "schema", "v1.0.0", "schema.json",
                                       package = "crate", mustWork = TRUE))
  deref <- function(node) {
    while (!is.null(node$`$ref`)) node <- s$definitions[[sub("^#/definitions/", "", node$`$ref`)]]
    node
  }
  walk <- function(node, path) {
    node <- deref(node)
    if (!is.null(node$properties)) {
      unlist(lapply(names(node$properties), function(p) walk(node$properties[[p]], paste0(path, ".", p))))
    } else if (!is.null(node$propertyNames)) {
      ap <- node$additionalProperties
      c(path, if (is.list(ap)) walk(ap, paste0(path, ".*")) else paste0(path, ".*"))
    } else {
      path
    }
  }
  unlist(lapply(c("output", "recipe", "result", "context"), function(b) walk(s$definitions[[b]], b)))
}

test_that("the register has one row per schema field, and none other", {
  r <- register()
  expect_false(anyDuplicated(r$field) > 0)
  expect_setequal(r$field, schema_fields())
  expect_true(all(r$action %in% c("refuse", "warn", "record")))
  expect_true(all(nzchar(r$why)))
  # recipe_id covers every recipe field, and context is never identity
  expect_true(all(r$action[startsWith(r$field, "recipe.")] == "refuse"))
  expect_true(all(r$action[startsWith(r$field, "context.")] == "record"))
})

# A receipt with every field present, so each can be changed alone.
full_receipt <- function() {
  x <- crt_receipt_read(wc_dir("build_1"))
  x$output$schema <- "nge/link/evidence"
  x$recipe$seed <- 7L
  x$recipe$inputs$dem <- list(sha256 = strrep("d", 64))
  x$recipe$inputs$lulc <- list(none = "live collection")
  x$context$host <- "m4"
  x$context$session <- "first build"
  x$context$lockfile_sha256 <- strrep("e", 64)
  x$context$inputs <- list(flow = list(rows = 3L))
  x
}

collections_of <- function(fields) {
  unique(unlist(lapply(fields[grepl(".*", fields, fixed = TRUE)], function(f) {
    p <- strsplit(f, ".", fixed = TRUE)[[1]]
    vapply(which(p == "*"), function(s) paste(p[seq_len(s - 1L)], collapse = "."), "")
  })))
}

bump <- function(v) {
  if (is.null(v)) return("added")
  if (is.character(v)) return(paste0(v, "x"))
  if (is.logical(v)) return(!v)
  if (is.numeric(v)) return(v + 1)
  if (is.list(v) && !is.null(names(v))) return(c(v, list(zz = "x")))
  c(v, list("x"))
}

# Change one field: `*` takes the first key there; a collection gains a key.
change_at <- function(x, segs, collection) {
  key <- if (segs[1] == "*") names(x)[1] else segs[1]
  if (length(segs) == 1L) {
    if (collection) {
      x[[key]][["zz_added"]] <- x[[key]][[1]]
    } else {
      x[[key]] <- bump(x[[key]])
    }
    return(x)
  }
  x[[key]] <- change_at(x[[key]], segs[-1], collection)
  x
}

test_that("a difference in each field alone does what the register says", {
  r <- register()
  colls <- collections_of(r$field)
  base <- full_receipt()
  # A part whose bytes move while its table agrees is the one documented downgrade.
  within <- c("result.parts.*.bytes", "result.parts.*.sha256")
  for (i in seq_len(nrow(r))) {
    f <- r$field[i]
    changed <- change_at(base, strsplit(f, ".", fixed = TRUE)[[1]], f %in% colls)
    x <- crt_receipt_compare(base, changed)
    d <- x$differences
    hit <- d[vapply(d$field, function(fd) {
      p <- gsub("\\[[^]]*\\]", ".*", fd)
      identical(p, f)
    }, TRUE), ]
    expect_identical(nrow(hit), 1L, info = f)
    want <- if (f %in% within) "within" else r$action[i]
    expect_identical(hit$action, want, info = f)
    verdict <- c(refuse = "different", within = "equivalent", warn = "identical", record = "identical")
    expect_identical(x$verdict, verdict[[want]], info = f)
  }
})
