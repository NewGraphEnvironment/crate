# crate

> Stable file readers for shape-shifting data sources.

When external data we depend on changes shape — columns renamed, types
swapped, layouts flipped — code that reads those files breaks. crate is
the one place that knows about all the shape variations.

Call `crt_ingest("source", "file_name", path)` from anywhere. Same call,
same output, regardless of which version of the upstream file landed.
When upstream changes shape again, fix it once in crate; everywhere
downstream keeps working.

## Installation

``` r
pak::pak("NewGraphEnvironment/crate")
```

## Example

The bundled example shows the value. smnorris (who maintains
[bcfishpass](https://github.com/smnorris/bcfishpass)) reshaped
`user_habitat_classification.csv` from “long” to “wide” format on
2026-04-26. crate handles both:

``` r
library(crate)

# What sources + files does crate know how to ingest?
crt_files()
#> # A tibble: 1 × 5
#>   source file_name                   handler_fn                              schema_yaml                                       canonical_cols
#>   <chr>  <chr>                       <chr>                                   <chr>                                             <chr>
#> 1 bcfp   user_habitat_classification internal_bcfp_user_habitat_classifica… schemas/bcfp/user_habitat_classification.yaml     blue_line_key,…

# Ingest a bundled wide-format example fixture (today's upstream shape)
wide_path <- system.file(
  "extdata/examples/bcfp/user_habitat_classification_wide.csv",
  package = "crate"
)
wide <- crt_ingest("bcfp", "user_habitat_classification", wide_path)

# Ingest the bundled long-format historical fixture — same call,
# crate pivots it to canonical wide automatically
long_path <- system.file(
  "extdata/examples/bcfp/user_habitat_classification_long.csv",
  package = "crate"
)
long <- crt_ingest("bcfp", "user_habitat_classification", long_path)

# Both calls return the same canonical column set
identical(names(wide), names(long))
#> [1] TRUE
```

When the next upstream reshape happens, the fix is one PR in crate —
register the new shape as an `upstream_variant` in the schema YAML and
add a small pivot function. Code calling
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
doesn’t change.

See the [function
reference](https://newgraphenvironment.github.io/crate/reference/) and
[browse the
schemas](https://github.com/NewGraphEnvironment/crate/tree/main/inst/extdata/schemas).

## What crate handles today

One source family, one file:

- `bcfp` (files from
  [smnorris/bcfishpass](https://github.com/smnorris/bcfishpass))
  - `user_habitat_classification` — handles both pre-2026-04-26 long and
    current 2026-04-26 wide upstream variants

More land as integration work surfaces. Each addition = a YAML in
`inst/extdata/schemas/` + a small R function + a registry row. See
[`inst/extdata/schemas/README.md`](https://newgraphenvironment.github.io/crate/inst/extdata/schemas/README.md)
for the format.

## Sibling public packages

[fresh](https://github.com/NewGraphEnvironment/fresh),
[link](https://github.com/NewGraphEnvironment/link),
[flooded](https://github.com/NewGraphEnvironment/flooded),
[gq](https://github.com/NewGraphEnvironment/gq),
[fpr](https://github.com/NewGraphEnvironment/fpr),
[ngr](https://github.com/NewGraphEnvironment/ngr).

## Adding a new schema or source

See
[`inst/extdata/schemas/README.md`](https://newgraphenvironment.github.io/crate/inst/extdata/schemas/README.md)
for the schema YAML format and
[`decisions/README.md`](https://newgraphenvironment.github.io/crate/decisions/README.md)
for when (and why) to write a decision log entry.
