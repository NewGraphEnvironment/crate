# crate

> Canonical schemas and source-explicit ingest dispatcher for New Graph
> Environment data.

Insulates downstream consumers (link, fresh, reporting repos) from
upstream-shape variability. Schemas, decision logs, and adapter
functions live together so a schema change becomes one declarative
artifact + one normalize handler — not a multi-repo cascade.

## Installation

``` r
pak::pak("NewGraphEnvironment/crate")
```

## Example

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
  "extdata/examples/bcfp/wide_user_habitat_classification.csv",
  package = "crate"
)
wide <- crt_ingest("bcfp", "user_habitat_classification", wide_path)

# Ingest the bundled long-format historical fixture — same call,
# crate pivots it to canonical wide automatically
long_path <- system.file(
  "extdata/examples/bcfp/long_user_habitat_classification.csv",
  package = "crate"
)
long <- crt_ingest("bcfp", "user_habitat_classification", long_path)

# Both calls return the same canonical column set
identical(names(wide), names(long))
#> [1] TRUE
```

When upstream reshapes a CSV (e.g. long → wide), the same
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
call keeps returning canonical output — register the new shape as an
`upstream_variant` in the schema YAML, add a normalize handler, and
downstream consumers don’t need to know.

See the [function
reference](https://newgraphenvironment.github.io/crate/reference/) for
the public API and [browse the
schemas](https://github.com/NewGraphEnvironment/crate/tree/main/inst/extdata/schemas)
to see what canonical shapes look like.

## How it fits in the NGE ecosystem

| Repo                                                      | Role                                      | Analogy        |
|-----------------------------------------------------------|-------------------------------------------|----------------|
| [compass](https://github.com/NewGraphEnvironment/compass) | Ethics, values                            | The “why”      |
| [soul](https://github.com/NewGraphEnvironment/soul)       | LLM conventions                           | The “how”      |
| [compost](https://github.com/NewGraphEnvironment/compost) | Communications                            | The “who”      |
| [rtj](https://github.com/NewGraphEnvironment/rtj)         | Infrastructure / IaC                      | The “where”    |
| [gq](https://github.com/NewGraphEnvironment/gq)           | Cartographic style                        | The “look”     |
| **crate**                                                 | **Canonical schemas + ingest dispatcher** | **The “what”** |

crate is the data-governance layer — declarative schemas as the source
of truth,
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
as the executable adapter that downstream packages (`link`, `fresh`,
reporting) consume. See `crate/CLAUDE.md` for the boundary with `rfp`
(the field-project lifecycle package — different role, different scope).

## Adding a new schema or source

See
[`inst/extdata/schemas/README.md`](https://newgraphenvironment.github.io/crate/inst/extdata/schemas/README.md)
for the schema YAML format and
[`decisions/README.md`](https://newgraphenvironment.github.io/crate/decisions/README.md)
for when (and why) to write a decision log entry.
