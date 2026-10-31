# Fingerprint a capture's column set

Computes the `schema_version` value the `nge/form_capture` schema
declares: `<n>-<digest>`, where `n` is the number of columns and
`digest` is the 64-bit xxHash, in hex, of the columns' `name:TYPE` pairs
sorted by name and joined with commas.

## Usage

``` r
crt_schema_fingerprint(types)
```

## Arguments

- types:

  Named character vector of declared column types, one element per
  column, names being the column names.

## Value

A string, `<n>-<16 hex digits>`.

## Details

The rule lives here so that every producer computes it the same way. Two
producers that differed would give two different vintages the same
version, or one vintage two versions, and nothing downstream could tell.

## What goes in

Pass the capture's **own** columns with the types the file declares, as
a named character vector:
`c(date_time_start = "DATETIME", gravel = "REAL")`. For a GeoPackage
that is `PRAGMA table_info()`'s `type`. Leave out the geometry column
and any surrogate row id the reader supplies rather than the capture
carrying, such as a GeoPackage `fid`.

Types are part of the pair because a column that changes type between
vintages is a real schema change, and a fingerprint of names alone would
report it as none. They are upper-cased first, so `real` and `REAL`
agree. Names are sorted in C collation, so the value does not depend on
the machine's locale, and column order does not move it.

## What gets hashed

The bytes of the joined string, not R's serialization of it. A hash of a
serialized object depends on the serialization format, which R can
change without any schema change behind it, and no other language could
reproduce it. The digest is the standard XXH64 with seed 0, so any
implementation of it gives the same value from the same string.

## Examples

``` r
types <- c(date_time_start = "DATETIME", wetted_width_m = "REAL",
           crew_members = "TEXT")
crt_schema_fingerprint(types)
#> [1] "3-53a53c8bae8940fa"

# Column order does not matter; a changed type does.
crt_schema_fingerprint(rev(types))
#> [1] "3-53a53c8bae8940fa"
crt_schema_fingerprint(replace(types, "wetted_width_m", "TEXT"))
#> [1] "3-6240cab34f1c197c"
```
