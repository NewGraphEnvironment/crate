# List registered (source, file_name) entries crate knows how to ingest

Returns the registry as a tibble. Optionally filterable by `source`.
Output drives consumer-side config authoring: callers (e.g. link's
`lnk_load_overrides()`) use this to know what entries crate can handle.

## Usage

``` r
crt_files(source = NULL)
```

## Arguments

- source:

  Character or NULL. If supplied, filter to entries with that source
  family code (e.g. `"bcfp"`). NULL returns all entries.

## Value

A tibble with columns `source`, `file_name`, `kind`, `handler_fn`,
`schema_yaml`, `canonical_cols`. `kind` is `file` when crate reads the
source file and dispatches to a handler, or `schema_only` when crate
declares the canonical shape but the caller supplies the data — see
[`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md).

## See also

[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
to actually ingest a registered file.

## Examples

``` r
# All registered (source, file_name) entries
crt_files()
#> # A tibble: 5 × 6
#>   source file_name                   kind  handler_fn schema_yaml canonical_cols
#>   <chr>  <chr>                       <chr> <chr>      <chr>       <chr>         
#> 1 bcfp   user_habitat_classification file  crt_handl… schemas/bc… blue_line_key…
#> 2 nge    track_sessions              sche… NA         schemas/ng… project,sessi…
#> 3 nge    track_vertices              sche… NA         schemas/ng… project,sessi…
#> 4 nge    track_annotations           sche… NA         schemas/ng… project,sessi…
#> 5 nge    form_capture                sche… NA         schemas/ng… project,form,…

# Filter to bcfp-sourced entries
crt_files(source = "bcfp")
#> # A tibble: 1 × 6
#>   source file_name                   kind  handler_fn schema_yaml canonical_cols
#>   <chr>  <chr>                       <chr> <chr>      <chr>       <chr>         
#> 1 bcfp   user_habitat_classification file  crt_handl… schemas/bc… blue_line_key…

# Bogus source filter returns an empty tibble (not an error)
crt_files(source = "nonexistent")
#> # A tibble: 0 × 6
#> # ℹ 6 variables: source <chr>, file_name <chr>, kind <chr>, handler_fn <chr>,
#> #   schema_yaml <chr>, canonical_cols <chr>
```
