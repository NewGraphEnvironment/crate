# Guards over the registry as a whole, rather than over one entry.
#
# The failure these exist for is a schema or a row added without the other, or
# a schema declaring a type nothing implements. Both are invisible until a
# caller hits them, and both are cheap to catch here.
#
# Enumerated from the registry and the schemas directory rather than from a
# list written by hand -- a guard that walks a subset returns the same green
# tick while the uncovered part drifts.

reg <- crt_registry_load()

schema_path <- function(rel) {
  system.file(file.path("extdata", rel), package = "crate")
}

test_that("every registered schema YAML is bundled and parses", {
  for (i in seq_len(nrow(reg))) {
    p <- schema_path(reg$schema_yaml[[i]])
    expect_true(nzchar(p), info = reg$schema_yaml[[i]])
    expect_no_error(yaml::read_yaml(p))
  }
})

test_that("every kind is one crate knows", {
  expect_true(all(reg$kind %in% c("file", "schema_only")))
})

test_that("handler presence matches kind", {
  for (i in seq_len(nrow(reg))) {
    fn <- reg$handler_fn[[i]]
    if (identical(reg$kind[[i]], "file")) {
      expect_true(!is.na(fn) && nzchar(fn), info = reg$file_name[[i]])
      expect_true(
        exists(fn, envir = asNamespace("crate"), mode = "function"),
        info = fn
      )
    } else {
      # A schema_only entry with a handler is a row that was flipped without
      # its code being removed, or the reverse.
      expect_true(is.na(fn) || !nzchar(fn), info = reg$file_name[[i]])
    }
  }
})

test_that("every declared column name is a string", {
  # YAML 1.1 resolves bare y, n, yes, no, on, off, true and false to booleans,
  # so `- name: y` parses as logical TRUE and the column silently stops being a
  # column -- crt_schema_apply() would never match it and it would go untyped
  # with nothing reported. Caught exactly this way on track_vertices.
  for (i in seq_len(nrow(reg))) {
    schema <- yaml::read_yaml(schema_path(reg$schema_yaml[[i]]))
    bad <- Filter(function(col) !is.character(col$name), schema$canonical$cols)
    expect_identical(
      length(bad), 0L,
      info = paste0(
        reg$file_name[[i]], ": ",
        paste(vapply(bad, function(col) paste0(col$name, " (", class(col$name), ")"),
                     character(1)), collapse = ", "),
        " -- quote it in the YAML"
      )
    )
  }
})

test_that("upstream variant column lists are strings too", {
  for (i in seq_len(nrow(reg))) {
    schema <- yaml::read_yaml(schema_path(reg$schema_yaml[[i]]))
    for (variant in schema$upstream_variants) {
      expect_true(
        all(vapply(variant$cols, is.character, logical(1))),
        info = paste(reg$file_name[[i]], variant$id)
      )
    }
  }
})

test_that("every declared type is one crt_schema_apply implements", {
  supported <- crt_schema_types()
  for (i in seq_len(nrow(reg))) {
    schema <- yaml::read_yaml(schema_path(reg$schema_yaml[[i]]))
    types <- vapply(
      schema$canonical$cols,
      function(col) if (is.null(col$type)) NA_character_ else col$type,
      character(1)
    )
    unknown <- setdiff(stats::na.omit(types), supported)
    expect_identical(
      unknown, character(0),
      info = paste(reg$file_name[[i]], ":", paste(unknown, collapse = ", "))
    )
  }
})

test_that("the registry's canonical_cols match the schema's canonical cols", {
  for (i in seq_len(nrow(reg))) {
    schema <- yaml::read_yaml(schema_path(reg$schema_yaml[[i]]))
    from_schema <- vapply(schema$canonical$cols, function(col) col$name, character(1))
    from_registry <- trimws(strsplit(reg$canonical_cols[[i]], ",")[[1]])
    # The registry list is informational, so it is allowed to name a subset of
    # the schema (bcfp lists the required cols only) -- but never a column the
    # schema does not declare, which would be a rename that landed in one place.
    expect_identical(
      setdiff(from_registry, from_schema), character(0),
      info = reg$file_name[[i]]
    )
  }
})

test_that("every schema YAML sits at schemas/<source>/<file_name>.yaml", {
  # The rule that lets a dataset ID name its schema with no lookup: a published
  # dataset's file_name is its path (discharge/fwa/v1/segment_monthly), and the
  # YAML is found by appending it. A row that breaks it is a schema nobody can
  # find from the ID.
  expect_identical(
    reg$schema_yaml,
    paste0("schemas/", reg$source, "/", reg$file_name, ".yaml")
  )
})

test_that("each schema's file field is its registry file_name", {
  for (i in seq_len(nrow(reg))) {
    schema <- yaml::read_yaml(schema_path(reg$schema_yaml[[i]]))
    expect_identical(schema$file, reg$file_name[[i]], info = reg$schema_yaml[[i]])
  }
})

test_that("every bundled schema YAML is registered", {
  # The direction that matters: a schema authored and then never given a row is
  # invisible to crt_files(), so nobody can discover it. The reverse direction
  # is covered by the bundled-and-parses test above.
  root <- system.file("extdata/schemas", package = "crate")
  found <- paste0("schemas/", list.files(root, pattern = "[.]yaml$", recursive = TRUE))
  expect_identical(sort(setdiff(found, reg$schema_yaml)), character(0))
})

test_that("decision entries referenced by a schema exist", {
  # decisions/ is .Rbuildignore'd, so it is absent from an installed package.
  # Run this against the source tree when there is one, rather than asserting
  # nothing when there is not.
  root <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = FALSE)
  skip_if_not(dir.exists(file.path(root, "decisions")), "not running in the source tree")
  for (i in seq_len(nrow(reg))) {
    schema <- yaml::read_yaml(schema_path(reg$schema_yaml[[i]]))
    for (d in as.character(schema$decisions)) {
      expect_true(file.exists(file.path(root, d)), info = d)
    }
  }
})

# ---- the keys that say what a column means (#13) ---------------------------

read_schema <- function(i) yaml::read_yaml(schema_path(reg$schema_yaml[[i]]))
declared_names <- function(schema) {
  vapply(schema$canonical$cols, function(col) as.character(col$name), character(1))
}

test_that("every grade requires only columns the schema declares", {
  for (i in seq_len(nrow(reg))) {
    schema <- read_schema(i)
    for (g in schema$grades) {
      expect_true(is.character(g$name) && nzchar(g$name), info = reg$file_name[[i]])
      req <- unlist(g$requires)
      expect_true(length(req) > 0L, info = paste(reg$file_name[[i]], g$name))
      expect_identical(
        setdiff(req, declared_names(schema)), character(0),
        info = paste(reg$file_name[[i]], g$name)
      )
    }
  }
})

test_that("variant fingerprints are well-formed and name one variant each", {
  for (i in seq_len(nrow(reg))) {
    schema <- read_schema(i)
    fps <- unlist(lapply(schema$upstream_variants, function(v) v$fingerprint))
    if (!length(fps)) next
    expect_true(
      all(grepl("^[0-9]+-[0-9a-f]{16}$", fps)),
      info = paste(reg$file_name[[i]], paste(fps, collapse = ", "))
    )
    expect_identical(anyDuplicated(fps), 0L, info = reg$file_name[[i]])
  }
})

test_that("allowed values sit on string or integer columns and read back as text", {
  # YAML 1.1 reads a bare Yes or No as a boolean and a bare 4 as a number, so a
  # vocabulary written unquoted stops being the stored values. Every value, and
  # every label of a coded one, must come back as a string.
  for (i in seq_len(nrow(reg))) {
    schema <- read_schema(i)
    for (col in schema$canonical$cols) {
      if (is.null(col$values)) next
      where <- paste(reg$file_name[[i]], col$name)
      expect_true(col$type %in% c("string", "integer"), info = where)
      for (e in as.list(col$values)) {
        if (is.list(e)) {
          expect_true(is.character(e$value) && is.character(e$label), info = where)
        } else {
          expect_true(is.character(e), info = paste(where, format(e)))
        }
      }
    }
  }
})

test_that("a range is two numbers, low then high", {
  for (i in seq_len(nrow(reg))) {
    schema <- read_schema(i)
    for (col in schema$canonical$cols) {
      if (is.null(col$range)) next
      r <- unlist(col$range)
      where <- paste(reg$file_name[[i]], col$name)
      expect_true(is.numeric(r) && length(r) == 2L && r[[1]] <= r[[2]], info = where)
      expect_true(col$type %in% c("integer", "double"), info = where)
    }
  }
})

test_that("every form schema carries the form_capture envelope verbatim", {
  # The envelope is declared once, in nge/form_capture, and repeated by each
  # per-form schema so one conform call checks both. Repeated text drifts; this
  # is what stops it.
  envelope <- yaml::read_yaml(schema_path("schemas/nge/form_capture.yaml"))$canonical$cols
  strip <- function(col) col[c("name", "type", "required")]
  forms <- which(reg$source == "nge" & startsWith(reg$file_name, "form_") &
                   reg$file_name != "form_capture")
  for (i in forms) {
    schema <- read_schema(i)
    by_name <- stats::setNames(schema$canonical$cols, declared_names(schema))
    for (col in envelope) {
      expect_identical(strip(by_name[[col$name]]), strip(col),
                       info = paste(reg$file_name[[i]], col$name))
    }
  }
})
