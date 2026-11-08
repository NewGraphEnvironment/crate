# crate

> Canonical schemas for data that changes shape, and provenance receipts
> for what we build from it.

When external data we depend on changes shape — columns renamed, types
swapped, layouts flipped — code that reads those files breaks. crate is
the one place that knows about all the shape variations.

Call `crt_ingest("source", "file_name", path)` from anywhere. Same call,
same output, regardless of which version of the upstream file landed.
When upstream changes shape again, fix it once in crate; everywhere
downstream keeps working.

Some data crate should not read — a spatial format, a database, an API.
For that, `crt_schema_conform(df, "source", "file_name")` takes a data
frame you already have and holds it to the same declared shape. crate
says what the columns mean either way; reading the bytes is somebody
else’s job.

crate’s other job is the outputs. A provenance receipt is one
`receipt.json` per output (a table, raster, model or STAC item) saying
what it is, how it was made, what came out, and where and when, so a
rebuild can be compared with its reference copy and judged identical,
equivalent within a declared tolerance, or different, naming what
differed. See [Provenance receipts](#provenance-receipts) below and
[`vignette("receipt")`](https://newgraphenvironment.github.io/crate/articles/receipt.md).

## Installation

``` r

pak::pak("NewGraphEnvironment/crate")
```

## Reading a file that changed shape

[bcfishpass](https://github.com/smnorris/bcfishpass) changed
`user_habitat_classification.csv` between commit `9cc30fc` (long format
with text `habitat_ind` indicators) and commit `40c4a0a` (wide format
with integer `spawning` + `rearing` columns) on 2026-04-26. The reshape
included both a structural change (one column → two) and a type change
(text → integer). crate handles both shapes:

``` r

library(crate)

# What does crate know about?
crt_files()
#> # A tibble: 14 × 6
#>    source file_name                   kind        handler_fn                schema_yaml
#>    <chr>  <chr>                       <chr>       <chr>                     <chr>
#>  1 bcfp   user_habitat_classification file        crt_handler_bcfp_user_ha… schemas/bcfp/user_habitat_classification.yaml
#>  2 nge    track_sessions              schema_only NA                        schemas/nge/track_sessions.yaml
#>  3 nge    track_vertices              schema_only NA                        schemas/nge/track_vertices.yaml
#>  4 nge    track_annotations           schema_only NA                        schemas/nge/track_annotations.yaml
#>  5 nge    form_capture                schema_only NA                        schemas/nge/form_capture.yaml
#>  6 nge    discharge/fwa/v1/segment_m… schema_only NA                        schemas/nge/discharge/fwa/v1/segment_monthly.yaml
#>  7 nge    discharge/fwa/v1/segment_d… schema_only NA                        schemas/nge/discharge/fwa/v1/segment_daily.yaml
#>  8 nge    discharge/fwa/v1/watershed… schema_only NA                        schemas/nge/discharge/fwa/v1/watershed_monthly.yaml
#>  9 nge    form_pscis                  schema_only NA                        schemas/nge/form_pscis.yaml
#> 10 nge    form_fiss_site              schema_only NA                        schemas/nge/form_fiss_site.yaml
#> 11 nge    form_monitoring_fish_passa… schema_only NA                        schemas/nge/form_monitoring_fish_passage.yaml
#> 12 nge    form_monitoring_general     schema_only NA                        schemas/nge/form_monitoring_general.yaml
#> 13 nge    form_monitoring             schema_only NA                        schemas/nge/form_monitoring.yaml
#> 14 nge    fish_data                   file        crt_handler_nge_fish_data schemas/nge/fish_data.yaml

# Ingest a bundled wide-format example fixture (today's upstream shape)
wide_path <- system.file(
  "extdata/examples/bcfp/user_habitat_classification_wide.csv",
  package = "crate"
)
wide <- crt_ingest("bcfp", "user_habitat_classification", wide_path)

# Ingest the bundled long-format historical fixture — same call,
# crate pivots it to canonical wide automatically
long_path <- system.file(
  "extdata/examples/bcfp/user_habitat_classification_long.csv",
  package = "crate"
)
long <- crt_ingest("bcfp", "user_habitat_classification", long_path)

# Both calls return the same canonical column set
identical(names(wide), names(long))
#> [1] TRUE
```

When the next upstream reshape happens, the fix is one PR in crate —
register the new shape as an `upstream_variant` in the schema YAML and
add a small pivot function. Code calling
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
doesn’t change.

See the [function
reference](https://newgraphenvironment.github.io/crate/reference/) and
[browse the
schemas](https://github.com/NewGraphEnvironment/crate/tree/main/inst/extdata/schemas).

## Provenance receipts

A rebuild asks two questions. **Was it made the same way?** That is the
recipe: code, config, the inputs’ identities, a seed. **Did it come out
the same?** That is the result. The same recipe can give slightly
different results on another machine or another day, through row order
or float summation order, so comparing two receipts answers one of three
verdicts: `identical`; `equivalent`, the same recipe with every
differing value within its declared tolerance; or `different`, another
recipe or a value past its tolerance.

A package declares what only it knows (which inputs and settings are
recipe, which tables are fingerprinted, and their tolerances) and hands
[`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md)
its values. crate computes the ids, fingerprints and digests, fills the
context, and writes `receipt.json` beside the output:

``` r

wc <- system.file("extdata", "receipt", "examples", "worked_case", package = "crate")
access <- read.csv(file.path(wc, "build_1", "access_check.csv"))

dir <- file.path(tempdir(), "evidence")
dir.create(dir)
write.csv(access, file.path(dir, "access_check.csv"), row.names = FALSE)

w <- crt_receipt_write(
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
w$recipe$recipe_id
#> [1] "6f2f62c41cccd8fee1a84e87cbf9486432cb942f00a965911ad4216bfaf93c02"
```

One link build’s evidence was built twice from the same code. The
`access_check` table had the same rows and counts both times but
differed in the 11th decimal place of `km`, because the database summed
in another order. crate ships a synthetic copy of the two builds, each
with its receipt:

``` r

crt_receipt_compare(file.path(wc, "build_1"), file.path(wc, "build_2"))
#> equivalent (receipts only)
#>   within result.parts[access_check.csv].bytes: 124 vs 128; table access_check agrees
#>   within result.parts[access_check.csv].sha256: "04994ff01cdee55d69fc410add51ad261ec4b33a751135fc224e97305823c3e2" vs "6801fb7bb092626441fd804d5ffbf8c4c05213ff18fa7c7ca524a9c2aa32f5e4"; table access_check agrees
#>   within result.summary[km_total]: 47.3767792597 vs 47.376779259805; within 1e-06
#>   record context.run: {"link_run_id":"20261104T181900Z-bulk"} vs {"link_run_id":"20261104T214400Z-bulk"}
#>   record context.time: "2026-11-04T18:22:05Z" vs "2026-11-04T21:47:31Z"
```

`access_check.csv`’s bytes differ, but the receipt says that file holds
the `access_check` table, whose fingerprint agrees under the `1e-9`
tolerance on `km`; `km_total` differs within its `1e-6`; the run
identifiers and times are context, recorded and never part of an
identity.

crate holds the contract in a form any language can implement: the
[receipt
schema](https://newgraphenvironment.github.io/crate/receipt/v1.0.0/schema.json)
(also installed with crate), RFC 8785 canonical JSON, the table
fingerprint, and test vectors in
[`inst/extdata/receipt/vectors/`](https://github.com/NewGraphEnvironment/crate/blob/main/inst/extdata/receipt/vectors/v1.0.0/README.md).
The R implementation is
[`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md),
[`crt_receipt_read()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_read.md),
[`crt_receipt_validate()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_validate.md),
[`crt_receipt_compare()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_compare.md),
[`crt_receipt_keys()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_keys.md),
[`crt_receipt_migrate()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_migrate.md)
and
[`crt_table_fingerprint()`](https://newgraphenvironment.github.io/crate/reference/crt_table_fingerprint.md).
A Python implementation for STAC catalogues, passing the same vectors,
is planned in stacs
([stacs#12](https://github.com/NewGraphEnvironment/stacs/issues/12)).
[`vignette("receipt")`](https://newgraphenvironment.github.io/crate/articles/receipt.md)
is the contract’s reference.

## How reading works

When you call `crt_ingest("bcfp", "user_habitat_classification", path)`,
five pieces wire together at runtime:

1.  **Registry**
    ([`inst/extdata/crate_registry.csv`](https://github.com/NewGraphEnvironment/crate/blob/main/inst/extdata/crate_registry.csv))
    — a CSV mapping each `(source, file_name)` pair to a handler
    function name and a schema YAML path. crate looks up “what do I know
    about this file?” here. Loaded by `crt_registry_load()`.

2.  **Schema YAML**
    ([`inst/extdata/schemas/bcfp/user_habitat_classification.yaml`](https://github.com/NewGraphEnvironment/crate/blob/main/inst/extdata/schemas/bcfp/user_habitat_classification.yaml))
    — declares the canonical column shape (names, types, required flags)
    AND each known upstream variant (a column-name set + a
    normalize-function id). Loaded by
    [`crt_schema_read()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_read.md).

3.  **Handler**
    ([`R/crt_handler_bcfp_user_habitat_classification.R`](https://github.com/NewGraphEnvironment/crate/blob/main/R/crt_handler_bcfp_user_habitat_classification.R))
    — one function per `(source, file_name)`. crate matches the actual
    file columns against each variant’s declared columns (first
    set-equal match wins), then dispatches the matched `variant_id` into
    the handler:

    - `2026-04-26-wide` → identity passthrough (already canonical)
    - `pre-2026-04-26-long` → pivot long rows to wide canonical, mapping
      `habitat_ind` text values to integer indicators

4.  **Validation**
    ([`crt_schema_validate()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_validate.md))
    — after the handler returns, crate checks every column declared
    `required: true` in the schema is present. Fails loud listing all
    missing required columns.

5.  **Type enforcement**
    ([`crt_schema_apply()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_apply.md))
    — finally, crate coerces every named column to the type declared in
    the schema (`integer`, `double`, `string`, `logical`, `datetime`).
    Schema YAML is the single source of truth for types; handlers don’t
    encode type knowledge. Without this, readr’s defaults leak through
    (integer cols become double, declared strings become Date).

Steps 4 and 5 are
[`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md),
which
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
calls rather than reimplements — so a file and a frame you supply
yourself get identical treatment.

A `datetime` column is **an instant**, and crate never moves it. A
`POSIXct` has its timezone attribute *stamped* to UTC rather than
converted: several readers return correct UTC instants carrying no
timezone label, so R renders them in the session’s zone and they read as
a second clock in a second timezone. Converting to “fix” that rendering
injects a real whole-hour error into every join downstream. Stamping
fixes the label, which was the only thing wrong.

The handler made the type change transparent in our example. The wide
canonical declares `spawning` and `rearing` as integer columns; the long
upstream had `habitat_ind` as text (`"t"`/`"f"`). The pivot does the
text→integer conversion in the same step as the long→wide reshape —
callers never see either intermediate form. Type enforcement (step 5)
catches any leaks at the boundary regardless of handler.

### Caveat: variant matching is column-names only

[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
matches input to upstream variants by exact column-name set equality. It
does not validate column types at the variant-match step. If upstream
later ships the same column names with different types, the handler
would receive misshapen data;
[`crt_schema_apply()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_apply.md)
then coerces the output (some coercions silently produce NAs, e.g.,
`as.integer("yes")` → NA). Type-aware variant matching (declaring
`cols: [{name, type}]` and validating both at dispatch) is a planned
v0.1.x improvement.

Output types and required-cols ARE enforced via
[`crt_schema_apply()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_apply.md)
and
[`crt_schema_validate()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_validate.md)
respectively (steps 4–5 above).

### Adding a new (source, file_name) pair

1.  Author the schema YAML at
    `inst/extdata/schemas/<source>/<file_name>.yaml`
2.  Write a normalize handler at `R/crt_handler_<source>_<file_name>.R`
3.  Add a row to
    [`inst/extdata/crate_registry.csv`](https://github.com/NewGraphEnvironment/crate/blob/main/inst/extdata/crate_registry.csv)
4.  Write a decision-log entry at
    `decisions/<source>/<YYYYMMDD>_<topic>.md` if the canonical-shape
    choice isn’t self-evident
5.  Add tests + small synthetic fixtures at
    `inst/extdata/examples/<source>/<file_name>_<variant>.csv`

See
[`inst/extdata/schemas/README.md`](https://github.com/NewGraphEnvironment/crate/blob/main/inst/extdata/schemas/README.md)
and
[`decisions/README.md`](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/README.md)
for the conventions on each.

## Naming convention

Every function in crate’s namespace starts with `crt_`,
family-namespaced:

- `crt_<verb>` — public singletons (`crt_ingest`, `crt_files`)
- `crt_schema_conform`, `crt_schema_cols`, `crt_schema_grade`,
  `crt_schema_variant`, `crt_schema_fingerprint` — public, and in the
  `crt_schema_*` family because that is what they belong to
- `crt_receipt_write`, `crt_receipt_read`, `crt_receipt_validate`,
  `crt_receipt_compare`, `crt_receipt_keys`, `crt_receipt_migrate` —
  public, the provenance receipt family; `crt_table_fingerprint` beside
  it, named apart from `crt_schema_fingerprint`, which hashes column
  names and types rather than values
- `crt_handler_<source>_<file_name>` — per-(source, file) dispatchers
- `crt_<family>_<verb>` — internal helper families (`crt_registry_*`,
  `crt_schema_*`)

Reserved future families (slots in the `crt_schema_*` family for the
schema-as-contract roadmap): `crt_schema_version`, `crt_schema_migrate`,
plus a future `cols[].predicate` extension to `crt_schema_validate`. A
schema already declares `cols[].values` and `cols[].range`, which
[`crt_schema_cols()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_cols.md)
returns for a QC rule to flag against; conforming does not enforce them.

## What crate handles today

Registered entries come in two kinds. `file` entries crate reads and
normalizes; `schema_only` entries declare a canonical shape for data
crate does not read, which you conform yourself with
[`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md).

**`file`**

- `bcfp` (files from
  [smnorris/bcfishpass](https://github.com/smnorris/bcfishpass))
  - `user_habitat_classification` — handles both pre-2026-04-26 long and
    current 2026-04-26 wide upstream variants
- `nge` — fish sampling
  - `fish_data` — one row per fish caught or observed; reads the 2023
    individual fish files and the 2024+ field sheet to the same columns,
    with 2023 PIT tags read out of `comments`, so seasons stack and a
    tagged fish can be followed between them

**`schema_only`**

- `nge` — GPS tracks
  - `track_sessions` — one row per tracking session, carrying the
    evidence that its two clocks agree, and what the crew said about the
    session when they walked it (`track_name`, `track_type`,
    `track_description`, `named_by` — optional, because not every
    capture source has them)
  - `track_vertices` — one row per recorded position; non-spatial, so
    the geometry is reconstructable without a spatial dependency in the
    read path
  - `track_annotations` — overrides for the crew-supplied columns,
    deliberately a separate table. Captured tables are immutable and a
    harvest only ever writes those, so a correction lives beside them; a
    non-key column here sharing a captured column’s name overrides it
    where non-`NA`. Keyed with a timestamp fingerprint so a reissued
    identifier fails loudly instead of silently renaming somebody else’s
    track. See the decision entries on [the two-table
    shape](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20260824_track_canonical_two_tables.md)
    and [captured naming and
    overrides](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20260902_track_naming_captured_and_overridden.md).
- `nge` — field forms
  - `form_capture` — the envelope every captured field-form record
    carries (`project`, `form`, `record_id`, `source_version`,
    `schema_version`, `captured_at`), saying where a record came from
    and in what shape, and nothing about what any observation means. See
    the [decision
    entry](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20260901_form_capture_envelope.md).

More land as integration work surfaces. Each addition = a YAML in
`inst/extdata/schemas/` + a registry row, plus a handler when crate does
the reading. See
[`inst/extdata/schemas/README.md`](https://github.com/NewGraphEnvironment/crate/blob/main/inst/extdata/schemas/README.md)
for the format.

## STAC field schemas

crate’s pkgdown site also publishes JSON Schemas for custom fields in
NGE’s STAC catalogues, `lidarbc`, `las` and `receipt`, at
`https://newgraphenvironment.github.io/crate/stac/<prefix>/v<X.Y.Z>/schema.json`
for items to list in `stac_extensions`. `receipt:` mirrors a receipt’s
`recipe_id` into an item; catalogues adopt it with receipts
([stacs#12](https://github.com/NewGraphEnvironment/stacs/issues/12)).
They are not R schemas and not part of the package: they live in
[`pkgdown/assets/stac/`](https://github.com/NewGraphEnvironment/crate/blob/main/pkgdown/assets/stac/README.md),
and a released version is never edited. See the [decision
entry](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20261010_stac_field_schemas.md).

## Sibling public packages

[fresh](https://github.com/NewGraphEnvironment/fresh),
[link](https://github.com/NewGraphEnvironment/link),
[flooded](https://github.com/NewGraphEnvironment/flooded),
[gq](https://github.com/NewGraphEnvironment/gq),
[fpr](https://github.com/NewGraphEnvironment/fpr),
[ngr](https://github.com/NewGraphEnvironment/ngr).
