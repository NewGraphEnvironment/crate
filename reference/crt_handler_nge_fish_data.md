# Internal handler dispatcher: nge/fish_data

Called by
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
via the registry's `handler_fn` lookup. Dispatches on `variant_id`
(matched upstream from schema YAML) to the rename for that file shape,
then returns every canonical column, in schema order, with a column the
shape did not record present and null. So every season comes back with
the same columns, and even
[`rbind()`](https://rdrr.io/r/base/cbind.html) stacks them.

## Usage

``` r
crt_handler_nge_fish_data(raw, variant_id)
```

## Arguments

- raw:

  A data frame returned by
  [`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)
  against the source CSV.

- variant_id:

  Character. The upstream variant id matched by
  [`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
  against the schema YAML. One of: `"2023-peace-6col"`,
  `"2023-skeena-7col"`, `"2024-field-sheet"`.

## Value

A tibble with the canonical columns of
`inst/extdata/schemas/nge/fish_data.yaml`, untyped:
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
types it through
[`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md).

## Details

Not exported. See
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
for the public API.
