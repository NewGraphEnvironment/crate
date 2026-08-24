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
