# Task: A shared provenance receipt: a language-neutral contract, crate's R implementation, and a three-way comparison (#43)

The packages and catalogues that publish outputs each record provenance their own way. Some write a
`manifest.json` with a `provenance` block and per-part md5, some a `provenance.json` sidecar, some
log tables, some STAC properties and raster tags. Across them there are hundreds of distinct field
names for what an output was built from. No two records can be compared without a hand-written
mapping, and an R-only answer would leave the catalogues, whose items are mostly built and
registered in Python, outside it.

A rebuild asks two separate questions:

- **Was it made the same way?** This is the recipe: code commits, config, and the identities of the
  inputs.
- **Did it come out the same?** This is the result. The same recipe can give slightly different
  results on another machine or another day, through row order, float summation order, or a model
  fitted with random draws. "Equivalent" has to be an answer in its own right.

A worked case: the same build's evidence, built twice from the same code, gave three
byte-identical tables and a fourth differing in the 11th decimal place (max 9.5e-11 km), because
the database summed in another order. A receipt that fingerprints the tables that matter and
declares a rounding on the km sum calls that `equivalent`. Today that choice is one package's
habit, written nowhere.

## Context

Every package and catalogue records provenance in its own shape, under hundreds of field names.
soul#685's census found 272 names for "built from what" alone, so no two records can be compared
without a hand-written mapping. soul's `conventions/provenance.md` (renamed to "receipt" by
soul#746, merging now) hands the contract to crate: a language-neutral JSON Schema, an RFC 8785
`recipe_id`, a table fingerprint and test vectors. It also hands crate the one R implementation.
stacs#12 (open) is the Python side: it pins a crate tag and runs the same vectors. Worked case
(knowledge#145): a link build's evidence was rebuilt and gave three byte-identical tables and a
fourth that differed by up to 9.5e-11 km. That rebuild must read `equivalent`.

## Decided at the gate

Decided by the owner on 2026-11-05, in the plan-mode questions:
- **Hash: SHA-256 everywhere** (`recipe_id`, table fingerprint, `parts`), stored as lowercase hex.
  The receipt schema version pins the algorithm. It matches stacs' body digest and is built into
  Python's hashlib and Postgres's `sha256()`. `crt_schema_fingerprint()` stays XXH64: it is a
  separate contract over column names and types.
- **Table canonical form: the RFC 8785 JSON of `{"columns":[...],"rows":[[...],...]}`.**
  - Columns are sorted by name (C collation).
  - Every cell is a string or `null` (NA).
  - Doubles are rounded to the declared decimals and written with fixed decimals; `-0` becomes `0`.
  - Dates are ISO 8601; datetimes are UTC with a trailing `Z`; logicals are `true`/`false`; factors are their labels.
  - Rows are sorted by the bytes of their own JCS.
  - It reuses the `recipe_id` serializer, so there are no CSV quoting rules.
- **Scope: every box in #43, one PR**, one atomic commit per phase.
- Carried from the issue, not reopened: the name `receipt`; toolchain is context; a seed is recipe;
  resolved run settings are hashed with config; crate owns the byte-for-byte parts and each package
  declares what only it knows. `crt_receipt_lineage()` and `crt_receipt_stac()` stay out of scope.

## What exploration found

- `R/crt_schema_fingerprint.R` sets the house pattern for a cross-language hash: it hashes bytes, never R's serialization, marks text UTF-8, sorts with radix (C collation) and upper-cases with ASCII-only `chartr`. The new code follows the same rules.
- #23 sets the pattern for a published schema (`planning/archive/2026-10-issue-23-stac-field-schemas/`):
  - The files live in `pkgdown/assets/stac/<prefix>/v<X.Y.Z>/schema.json`; `$id` is the URL; the schemas are draft-07.
  - `tests/testthat/test-stac_schemas.R` validates them with ajv and finds every prefix in the tree on its own.
  - `.github/workflows/pkgdown.yaml` (step "Check the STAC schemas against what is published") freezes each version against gh-pages. It covers `stac/` only today.
  - So the `receipt:` STAC prefix fits the existing pattern; the receipt schema itself needs the guard widened.
- `pkgdown/assets/` is not installed, so `crt_receipt_validate()` needs the schema in `inst/` as well.
- `digest` (0.6.39, has sha256) is already in Imports. `jsonlite` and `jsonvalidate` are in Suggests. There is no `vignettes/` directory and no `VignetteBuilder` field.
- Python `rfc8785` 0.1.4 is in `~/Projects/repo/stacs/.venv`, which allows a local cross-check against an independent JCS implementation.
- The field-name inventory to map from is soul#685's census CSVs (`soul/planning/archive/2026-11-issue-685-provenance-census/census-*.csv`). soul is private, so only field names and public repos' names go into crate (`gh api repos/<o>/<r> --jq .private` per repo).
- `check_pkg_stale.sh` lists 12 stale first-party installs. crate imports none of them, so nothing to upgrade.

## Phase 1: Research file and design decisions
- [x] `research/provenance_receipt.md`, revised in place through the branch, covering:
  - the four blocks
  - the gate decisions above, each with a line of why
  - the worked case carried through two receipts, a comparison and its verdict
- [x] `.Rbuildignore`: `^research$`
- [x] Decide and record in the research file:
  - **Tolerance**: declared as an absolute `10^-k` per column or summary value. The fingerprint rounds to `k` decimals; the comparison tests `|a - b| <= tol`.
  - **Rounding boundary**: two values within tolerance can round apart. A receipts-only comparison then says `different` (result: fingerprint of table X) and says it compared receipts only. A bytes comparison (both tables supplied) re-reads the cells and can return `equivalent`.
  - **The register against `recipe_id`**: `recipe_id` covers every recipe field, so a recipe-field row must be `refuse`, and a test asserts it. `warn` rows are reported without changing the verdict; `record` rows (context) are listed only.
  - **Inputs**: an input either has a `recipe_id`, or a `version_id`/`sha256` for an input with no receipt, or `"none"` with `declared: true`. `recipe_id` excludes itself.
  - **`host`**: `crt_receipt_write(publish = TRUE)` leaves it out.
  - **`parts` paths**: relative to the receipt's directory.
  - **Migrated receipts**: what goes in `recipe_id` when old records lack recipe fields (proposal: `null`, plus `migrated_from` and the comparison reporting `recipe: unknown`).

## Phase 2: Receipt schema v1.0.0
- [x] `inst/extdata/receipt/schema/v1.0.0/schema.json`:
  - draft-07; `$id` `https://newgraphenvironment.github.io/crate/receipt/v1.0.0/schema.json`
  - blocks `output`, `recipe`, `result`, `context`; `output.receipt_version` set to the schema version
- [x] A published copy at `pkgdown/assets/receipt/v1.0.0/schema.json`, with a test that it is byte-identical to the installed copy
- [x] `pkgdown.yaml`: widen the build check and the gh-pages immutability guard to `receipt/v*/schema.json`. Prove the guard fires the way #23 did: extract the step and run it in a scratch clone against a fake published ref.
- [x] `tests/testthat/test-crt_receipt_schema.R`: compiles under ajv; example receipts pass; negatives fail (block missing, `recipe_id` not 64 hex, unknown block key)
- [x] DESCRIPTION: `jsonlite` to Imports. `jsonvalidate` stays in Suggests; `crt_receipt_validate()` aborts with an install hint when it is missing.

## Phase 3: Canonical JSON and `recipe_id`
- [x] `R/crt_receipt_jcs.R` (internal), an RFC 8785 serializer:
  - keys sorted by UTF-16 code units
  - the JCS string escaping rules
  - numbers as ECMAScript shortest round-trip, with the 1e21 and 1e-7 switches to exponent form
  - aborts on NaN and Inf
- [x] Internal `recipe_id`: SHA-256 hex of the JCS bytes of the `recipe` block without `recipe_id`
- [x] Tests: the RFC 8785 Appendix B number samples, key-order samples (including a supplementary-plane key), escaping

## Phase 4: Table fingerprint
- [x] `R/crt_table_fingerprint.R`: export `crt_table_fingerprint(x, tolerance = NULL)`, using the canonical form decided at the gate
  - supported column types: character, integer, double, logical, Date, POSIXct, factor; any other type aborts
  - a double with no declared tolerance uses shortest round-trip, i.e. exact
  - roxygen keeps it distinct from `crt_schema_fingerprint()`
- [x] Tests:
  - column order and row order do not move the value
  - a 9.5e-11 difference under a 1e-9 tolerance gives the same value; the same difference with no tolerance gives a different one
  - NA and `""` differ; a locale change (C vs UTF-8) leaves the value unchanged

## Phase 5: Test vectors
- [x] `inst/extdata/receipt/vectors/v1.0.0/` holds `jcs/`, `recipe_id/`, `fingerprint/` and `compare/`, each as JSON input plus expected output. *(Landed as one file per kind: `numbers.json`, `jcs.json`, `recipe_id.json`, `fingerprint.json`, with a README; `compare.json` lands with Phase 7, which needs `crt_receipt_compare()`.)* The fingerprint tables are stored as JSON columns, so Python reads them without R.
- [x] `data-raw/receipt_vectors.R` writes them
- [x] `tests/testthat/test-crt_receipt_vectors.R` runs every file, so a vector with no test fails
- [x] A local cross-check with Python `rfc8785` (the stacs venv) over the jcs and recipe_id vectors, recorded in findings.md. It does not run in CI, which has no Python.

## Phase 6: The R family
- [x] `crt_receipt_write(path, output, recipe, result, context = NULL, publish = FALSE)`:
  - takes the values a package supplies and computes `recipe_id`, the fingerprints and the `parts` sha256 and bytes
  - fills `context` (UTC time, R version, loaded GDAL/terra/arrow versions, `renv.lock` hash when present)
  - writes `receipt.json` as pretty JSON; the ids are computed over JCS, not the pretty form
- [x] `crt_receipt_read()`, and `crt_receipt_validate()` against the installed schema
- [x] `crt_receipt_keys(path)` reads a package's YAML declaration: recipe inputs and settings, fingerprinted tables, tolerances, register overrides. It is validated with chk/cli, like `crt_schema_read()`.
- [x] Tests: written receipts validate against the schema; a round trip keeps the ids; `publish = TRUE` leaves out `host`; context never moves `recipe_id`

## Phase 7: Comparison and register
- [x] `inst/extdata/receipt/register.csv`: one row per schema leaf field (`field`, `action` = refuse/warn/record, `why`)
- [x] `crt_receipt_compare(a, b, tables = NULL)` returns:
  - `verdict`: identical/equivalent/different
  - `mode`: receipts/bytes
  - a `differences` tibble (side recipe/result/context/output, field, action, detail, e.g. "result: column `km`, 3 rows past 1e-9")
  - It reads the register, overlaid by the package's declaration.
- [x] Register test: build a receipt pair per field that differs only there, and assert the register's action. A schema field with no register row fails the test, and so does a recipe field that is not `refuse`.
- [x] Compare vectors (from Phase 5) pass, including the worked case → `equivalent`

## Phase 8: Mapping table and migrate
- [x] `inst/extdata/receipt/mapping.csv` (`source_field`, `source_format`, `receipt_key`, `stac_key`), seeded from the census: field names, with repo names only where the repo is public *(scope as landed: every field of the two formats migrate reads, STAC keys, and the names most repos share; see the research file)*
- [x] `crt_receipt_migrate(path, format)` reads an old `manifest.json`/`provenance.json` through the mapping into a receipt, per the Phase 1 decision on migrated `recipe_id`
- [x] Tests on fixtures shaped like floodplains' `provenance.json` and a link-style `manifest.json`. An unmapped field is reported, never dropped silently.

## Phase 9: `receipt:` STAC field schema
- [ ] `pkgdown/assets/stac/receipt/v1.0.0/schema.json`, with README, CHANGELOG and `examples/item.json`. `receipt:recipe_id` is the first field (64 hex); no field is required.
- [ ] `pkgdown/assets/stac/README.md`: add the index row
- [ ] `test-stac_schemas.R` finds the new prefix on its own; add negatives (bad `receipt:recipe_id`, unknown `receipt:bogus`)

## Phase 10: Vignette and docs
- [ ] `vignettes/receipt.Rmd` from the research file, with runnable examples on a synthetic copy of the worked case (four tables, one off by 9.5e-11 km), not knowledge's data. DESCRIPTION: `VignetteBuilder: knitr`.
- [ ] `_pkgdown.yml`: reference sections and an article; README "How it works" line; NEWS entry (the version bump is left to `/gh-pr-merge`)
- [ ] CLAUDE.md Status and naming: the `crt_receipt_*` family and `crt_table_fingerprint`; reserve `crt_receipt_lineage` and `crt_receipt_stac`
- [ ] Tick the #43 body's boxes as they land

## Owed at the end (reported, done after merge)

- [ ] After the deploy, check that the receipt and `receipt:` STAC schema URLs serve (curl returns 200 and the `$id` matches)
- [ ] Tell stacs#12 the crate tag carrying vectors v1.0.0, so it can pin it
- [ ] soul `conventions/provenance.md` rule 4: point at the published vignette and drop the detail it now holds (the rule says to once the vignette exists)

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

How each change is proved:
- `devtools::test()` green, and `devtools::check()` with 0 errors, 0 warnings and 0 notes beyond the existing baseline
- JCS and `recipe_id` agree byte for byte with Python `rfc8785` on every vector (script output in findings.md)
- Restore-the-bug runs:
  - drop a register row, and the register test fails
  - mutate one vector, and the vectors test fails
  - remove the tolerance on `km`, and the worked case reads `different`
  - edit a frozen schema, and the guard step fails in the scratch clone
- A local `pkgdown::build_site()` emits `docs/receipt/v1.0.0/schema.json` and `docs/stac/receipt/v1.0.0/schema.json`
- Every receipt the tests write validates under ajv
