# Name the known version each record was captured with

Looks up each row's `schema_version` fingerprint among the upstream
variants a registered schema lists, and returns the variant's `id`. A
fingerprint the schema does not list comes back `NA`: a capture shape
nobody has recorded yet, which is worth looking at rather than guessing
at.

## Usage

``` r
crt_schema_variant(df, source, file_name)
```

## Arguments

- df:

  A data frame, usually the output of
  [`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md).

- source:

  Character. Source family code (e.g. `"nge"`).

- file_name:

  Character. Logical file name (e.g. `"form_pscis"`).

## Value

A character vector, one element per row of `df`: the variant `id`, or
`NA` where the fingerprint is not listed or is missing.

## Details

A fingerprint describes a column set, so on its own it cannot say which
build of a form a record came from. Each per-form schema therefore lists
its form's known versions as `upstream_variants`, each with the
fingerprint a capture of it produces. That names the version of forms
already in the field, with no change to the deployed forms.

[`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md)
reports unlisted fingerprints as a warning of class
`crate_unknown_fingerprint`, for schemas that list any. This function is
how to find which rows they were.

Throws when `df` has no `schema_version` column, or the schema lists no
fingerprints.

## See also

[`crt_schema_fingerprint()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_fingerprint.md)
for how a fingerprint is computed.

## Examples

``` r
types <- c(date_time_start = "DATETIME", crew_members = "TEXT")
records <- data.frame(record_id = 1L, schema_version = crt_schema_fingerprint(types))
crt_schema_variant(records, "nge", "form_monitoring_fish_passage")
#> [1] NA
```
