# Provenance receipts

A receipt is one JSON file per output that says what the output is, how
it was made, what came out, and where and when. Every package and
catalogue that publishes a table, raster, model or STAC item is to write
its receipts in this one shape, so any rebuild can be compared with a
reference copy and answered **identical**, **equivalent** within a
declared tolerance, or **different**, naming what differed.

crate holds the contract in a form any language can implement (a JSON
Schema, a canonical JSON rule, a fingerprint specification, a register
of what each difference does, a mapping from older records, and test
vectors) and one R implementation of it. `stacs.receipt` is a Python
implementation for STAC catalogues that runs the same vectors
([crate#43](https://github.com/NewGraphEnvironment/crate/issues/43),
[stacs#12](https://github.com/NewGraphEnvironment/stacs/issues/12)).
This vignette is the contract’s reference.

``` r

library(crate)
```

## Two questions, three answers

A rebuild asks two questions. **Was it made the same way?** That is the
recipe: code, config, the inputs’ identities, a seed. **Did it come out
the same?** That is the result. The same recipe can give slightly
different results on another machine or another day, through row order,
float summation order, or a model fitted with random draws, so
“equivalent” has to be an answer in its own right:

| verdict | recipe | result |
|----|----|----|
| `identical` | the same | the same |
| `equivalent` | the same | every value that differs is within its declared tolerance |
| `different` | another | or a value past its tolerance |

## The worked case

One link build’s evidence was built twice from the same code
(knowledge#145). Three tables came out byte-identical. The fourth,
`access_check`, had the same rows and counts but differed in the 11th
decimal place, at most 9.5e-11 km, because the database summed in
another order. crate ships a synthetic copy of the two builds, each with
its receipt:

``` r

wc <- system.file("extdata", "receipt", "examples", "worked_case", package = "crate")
list.files(file.path(wc, "build_1"))
#> [1] "access_check.csv"   "receipt.json"       "visits_link.csv"   
#> [4] "visits_species.csv" "walks.csv"
read.csv(file.path(wc, "build_1", "access_check.csv"))
#>   segment accessible       km
#> 1    S010       TRUE 12.34568
#> 2    S011       TRUE  3.14000
#> 3    S012      FALSE  0.87500
#> 4    S013       TRUE 31.01610
read.csv(file.path(wc, "build_2", "access_check.csv"))
#>   segment accessible       km
#> 1    S010       TRUE 12.34568
#> 2    S011       TRUE  3.14000
#> 3    S012      FALSE  0.87500
#> 4    S013       TRUE 31.01610
```

The output declares a tolerance of `1e-9` on `km`, so both receipts
carry the same fingerprint for `access_check`, and the comparison
answers `equivalent`:

``` r

crt_receipt_compare(file.path(wc, "build_1"), file.path(wc, "build_2"))
#> equivalent (receipts only; register v1.0.0)
#>   within result.parts[access_check.csv].bytes: 124 vs 128; table access_check agrees
#>   within result.parts[access_check.csv].sha256: "04994ff01cdee55d69fc410add51ad261ec4b33a751135fc224e97305823c3e2" vs "6801fb7bb092626441fd804d5ffbf8c4c05213ff18fa7c7ca524a9c2aa32f5e4"; table access_check agrees
#>   within result.summary[km_total]: 47.3767792597 vs 47.376779259805; within 1e-06
#>   record context.run: {"link_run_id":"20261104T181900Z-bulk"} vs {"link_run_id":"20261104T214400Z-bulk"}
#>   record context.time: "2026-11-04T18:22:05Z" vs "2026-11-04T21:47:31Z"
```

`access_check.csv`’s bytes differ, but the receipt says that file holds
the `access_check` table, whose fingerprint agrees; `km_total` differs
within its `1e-6`; the run identifiers and times are context, recorded
and never part of an identity.

## The four blocks

``` r

r <- crt_receipt_read(file.path(wc, "build_1"))
names(r)
#> [1] "context" "output"  "recipe"  "result"
```

**`output`**: what the thing is. Not hashed.

| field             |                                                      |
|-------------------|------------------------------------------------------|
| `name`            | the output’s name                                    |
| `scope`           | its partition (a watershed group, a region), or null |
| `receipt_version` | `"1.0.0"`                                            |
| `schema`          | the crate schema the output conforms to, or null     |
| `migrated_from`   | only in a receipt read from an older record          |

**`recipe`**: how it was made. Its identity is `recipe_id`.

| field |  |
|----|----|
| `code` | keyed by repository of ours: `commit` (40 hex), `version`, `dirty` |
| `config` | `files` (keyed by path: the SHA-256 of its bytes) and `settings` (the resolved run settings, verbatim) |
| `inputs` | keyed by input name: exactly one of `recipe_id`, `version_id`, `sha256`, or `none` (why neither) |
| `seed` | the seed of any fit, or null |
| `recipe_id` | SHA-256 over the canonical JSON of the fields above |

**`result`**: what came out.

| field |  |
|----|----|
| `fingerprint` | keyed by table: `sha256`, `rows` |
| `parts` | keyed by path relative to the receipt: `bytes`, `sha256`, and `table` where the file holds a fingerprinted table |
| `summary` | keyed by name: a number (`rows`, `km_total`) |
| `tolerance` | `tables` (table, then column: a tolerance) and `summary` (name: a tolerance) |

**`context`**: where and when. Never part of an identity.

| field |  |
|----|----|
| `time` | UTC, ISO 8601 with a trailing `Z` |
| `host` | optional; left out of a receipt that is published |
| `run`, `session` | run identifiers, a note |
| `toolchain` | third-party versions: R, GDAL, terra, arrow |
| `lockfile_sha256` | the SHA-256 of `renv.lock`, or null |
| `inputs` | each input’s own result, for reporting |
| `legacy` | in a migrated receipt, the older record’s fields with no receipt key |

The schema is published at
`https://newgraphenvironment.github.io/crate/receipt/v1.0.0/schema.json`
and installed with crate. A published version is never edited.

**Three parts of the contract are versioned, each on its own**
([crate#58](https://github.com/NewGraphEnvironment/crate/issues/58)).
The schema is the receipt’s form, and its version is the one a receipt
carries in `output.receipt_version`. The register decides what a
difference in each field does to a comparison, and a comparison names
the register version it was judged under. The mapping turns an older
record into a receipt. A change to the register or the mapping is a new
version of that part only: it never moves the number on a receipt,
because a receipt’s form has not changed. Each register version covers
one form version. The rules and every release are in the
[changelog](https://newgraphenvironment.github.io/crate/receipt/CHANGELOG.md).

## What goes where, and why

- **Toolchain versions are context; a seed is recipe; resolved run
  settings are config.** A GDAL upgrade alone should read “same recipe”
  and let the result decide. A different seed draws differently, so it
  is another recipe. Two runs that differ only in a command-line
  argument are two recipes.
- **`recipe_id` hashes each input’s recipe identity, never its result.**
  An input rebuilt equivalently has a new result; folding that into
  `recipe_id` would make everything downstream `different`. Input
  results go in `context.inputs`, for reporting.
- **Collections are objects keyed by name, never arrays,** because
  canonical JSON sorts object keys and leaves arrays in the order given:
  two writers listing the same inputs in another order would otherwise
  compute two ids.
- **crate owns every part that must agree byte for byte; each package
  declares what only it knows**: which inputs and settings are recipe,
  which tables are fingerprinted, and their tolerances.

## The canonical forms

Everything hashed is hashed as bytes of a declared form, never a
language’s serialization.

### Canonical JSON

RFC 8785, the JSON Canonicalization Scheme: object keys sorted by their
UTF-16 code units; strings escaped only where JSON requires (`"`, `\`,
`\b \t \n \f \r`, other control characters as `\u00xx` in lowercase
hex); numbers in ECMAScript’s shortest round-trip form, in plain decimal
from 1e-7 to 1e21 and in exponent form outside it (`1e+21`, `1e-7`,
`333333333.3333333`); no whitespace.

Two things trip implementations. **Read every JSON number as a double**:
Python’s `json` reads `1152921504606846976` as an `int`, which `rfc8785`
refuses past 2^53, so parse with `parse_int=float`. **The shortest
spelling needs a correctly rounded decimal parser**: R’s
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) misread 84% of
200,000 random 17-digit spellings on arm64 macOS, where long double is
double, so crate reads candidates back through jsonlite, which uses the
C library’s `strtod`.

### `recipe_id`

The SHA-256, lowercase hex, of the UTF-8 bytes of the canonical JSON of
the `recipe` block without its `recipe_id`:

``` r

r$recipe$recipe_id
#> [1] "b06f982dd07b5e44edf586519e5d6ab60b29715a051c3827fba647230636f977"
```

### The table fingerprint

[`crt_table_fingerprint()`](https://newgraphenvironment.github.io/crate/reference/crt_table_fingerprint.md)
is the SHA-256 of the canonical JSON of
`{"columns": [...], "rows": [[...], ...]}`:

- Columns are sorted by name as UTF-8 bytes.
- Every cell is a string, or `null` for NA. Text is its UTF-8, not
  normalized; a factor is its label.
- Integers are their digits; logicals `true` and `false`.
- A double with a declared tolerance `10^-k` is written with exactly `k`
  decimals, rounding its exact binary value with ties to even, as C’s
  `printf("%.*f")` and Python’s `format(x, ".kf")` do. Without a
  tolerance it is written in the shortest round-trip form above. A zero
  has no sign. NaN and infinities are refused.
- Dates are `YYYY-MM-DD`; datetimes are UTC `YYYY-MM-DDTHH:MM:SSZ`, and
  fractional seconds are refused. A subclass of `Date` or `POSIXct`,
  such as data.table’s `IDate`, is spelled as its base class.
- Rows are sorted by the UTF-8 bytes of each row’s own canonical JSON.

``` r

a <- data.frame(segment = c("s2", "s1"), km = c(7.25, 12.3456789012))
b <- data.frame(km = c(12.3456789012 + 9.5e-11, 7.25), segment = c("s1", "s2"))
crt_table_fingerprint(a) == crt_table_fingerprint(b)
#> [1] FALSE
crt_table_fingerprint(a, c(km = 1e-9)) == crt_table_fingerprint(b, c(km = 1e-9))
#> [1] TRUE
```

It is not
[`crt_schema_fingerprint()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_fingerprint.md),
which hashes a table’s column names and types, never its values.

### Tolerances

A tolerance is an absolute power of ten from 1 to 1e-15. It says both
how a fingerprint rounds (`k` decimals for `10^-k`) and what the
comparison accepts (`|a - b| <= 10^-k`). A tolerance that is not a power
of ten has no rounding that matches it, and is refused.

## Writing a receipt

A package declares, as YAML beside its writer, what only it knows:

    # The receipt declaration for the worked case's output (crate#43): what only the
    # producing package knows. crt_receipt_keys() reads it.
    receipt_keys: 1
    output: link_evidence
    recipe:
      config_files: [settings.csv]
      settings: [species, watershed_group]
      inputs: [flow, fwa_stream_networks]
      seed: false
    result:
      tables:
        access_check:
          tolerance: {km: 1.0e-9}
        visits_link: {}
        visits_species: {}
        walks: {}
      summary:
        rows: {}
        km_total: {tolerance: 1.0e-6}

and hands the writer its values.
[`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md)
computes the ids, fingerprints and digests, fills the context, writes
`receipt.json` atomically, and returns the SHA-256 of the bytes it
wrote, which an item’s receipt asset carries (see “STAC items” below):

``` r

dir <- file.path(tempdir(), "evidence")
dir.create(dir, showWarnings = FALSE)
access <- read.csv(file.path(wc, "build_1", "access_check.csv"))
write.csv(access, file.path(dir, "access_check.csv"), row.names = FALSE)

digest <- crt_receipt_write(
  dir,
  output = list(name = "access_check", scope = "BULK"),
  recipe = list(
    code = list(link = list(commit = "a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0",
                            version = "0.31.2", dirty = FALSE)),
    config = list(settings = list(species = c("CO", "CH", "ST"))),
    inputs = list(fwa_stream_networks = list(version_id = "3HL4kqtJlcpXroDTDmJ.rmSpXd3dIbrHY"))
  ),
  result = list(
    tables = list(access_check = access),
    parts = c(access_check = "access_check.csv"),
    summary = list(rows = nrow(access), km_total = sum(access$km)),
    tolerance = list(tables = list(access_check = list(km = 1e-9)),
                     summary = list(km_total = 1e-6))
  ),
  publish = TRUE
)
crt_receipt_read(dir)$result$fingerprint
#> $access_check
#> $access_check$rows
#> [1] 4
#> 
#> $access_check$sha256
#> [1] "ac3a4b6d2811f6eb530a3d2a70a6cdfe226b652d33d2f20f9744560cb67c31d9"
```

Name each part by the table it holds. A file whose bytes differ between
builds is `equivalent` only when its table’s fingerprint agrees; a file
that names no table, such as a raster nobody fingerprinted, is
`different`.

``` r

crt_receipt_validate(file.path(dir, "receipt.json"))
```

## Comparing

[`crt_receipt_compare()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_compare.md)
reads the receipt register, one row per field, to decide what a
difference in each does: `refuse` makes the verdict `different`, `warn`
is reported without changing it, and `record` is listed only. Every
recipe field refuses, because `recipe_id` covers it; every context field
is recorded. Register v1.0.0 is published at
`https://newgraphenvironment.github.io/crate/receipt/register/v1.0.0/register.csv`
and installed with crate, and every comparison names the version it
read, with any field a package’s declaration overrode.

``` r

reg <- read.csv(system.file("extdata", "receipt", "register", "v1.0.0", "register.csv",
                            package = "crate", mustWork = TRUE))
table(reg$action)
#> 
#> record refuse   warn 
#>      9     31      3
head(reg[, c("field", "action")], 8)
#>                    field action
#> 1            output.name refuse
#> 2           output.scope refuse
#> 3 output.receipt_version   warn
#> 4          output.schema   warn
#> 5   output.migrated_from   warn
#> 6            recipe.code refuse
#> 7   recipe.code.*.commit refuse
#> 8  recipe.code.*.version refuse
```

**A comparison of receipts alone certifies less than one that re-reads
the result.** Two values within tolerance can still round apart at the
edge (0.0000000014 and 0.0000000016 under 1e-9 round to 0.000000001 and
0.000000002), and the receipts then disagree. Supply both builds’ tables
and the comparison checks each against its own receipt, compares their
cells, and reports which it did:

``` r

tables <- function(build) {
  list(access_check = read.csv(file.path(wc, build, "access_check.csv")))
}
crt_receipt_compare(file.path(wc, "build_1"), file.path(wc, "build_2"),
                    tables = list(a = tables("build_1"), b = tables("build_2")))$mode
#> [1] "bytes"
```

## Older records

[`crt_receipt_migrate()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_migrate.md)
reads a record written before its package moved to receipts through the
mapping table, so it stays readable while writers converge forward, each
when it is next touched. Mapping v1.1.0 is published at
`https://newgraphenvironment.github.io/crate/receipt/mapping/v1.1.0/mapping.csv`
and installed with crate. A migrated receipt claims no recipe identity,
and keeps what it cannot place in `context.legacy`:

``` r

old <- system.file("extdata", "receipt", "examples", "legacy", "link_manifest.json",
                   package = "crate")
m <- crt_receipt_migrate(old, "link manifest.json")
m$recipe
#> $code
#> $code$link
#> $code$link$version
#> [1] "0.31.2"
#> 
#> $code$link$commit
#> [1] "a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0"
#> 
#> $code$link$dirty
#> [1] FALSE
#> 
#> 
#> 
#> $recipe_id
#> NULL
names(m$context$legacy)
#> [1] "manifest_version" "datasets"         "configs"          "parts"           
#> [5] "files"
```

## STAC items

A STAC item carries a few of its receipt’s fields, so a STAC client or a
pgstac queryable can read a build’s identity without fetching the
receipt.
[`crt_receipt_stac()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_stac.md)
gives those fields, by the mapping table’s `STAC item` rows. A part’s
`sha256` becomes its asset’s `file:checksum` (a multihash, `1220` then
the digest) and its `bytes` the asset’s `file:size`. The repositories’
versions become `processing:software`, the time `processing:datetime`,
and the `recipe_id` `receipt:recipe_id`, whose field schema crate
publishes at
`https://newgraphenvironment.github.io/crate/stac/receipt/v1.0.0/schema.json`.

Pass each asset’s href relative to the item, which is the path a part is
keyed by. For the asset that links the receipt, give the digest
[`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md)
returned. A receipt is not one of its own parts, so nothing else can
compute that checksum, and the asset carries no `file:size`:

``` r

s <- crt_receipt_stac(dir, assets = c(access_check = "access_check.csv"),
                      receipt_asset = "receipt", receipt_sha256 = digest)
str(s, give.attr = FALSE)
#> List of 3
#>  $ stac_extensions: 'AsIs' chr [1:3] "https://stac-extensions.github.io/file/v2.1.0/schema.json" "https://stac-extensions.github.io/processing/v1.2.0/schema.json" "https://newgraphenvironment.github.io/crate/stac/receipt/v1.0.0/schema.json"
#>  $ properties     :List of 3
#>   ..$ receipt:recipe_id  : chr "6f2f62c41cccd8fee1a84e87cbf9486432cb942f00a965911ad4216bfaf93c02"
#>   ..$ processing:datetime: chr "2026-11-11T13:36:55Z"
#>   ..$ processing:software:List of 1
#>   .. ..$ link: chr "0.31.2"
#>  $ assets         :List of 2
#>   ..$ access_check:List of 2
#>   .. ..$ file:checksum: chr "122004994ff01cdee55d69fc410add51ad261ec4b33a751135fc224e97305823c3e2"
#>   .. ..$ file:size    : int 124
#>   ..$ receipt     :List of 1
#>   .. ..$ file:checksum: chr "12200f0ce1e4be40cc7cef7b447c0f75b0b815643f5d94dc13dd81d2931e4c9723c1"
```

Merge these into the item being built; its id, geometry, hrefs, types
and roles do not come from the receipt. A part that no asset names is
not mirrored, since an item may publish fewer files than the build made.
An asset whose href names no part is an error, never a guessed checksum.
A repository with no version is left out of `processing:software`. A
migrated receipt has no recipe identity, so its item leaves
`receipt:recipe_id` out rather than publish a null:

``` r

names(crt_receipt_stac(m)$properties)
#> [1] "processing:datetime" "processing:software"
```

## Test vectors

Every implementation runs the files in
`inst/extdata/receipt/vectors/v1.0.0/` and must produce each expected
value byte for byte: number spellings, canonical JSON, `recipe_id`s and
table fingerprints. These test the hashing, which the form defines, so
they are versioned with the form. Doubles are given as IEEE 754 bits, so
no decimal parser stands between a vector and its value.

``` r

vec <- system.file("extdata", "receipt", "vectors", "v1.0.0", package = "crate", mustWork = TRUE)
list.files(vec)
#> [1] "fingerprint.json" "jcs.json"         "numbers.json"     "README.md"       
#> [5] "recipe_id.json"
```

Receipt pairs with their verdicts test the register, so they sit with
it, in `inst/extdata/receipt/register/v1.0.0/compare.json`:

``` r

reg_dir <- system.file("extdata", "receipt", "register", "v1.0.0", package = "crate",
                       mustWork = TRUE)
list.files(reg_dir)
#> [1] "compare.json" "README.md"    "register.csv"
```

Receipts with the item fields each maps to, or a refusal, test the
mapping’s STAC rows, so they sit with the mapping, in
`inst/extdata/receipt/mapping/v1.1.0/stac.json`. A refused case gives a
code for what is refused, and a runner checks only that the case is
refused, since messages differ between implementations:

``` r

map_dir <- system.file("extdata", "receipt", "mapping", "v1.1.0", package = "crate",
                       mustWork = TRUE)
list.files(map_dir)
#> [1] "mapping.csv" "README.md"   "stac.json"
```
