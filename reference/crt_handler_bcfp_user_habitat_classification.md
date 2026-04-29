# Internal handler dispatcher: bcfp/user_habitat_classification

Called by
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
via the registry's `handler_fn` lookup. Dispatches on `variant_id`
(matched upstream from schema YAML) to the appropriate normalization
path. Returns canonical wide-shape tibble.

## Usage

``` r
crt_handler_bcfp_user_habitat_classification(raw, variant_id)
```

## Arguments

- raw:

  A data frame returned by
  [`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)
  against the source CSV.

- variant_id:

  Character. The upstream variant id matched by
  [`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
  against the schema YAML. One of: `"2026-04-26-wide"`,
  `"pre-2026-04-26-long"`.

## Value

A tibble in canonical wide shape (per
`inst/extdata/schemas/bcfp/user_habitat_classification.yaml`).

## Details

Not exported. See
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
for the public API.
