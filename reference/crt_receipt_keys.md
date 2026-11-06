# Read a package's receipt declaration

Each package declares, as data beside the code that writes an output,
what only it knows about that output's receipt: which inputs, settings
and config files are its recipe, which tables are fingerprinted with
what tolerances, which summary values it reports, and any change to what
a difference in a field does. crate reads the declaration; the package
never re-implements the hashing (crate#43).

## Usage

``` r
crt_receipt_keys(path)
```

## Arguments

- path:

  Path to the YAML declaration.

## Value

A list of class `crt_receipt_keys`: `output`, `config_files`,
`settings`, `inputs`, `seed`, `tables`, `summary`, `tolerance` and
`register`.

## The declaration

A YAML file:

    receipt_keys: 1
    output: link_evidence
    recipe:
      config_files: [inst/method/settings.csv]
      settings: [species, watershed_group]
      inputs: [flow, fwa_stream_networks]
      seed: false
    result:
      tables:
        access_check:
          tolerance: {km: 1.0e-9}
        visits_link: {}
      summary:
        rows: {}
        km_total: {tolerance: 1.0e-6}
    register:
      output.schema: record

Write a tolerance with a decimal point (`1.0e-9`): YAML reads `1e-9` as
a string, which is accepted, but `1.0e-9` is a number everywhere.
`register` may only soften or harden fields outside the recipe: every
recipe field refuses, because `recipe_id` covers it.

Pass the result to
[`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md)
as `keys`, which then takes the tolerances from it and refuses inputs,
settings, config files or tables the declaration does not list, or lacks
ones it does; and to
[`crt_receipt_compare()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_compare.md),
which applies `register`.

## Examples

``` r
keys <- crt_receipt_keys(system.file("extdata", "receipt", "examples",
                                     "receipt_keys.yaml", package = "crate"))
keys$tolerance
#> $tables
#> $tables$access_check
#> $tables$access_check$km
#> [1] 1e-09
#> 
#> 
#> 
#> $summary
#> $summary$km_total
#> [1] 1e-06
#> 
#> 
```
