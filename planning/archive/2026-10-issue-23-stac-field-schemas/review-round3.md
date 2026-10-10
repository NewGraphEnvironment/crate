# Code-check round 3 (crate#23)

## Mechanism

The freeze guard treats **"present on gh-pages" as "checked"**, and the set it freezes
is chosen by a different rule from the set the checks cover. Freezing takes in every
built `stac/<prefix>/v*/schema.json` that reaches gh-pages. Checking is narrower,
in three ways, and each one is a selector that only happens to agree with the freeze
selector:

| axis | freeze selector | check selector | status |
|---|---|---|---|
| file name | site glob / guard glob (any `v*` dir) | strict regex in `stac_schemas()` | R1, fixed (setequal) |
| git ref | whatever ref deploys | the ref the tests ran on | R1 dispatch, R2 release; fixed (main only) |
| **schema version** | every version built | only the version each example names in `stac_extensions` (`stac_schema_path()`, test lines 41-50) | **open: finding 1** |
| **prefix** | every prefix directory | the hand-written `c("lidarbc", "las")` loop (line 86), agreeing with the separate list at line 66 | **open: finding 1, second route** |
| validator | (n/a) | ajv in tests; the consumer is Python jsonschema | latent only, see below |

The findings.md enumeration covers the ref axis completely: I re-checked it. The
only gh-pages writer is the pkgdown.yaml deploy step, gated to `refs/heads/main`;
`update-citation-cff.yaml` never touches gh-pages. Nothing in the repo calls
`deploy_to_branch`. gh-pages carries no `stac/` today
(`git ls-tree origin/gh-pages -- stac` is empty), so nothing is frozen yet. Re-runs
and out-of-order runs of older main commits fail safe: the guard reports the newer
version as "published but no longer built".

The enumeration did not cover the version and prefix axes.

Rows I checked and found not reachable:
- **Hidden directories.** pkgdown's `copy_asset_dir()` uses `fs::dir_ls(recurse = TRUE)`
  with `all = FALSE`, so hidden directories are not copied. This matches `list.files()`
  and the bash glob.
- **Case variants** such as `Schema.json`. They are neither tested nor frozen, and no
  consumer fetches them.
- **Validator divergence.** ajv and Python `re` could disagree on a future pattern, for
  example `\p{L}` or `(?<name>)`, which ajv compiles and Python rejects. The current
  patterns compile identically in both. This is latent only, with no instance in this
  diff.

## Findings

- **[fragile]** `tests/testthat/test-stac_schemas.R:41-50` (`stac_schema_path`), lines 72-81
  (the per-schema loop), and `.github/workflows/pkgdown.yaml:84-106` (the guard).
  Behaviour is checked only for the schema version that an example names. Every
  other built version gets only the structural checks: `$schema`, `$id`, the
  `contains` const, and `$ref` standing alone. Even those versions are never compiled.
  The guard then deploys such a version as "new", and from the next run on it is frozen.

  Reproduced in a temp copy. I added `las/v1.1.0/schema.json` with `$id` and `const`
  set correctly, plus `"maximum": "ten"` and a dangling `$ref`, and left the examples
  naming v1.0.0. Results:
  - `test_file(..., stop_on_failure = TRUE)` reports no failures.
  - The guard step, run against `origin/gh-pages` with docs/stac populated, prints
    "3 STAC schema(s) built" and exits 0.
  - ajv itself rejects the schema: `schema is invalid: data/definitions/las:point_format/maximum must be number`.

  This is reachable by the normal workflow: add a version directory and forget to
  bump the examples, or add two versions in one push. The consequence is that a
  published URL fails every pystac validation that names it. The version number is
  also burned, because the guard blocks any fix to it.

  **Second route, same gap:** the prefix list is written twice, at line 66
  (`expect_setequal(..., c("lidarbc", "las"))`) and line 86 (`for (prefix in c("lidarbc", "las"))`).
  When the planned airphoto, floodplains and uav prefixes are added, a change to line 66 alone
  passes. I reproduced this: a new `foo/v1.0.0` with an invalid schema and an empty
  `examples/`, with only line 66 edited, gave no failures. The new prefix ships and is
  frozen without one validation having run.

  **Fix shape:**
  - Derive the prefixes from `rel`, not from a second literal.
  - Assert, per prefix, that the examples name the highest version present, so a
    new version cannot deploy until the examples and negative cases run against it.
  - Compile every strict schema with ajv, for example
    `jsonvalidate::json_schema$new(path, engine = "ajv")` in the line-72 loop, so an
    intermediate version added in the same push is at least a valid schema.
