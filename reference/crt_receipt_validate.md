# Validate a provenance receipt

Checks a receipt against the receipt JSON Schema installed with crate,
then recomputes its `recipe_id`, which the schema cannot check.

## Usage

``` r
crt_receipt_validate(x, error = TRUE)
```

## Arguments

- x:

  A receipt, as a list from
  [`crt_receipt_read()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_read.md),
  or a path to one.

- error:

  If `TRUE` (the default), abort on an invalid receipt, listing what is
  wrong; if `FALSE`, return `FALSE` with the problems as attribute
  `errors`.

## Value

`TRUE`, invisibly, for a valid receipt.

## Requires

the jsonvalidate package.

## Examples

``` r
if (requireNamespace("jsonvalidate", quietly = TRUE)) {
  crt_receipt_validate(system.file("extdata", "receipt", "examples", "worked_case",
                                   "build_1", package = "crate"))
}
```
