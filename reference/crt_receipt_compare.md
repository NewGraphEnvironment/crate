# Compare two provenance receipts

Judges a rebuild against its reference copy and answers with one of
three verdicts, naming every field that differed (crate#43):

## Usage

``` r
crt_receipt_compare(a, b, tables = NULL, keys = NULL)
```

## Arguments

- a, b:

  Receipts, as lists from
  [`crt_receipt_read()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_read.md),
  or paths to them. `a` is the reference copy.

- tables:

  Optional: `list(a = list(<table> = <data frame>), b = list(...))`, the
  two builds' tables to re-read.

- keys:

  Optional: the package's declaration, from
  [`crt_receipt_keys()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_keys.md),
  whose `register` overrides the default action for fields outside the
  recipe.

## Value

A list of class `crt_receipt_comparison`: `verdict`; `mode`,
`"receipts"` or `"bytes"`; and `differences`, a tibble with one row per
field that differed: `side` (`output`, `recipe`, `result` or `context`),
`field`, `action` (`refuse`, `warn`, `record`, or `within` for a
difference inside its tolerance), and `detail`.

## Details

- `identical`: the same recipe and the same result.

- `equivalent`: the same recipe, and every result value that differs is
  within the tolerance the output declares.

- `different`: another recipe, or a result value past its tolerance.

What a difference in each field does comes from the receipt register
(`inst/extdata/receipt/register.csv`), one row per field: `refuse` makes
the verdict `different`, `warn` is reported without changing it, and
`record` is listed only. Every recipe field refuses, because `recipe_id`
covers it; every context field is recorded, because the machine and the
toolchain are never part of an identity.

## Receipts or bytes

A comparison of receipts alone compares what the writers claimed. A
table whose fingerprints differ is then `different`, even when the
difference is a value that rounded the other way at the edge of its
tolerance (0.0000000014 and 0.0000000016 under 1e-9). Supply both
builds' tables and the comparison re-reads them: it checks each against
its own receipt's fingerprint, then compares their cells, and a table
whose cells all agree within tolerance is `equivalent`. The result's
`mode` says which was done.

A file whose bytes differ is `equivalent` only when its receipt names
the table it holds (`parts`, named, in
[`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md))
and that table agrees; a file that names no table, such as a raster
nobody fingerprinted, is `different`.

## Examples

``` r
wc <- system.file("extdata", "receipt", "examples", "worked_case", package = "crate")
crt_receipt_compare(file.path(wc, "build_1"), file.path(wc, "build_2"))
#> equivalent (receipts only)
#>   within result.parts[access_check.csv].bytes: 124 vs 128; table access_check agrees
#>   within result.parts[access_check.csv].sha256: "04994ff01cdee55d69fc410add51ad261ec4b33a751135fc224e97305823c3e2" vs "6801fb7bb092626441fd804d5ffbf8c4c05213ff18fa7c7ca524a9c2aa32f5e4"; table access_check agrees
#>   within result.summary[km_total]: 47.3767792597 vs 47.376779259805; within 1e-06
#>   record context.run: {"link_run_id":"20261104T181900Z-bulk"} vs {"link_run_id":"20261104T214400Z-bulk"}
#>   record context.time: "2026-11-04T18:22:05Z" vs "2026-11-04T21:47:31Z"
```
