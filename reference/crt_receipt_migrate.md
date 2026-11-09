# Read an older provenance record as a receipt

Reads a `manifest.json` or `provenance.json` written before its package
moved to receipts, through the receipt mapping table
(`inst/extdata/receipt/mapping/v1.0.0/mapping.csv`, published at
`https://newgraphenvironment.github.io/crate/receipt/mapping/v1.0.0/mapping.csv`),
so existing records stay readable in the receipt's keys while writers
converge forward, each when it is next touched (crate#43). The mapping
is versioned on its own (crate#58): a row change is a new mapping
version, and never moves the receipt's form.

## Usage

``` r
crt_receipt_migrate(
  x,
  format,
  section = NULL,
  name = NULL,
  time = NULL,
  path = NULL
)
```

## Arguments

- x:

  Path to the record, or the record as a list from
  [`jsonlite::read_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html).

- format:

  The record's format; see Formats.

- section:

  For a record holding several outputs: the path to one, its parts
  separated by `/`.

- name:

  The output's name, when the record carries none. Defaults to `section`
  for a section of a record.

- time:

  UTC time in ISO 8601 with a trailing `Z`, when the record carries
  none.

- path:

  Optional: where to write the receipt, a file or a directory (which
  gets `receipt.json`). It is written as
  [`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md)
  writes, canonical JSON pretty-printed, so
  [`crt_receipt_read()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_read.md)
  reads it back to the same bytes.

## Value

A receipt, as a list, invisibly when `path` is given. Compare it with
[`crt_receipt_compare()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_compare.md).

## Details

A migrated receipt has no recipe identity: an older record lacks fields
a recipe needs (resolved settings, a seed, inputs' own ids), so
`recipe.recipe_id` is null, `output.migrated_from` names the format, and
[`crt_receipt_compare()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_compare.md)
reports its recipe as unknown. Fields the mapping places nowhere are
kept verbatim in `context.legacy`, keyed by their path in the record.
Fields the mapping does not know at all go there too, and are reported
with a warning of class `crate_receipt_unmapped`, so nothing is dropped
silently.

## Formats

- `"link manifest.json"`: link's export manifest.

- `"floodplains provenance.json"`: one section of floodplains' per-area
  record, named by `section`, such as `"floodplain/all_ff02"` or
  `"network/CO3"`.

The mapping table also lists STAC's keys (`file:checksum`, `file:size`,
`processing:software`, `processing:datetime`) beside the receipt keys
they mirror.

## Examples

``` r
rec <- system.file("extdata", "receipt", "examples", "legacy", "link_manifest.json",
                   package = "crate")
r <- crt_receipt_migrate(rec, "link manifest.json")
r$recipe$code
#> $link
#> $link$version
#> [1] "0.31.2"
#> 
#> $link$commit
#> [1] "a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0"
#> 
#> $link$dirty
#> [1] FALSE
#> 
#> 
```
