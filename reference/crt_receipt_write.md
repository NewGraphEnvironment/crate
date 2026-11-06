# Write a provenance receipt

Writes `receipt.json` for one output: what it is, how it was made, what
came out, and where and when. The package supplies the values it knows;
this function computes everything that must agree byte for byte across
implementations: the `recipe_id`, each table's fingerprint, each part's
size and SHA-256, and the config files' SHA-256 (crate#43).

## Usage

``` r
crt_receipt_write(
  dir,
  output,
  recipe,
  result = list(),
  context = list(),
  keys = NULL,
  lockfile = NULL,
  publish = FALSE
)
```

## Arguments

- dir:

  Directory to write `receipt.json` into: the output's directory.
  `parts` are relative to it.

- output, recipe, result, context:

  Named lists, one per block (see above).

- keys:

  Optional: the package's declaration, from
  [`crt_receipt_keys()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_keys.md).
  When given, the tolerances come from it and the inputs, settings,
  config files and tables supplied must be exactly those it declares.

- lockfile:

  Path to a lockfile whose SHA-256 is recorded in `context`, or `NULL`.
  Defaults to `renv.lock` in the working directory when one exists.

- publish:

  `TRUE` for a receipt that will be published: leaves the host out.

## Value

The receipt, as a list, invisibly. The file is
`file.path(dir, "receipt.json")`.

## The blocks

- `output`: `name`, and optionally `scope` (the partition: a watershed
  group, a region) and `schema` (the crate schema the output conforms
  to).

- `recipe`: `code`, a list keyed by repository of
  `list(commit, version, dirty)`, with `commit` the full 40-character
  SHA; `config`, a list of `files` (paths, hashed here; named to set the
  key, otherwise keyed by the path as given) and `settings` (the
  resolved run settings, written verbatim: wrap a length-one vector in
  [`I()`](https://rdrr.io/r/base/AsIs.html) to keep it an array). A
  config file is hashed as its bytes, as checked out: a repo whose
  config enters `recipe_id` should pin its line endings
  (`.gitattributes`: `*.yaml text eol=lf`), or a CRLF checkout is
  another recipe; `inputs`, keyed by input name, each exactly one of
  `list(recipe_id = )`, `list(version_id = )`, `list(sha256 = )` or
  `list(none = "why")`; and `seed`, an integer or `NULL`.

- `result`: `tables`, a named list of data frames to fingerprint;
  `parts`, the output's files as paths relative to `dir`, each named by
  the table it holds where it holds one
  (`c(access_check = "access_check.csv", "map.tif")`), so a comparison
  can tell a file whose bytes moved within its table's tolerance from
  one that changed; `summary`, named numbers such as `rows` or
  `km_total`; and `tolerance`,
  `list(tables = list(<table> = list(<column> = 1e-9)), summary = list(<name> = 1e-6))`.

- `context`: anything of `run` (identifiers), `session`, `inputs` (each
  input's own result, for reporting), `toolchain` and `time`. `time`
  defaults to now, in UTC; `toolchain` is filled with R's version and,
  when loaded, GDAL's, terra's, sf's and arrow's, and entries given here
  win. The host is recorded unless `publish = TRUE`.

Toolchain versions and every other part of `context` are never part of
an identity: a GDAL upgrade alone leaves `recipe_id` unchanged, and the
comparison decides from the result whether the output still agrees.

## See also

[`crt_receipt_read()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_read.md),
[`crt_receipt_validate()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_validate.md),
[`crt_receipt_compare()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_compare.md),
[`crt_table_fingerprint()`](https://newgraphenvironment.github.io/crate/reference/crt_table_fingerprint.md).

## Examples

``` r
dir <- file.path(tempdir(), "evidence")
dir.create(dir, showWarnings = FALSE)
access <- data.frame(segment = c("s1", "s2"), km = c(12.3456789012, 7.25))
write.csv(access, file.path(dir, "access_check.csv"), row.names = FALSE)

r <- crt_receipt_write(
  dir,
  output = list(name = "link_evidence", scope = "BULK"),
  recipe = list(
    code = list(link = list(commit = strrep("a", 40), version = "0.31.2", dirty = FALSE)),
    config = list(settings = list(species = I("CO"))),
    inputs = list(fwa = list(version_id = "3HL4kqtJlcpXroDTDmJ"))
  ),
  result = list(
    tables = list(access_check = access),
    parts = c(access_check = "access_check.csv"),
    summary = list(rows = 2L, km_total = sum(access$km)),
    tolerance = list(tables = list(access_check = list(km = 1e-9)),
                     summary = list(km_total = 1e-6))
  ),
  publish = TRUE
)
r$recipe$recipe_id
#> [1] "b61eb32306d67d8bcef8c87fed32aeff3681251bb70464956787675e901cd09b"
```
