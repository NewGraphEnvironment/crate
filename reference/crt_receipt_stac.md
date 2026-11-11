# A receipt's fields as a STAC item mirrors them

Executes the STAC rows of the receipt mapping (`STAC item` in
`inst/extdata/receipt/mapping/v1.1.0/mapping.csv`, published at
`https://newgraphenvironment.github.io/crate/receipt/mapping/v1.1.0/mapping.csv`)
for one receipt: the item properties and asset fields that let a STAC
client or a pgstac queryable read a build's identity without fetching
its receipt (crate#59). The receipt stays the full record. Every
implementation of the mapping runs the vectors in
`mapping/v1.1.0/stac.json`, so two of them agree on every item.

## Usage

``` r
crt_receipt_stac(
  receipt,
  assets = NULL,
  receipt_asset = NULL,
  receipt_sha256 = NULL
)
```

## Arguments

- receipt:

  A receipt, as a list from
  [`crt_receipt_read()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_read.md),
  or a path to one.

- assets:

  A named character vector: each asset's key, and as its value the
  asset's href relative to the item, which is the path a part is keyed
  by. `NULL` for none.

- receipt_asset:

  The key of the asset that links the receipt, or `NULL`.

- receipt_sha256:

  With `receipt_asset`: the SHA-256 of the published receipt's bytes, as
  [`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md)
  returns it.

## Value

A list of `stac_extensions` (a character vector marked
[`I()`](https://rdrr.io/r/base/AsIs.html), so a JSON writer keeps it an
array), `properties` and `assets` (named lists).

## What it mirrors

- `properties`: `receipt:recipe_id` from `recipe.recipe_id`, left out
  for a migrated receipt (`output.migrated_from`), which claims no
  recipe identity, and refused when missing on any other: the item never
  publishes a null one; `processing:datetime` from `context.time`, which
  is required; `processing:software`, one entry per repository in
  `recipe.code` that has a `version`, and left out when none has.

- A block or entry present but not an object, `null` included, is
  refused, never read as absent.

## Refusals

A receipt or an argument the mapping cannot place is refused with an
error of class `crate_stac_refused`, whose `code` field names what was
refused: the same codes the `error` field of `stac.json` carries, so an
implementation's refusals can be compared by code rather than by
message. The receipt must be of the form this mapping reads
(`output.receipt_version` 1.0.0), as
[`crt_receipt_read()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_read.md)
requires of a file; a character `receipt` is read as a path.

- `assets`: for each asset in `assets`, the part its href names, as
  `file:checksum` (multihash: `1220` and the part's `sha256`) and
  `file:size` (its `bytes`). A part no asset names is not mirrored,
  since an item may publish fewer files than the build made; two assets
  may name one part. An asset whose href names no part is an error: the
  item would otherwise carry a guessed checksum or none.

- The receipt asset, named by `receipt_asset`: `file:checksum` only, the
  multihash of `receipt_sha256`, the digest
  [`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md)
  returned for the bytes it wrote. Never from a part, since a receipt is
  not one of its own parts, and with no `file:size`, deliberately: the
  digest identifies the bytes (crate#60).

- `stac_extensions`: the file, processing and receipt extension URLs, in
  that order, each only when one of its fields is present.

Merge the result into the item being built. Nothing else of the item
(its id, geometry, other assets' hrefs, types and roles) comes from the
receipt.

## See also

[`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md),
[`crt_receipt_read()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_read.md).

## Examples

``` r
wc <- system.file("extdata", "receipt", "examples", "worked_case", "build_1",
                  package = "crate")
digest <- digest::digest(file.path(wc, "receipt.json"), algo = "sha256", file = TRUE)
s <- crt_receipt_stac(wc, assets = c(access = "access_check.csv"),
                      receipt_asset = "receipt", receipt_sha256 = digest)
s$properties
#> $`receipt:recipe_id`
#> [1] "b06f982dd07b5e44edf586519e5d6ab60b29715a051c3827fba647230636f977"
#> 
#> $`processing:datetime`
#> [1] "2026-11-04T18:22:05Z"
#> 
#> $`processing:software`
#> $`processing:software`$knowledge
#> [1] "0.14.0"
#> 
#> $`processing:software`$link
#> [1] "0.31.2"
#> 
#> 
str(s$assets)
#> List of 2
#>  $ access :List of 2
#>   ..$ file:checksum: chr "122004994ff01cdee55d69fc410add51ad261ec4b33a751135fc224e97305823c3e2"
#>   ..$ file:size    : int 124
#>  $ receipt:List of 1
#>   ..$ file:checksum: chr "12200a51e33a6fbea388844c577746bad6ce10293291fc2185fa84e34a1f9d94a44c"
```
