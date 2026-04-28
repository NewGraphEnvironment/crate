# Ingest a registered upstream file and return canonical-shape data

Source-explicit dispatcher. Looks up `(source, file_name)` in the
registry, validates the input file's shape against known upstream
variants from the schema YAML, dispatches to the matching internal
handler, and returns a tibble in canonical shape.

## Usage

``` r
crt_ingest(source, file_name, path)
```

## Arguments

- source:

  Character. Source family code (e.g. `"bcfp"`).

- file_name:

  Character. Logical file name (e.g. `"user_habitat_classification"`).

- path:

  Character. Path to the source file (CSV today; future may accept S3
  URLs, postgres connections, etc. as the registered handler grows).

## Value

A tibble in the canonical shape declared by the schema YAML.

## Details

Use
[`crt_files()`](https://newgraphenvironment.github.io/crate/reference/crt_files.md)
to discover what `(source, file_name)` pairs are registered.

When upstream reshapes a CSV (e.g. long -\> wide), `crt_ingest()`
shields callers from the change: register the new shape as an
`upstream_variant` in the schema YAML and add a normalize handler, and
the same `crt_ingest()` call continues returning canonical output.

Throws on:

- Unknown `(source, file_name)` pair (not in registry)

- File at `path` does not exist

- Input file's shape does not match any known upstream variant

## See also

[`crt_files()`](https://newgraphenvironment.github.io/crate/reference/crt_files.md)
to list registered entries.

## Examples

``` r
# Read the bundled wide-format fixture (today's upstream shape)
wide_path <- system.file(
  "extdata/examples/bcfp/user_habitat_classification_wide.csv",
  package = "crate"
)
wide <- crt_ingest("bcfp", "user_habitat_classification", wide_path)
wide
#> # A tibble: 6 × 11
#>   blue_line_key downstream_route_measure upstream_route_measure
#>           <dbl>                    <dbl>                  <dbl>
#> 1     356385867                        0                    208
#> 2     356385867                        0                    208
#> 3     356400111                      500                   1500
#> 4     356400111                      500                   1500
#> 5     356500222                        0                    800
#> 6     356600333                        0                    300
#> # ℹ 8 more variables: watershed_group_code <chr>, species_code <chr>,
#> #   spawning <dbl>, rearing <dbl>, reviewer_name <chr>, review_date <date>,
#> #   source <chr>, notes <chr>

# Read the bundled long-format fixture (historical pre-2026-04-26 shape).
# crt_ingest pivots it to canonical wide automatically - same call,
# same output shape, regardless of which upstream variant arrived.
long_path <- system.file(
  "extdata/examples/bcfp/user_habitat_classification_long.csv",
  package = "crate"
)
long <- crt_ingest("bcfp", "user_habitat_classification", long_path)
long
#> # A tibble: 5 × 11
#>   blue_line_key downstream_route_measure upstream_route_measure
#>           <dbl>                    <dbl>                  <dbl>
#> 1     356385867                        0                    208
#> 2     356385867                        0                    208
#> 3     356400111                      500                   1500
#> 4     356400111                      500                   1500
#> 5     356500222                        0                    800
#> # ℹ 8 more variables: watershed_group_code <chr>, species_code <chr>,
#> #   spawning <int>, rearing <int>, reviewer_name <chr>, review_date <date>,
#> #   source <chr>, notes <chr>

# Both calls return the same canonical column set
identical(names(wide), names(long))
#> [1] TRUE
```
