# Conform a data frame to a registered canonical schema

Validates that every required canonical column is present, then coerces
every declared column to its canonical type. Returns the conformed
tibble.

## Usage

``` r
crt_schema_conform(df, source, file_name)
```

## Arguments

- df:

  A data frame.

- source:

  Character. Source family code (e.g. `"nge"`).

- file_name:

  Character. Logical file name (e.g. `"track_sessions"`).

## Value

A tibble conformed to the canonical schema for that entry.

## Details

This is the entry point for data crate did not read.
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
reads a registered CSV and dispatches to a handler before conforming; a
caller that already has a data frame — from a database, a spatial file,
an API — comes here directly. Both paths run the same validation and
typing, because
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
calls this function.

Use
[`crt_files()`](https://newgraphenvironment.github.io/crate/reference/crt_files.md)
to discover what `(source, file_name)` pairs are registered.

Presence is checked before types are applied, because a missing required
column would otherwise become a column of `NA` at coercion and the
failure would surface far from its cause.

What this does **not** do is reject columns the schema does not declare
— extra columns pass through untouched. A caller that wants the
canonical set to be exhaustive should assert that itself; the schema
declares a floor, not a ceiling.

Throws on an unknown `(source, file_name)` pair, on a missing required
column, and on a schema declaring a type crate does not support.

## See also

[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
to read and conform a registered file in one call,
[`crt_files()`](https://newgraphenvironment.github.io/crate/reference/crt_files.md)
to list registered entries.

## Examples

``` r
# A frame that is already in canonical shape passes through, typed.
path <- system.file(
  "extdata/examples/bcfp/user_habitat_classification_wide.csv",
  package = "crate"
)
raw <- readr::read_csv(path, show_col_types = FALSE)
conformed <- crt_schema_conform(raw, "bcfp", "user_habitat_classification")
conformed
#> # A tibble: 6 × 11
#>   blue_line_key downstream_route_measure upstream_route_measure
#>           <int>                    <dbl>                  <dbl>
#> 1     356385867                        0                    208
#> 2     356385867                        0                    208
#> 3     356400111                      500                   1500
#> 4     356400111                      500                   1500
#> 5     356500222                        0                    800
#> 6     356600333                        0                    300
#> # ℹ 8 more variables: watershed_group_code <chr>, species_code <chr>,
#> #   spawning <int>, rearing <int>, reviewer_name <chr>, review_date <chr>,
#> #   source <chr>, notes <chr>

# The schema declares blue_line_key as integer; readr guessed double.
class(raw$blue_line_key)
#> [1] "numeric"
class(conformed$blue_line_key)
#> [1] "integer"
```
