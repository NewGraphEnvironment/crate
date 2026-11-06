# Read a provenance receipt

Read a provenance receipt

## Usage

``` r
crt_receipt_read(path)
```

## Arguments

- path:

  Path to a `receipt.json`, or to the directory holding one.

## Value

The receipt as a list, as
[`jsonlite::read_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html)
gives it with `simplifyVector = FALSE`: objects are named lists, arrays
unnamed ones.

## See also

[`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md),
[`crt_receipt_validate()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_validate.md).

## Examples

``` r
r <- crt_receipt_read(system.file("extdata", "receipt", "examples", "worked_case",
                                  "build_1", package = "crate"))
r$recipe$recipe_id
#> [1] "b06f982dd07b5e44edf586519e5d6ab60b29715a051c3827fba647230636f977"
```
