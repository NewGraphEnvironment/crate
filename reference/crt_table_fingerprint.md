# Fingerprint a table's values

Computes the value a provenance receipt stores in `result.fingerprint`
for a table: the SHA-256, in lowercase hex, of the table's canonical
form. Two tables with the same rows in any order, and the same columns
in any order, have the same fingerprint; any changed value changes it,
except a double moved less than its declared tolerance's rounding.

## Usage

``` r
crt_table_fingerprint(x, tolerance = NULL)
```

## Arguments

- x:

  A data frame.

- tolerance:

  A named numeric vector or list: for each double column that is allowed
  to move between equivalent builds, its absolute tolerance, a power of
  ten from `1` to `1e-15`. Columns not named are fingerprinted exactly.

## Value

A string of 64 lowercase hex digits.

## Details

Not
[`crt_schema_fingerprint()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_fingerprint.md),
which hashes a table's column names and types and never its values.

## The canonical form

The RFC 8785 canonical JSON of
`{"columns": [...], "rows": [[...], ...]}`, so any language with a JCS
serializer and SHA-256 reproduces it (crate#43):

- Columns are sorted by name, as UTF-8 bytes (C collation).

- Every cell is a JSON string, or `null` for `NA`.

- Character values are their UTF-8 text, not Unicode-normalized; factors
  are their labels.

- Integers are their decimal digits; logicals are `true` and `false`.

- A double with a declared tolerance `10^-k` is written with exactly `k`
  decimals, rounding its exact binary value with ties to even, as C's
  `printf` and Python's `format(x, ".kf")` do. With no tolerance it is
  written in ECMAScript's shortest round-trip form, so it is exact. A
  zero is written without a sign. `NaN` and infinite values abort.

- Dates are `YYYY-MM-DD`. Datetimes are converted to UTC and written
  `YYYY-MM-DDTHH:MM:SSZ`; one with fractional seconds aborts, so round
  it or fingerprint it as a number.

- Rows are sorted by the UTF-8 bytes of each row's own canonical JSON.

## Examples

``` r
a <- data.frame(segment = c("b", "a"), km = c(12.5, 3.0000000001))
b <- data.frame(km = c(3.0000000002, 12.5), segment = c("a", "b"))

# Different rows order, column order and an 11th-decimal difference
crt_table_fingerprint(a) == crt_table_fingerprint(b)
#> [1] FALSE
crt_table_fingerprint(a, c(km = 1e-9)) == crt_table_fingerprint(b, c(km = 1e-9))
#> [1] TRUE
```
