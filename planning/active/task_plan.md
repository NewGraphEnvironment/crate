# Task: register.csv and mapping.csv are unversioned, and every verdict is a function of their rows (#58)

The receipt contract is versioned in two of its four parts. At v0.14.1:

```
inst/extdata/receipt/schema/v1.0.0/schema.json      versioned
inst/extdata/receipt/vectors/v1.0.0/*.json          versioned
inst/extdata/receipt/register.csv                   not versioned
inst/extdata/receipt/mapping.csv                    not versioned
```

`register.csv` is not documentation of the comparison — it **is** the comparison's input (`crt_receipt_compare()` reads it through `system.file()`, and `receipt_register()` is the only place the per-field actions come from). So a verdict is a function of those 43 rows, and editing one row changes a published answer. Nothing in the comparison output, and nothing in a receipt, says which register was read.

`mapping.csv` has the same shape: `crt_receipt_migrate()` reads it, and a migrated receipt's fields are whatever the mapping said on the day it ran.

Two consequences already visible:

- **The STAC extensions crate publishes each carry a `CHANGELOG.md` and a versioned path** (`pkgdown/assets/stac/receipt/`, `lidarbc/`, `las/`). The register, which has more downstream reach, carries neither.
- **A non-R consumer cannot pin them.** `stacs` vendors both files, and because there is no versioned path it has to pin a **git tag** and record each file's blob sha (`src/stacs/data/receipt/SOURCE`, re-checked against crate in CI). That works, but it pins a commit of the whole package rather than a version of the contract — the thing the schema URL already gets right.

## Context

The receipt contract has four parts, and two of them are frozen with a version: the form
(`schema/v1.0.0/schema.json`) and the answer key (`vectors/v1.0.0/`). The rulebook
(`register.csv`, which decides every verdict) and the translation table (`mapping.csv`, which
decides every migrated receipt) are not versioned. Edit one register row and a published
comparison changes answer, with nothing recording why. stacs (Python) can only pin them as
"crate at tag v0.12.0".

## Decided at the gate (discussed with the owner, 2026-11-09)

- **A receipt's `receipt_version` means the form only.** A register or mapping change never
  moves it. Reasons: it answers what a receipt *is*; two receipts with the same shape must not
  `warn` at each other because the rulebook moved; a reference copy's number must never go stale.
- **The register and the mapping each get their own version**, in their own directory, and
  published at their own URL. Each register version states the form version it covers (a form
  change always brings a register change; a register change alone leaves the form alone).
- **The register version goes on the verdict**, not on the receipt: the comparison object and
  `print()` name it, together with any fields the package's declaration overrode.
- **`compare.json` moves under the register's number**, because it tests the rulebook. The
  other four vector files test the hashing, which the form defines, and stay in `vectors/v1.0.0/`.
- **Out of 58, into a new issue:** reading older form versions in `crt_receipt_read()`, and
  recording the mapping version on a migrated receipt (`output.migrated_from` → `{format,
  mapping_version}`). Both make up the first form change (v1.1.0), and they go together: done
  before the reader can read v1.0.0, the bump would make every receipt knowledge has already
  published (`knowledge/R/publish.R`, `data-raw/database_receipts.R`) unreadable. Nobody
  calls `crt_receipt_migrate()` in code yet, so waiting loses no migrated receipt.

## Layout after

```
inst/extdata/receipt/
  schema/v1.0.0/schema.json                 unchanged
  vectors/v1.0.0/{numbers,jcs,recipe_id,fingerprint}.json, README.md   (compare.json leaves)
  register/v1.0.0/register.csv              moved from receipt/register.csv
  register/v1.0.0/compare.json              moved from vectors/v1.0.0/, bytes unchanged
  register/v1.0.0/README.md                 compare.json's format and the form version covered
  mapping/v1.0.0/mapping.csv                moved from receipt/mapping.csv

pkgdown/assets/receipt/                     (site: newgraphenvironment.github.io/crate/receipt/)
  v1.0.0/schema.json                        unchanged, frozen
  register/v1.0.0/register.csv              new, byte-identical to inst
  mapping/v1.0.0/mapping.csv                new, byte-identical to inst
  CHANGELOG.md                              new: versioning rules + v1.0.0 entries for all three
```

Current versions as one internal constant beside `receipt_version()` in
`R/crt_receipt_write.R`, e.g. `receipt_register_version()` / `receipt_mapping_version()`, read by
`receipt_register()` (`R/crt_receipt_compare.R:188`) and `receipt_mapping()`
(`R/crt_receipt_migrate.R:141`). Old version directories stay installed (mirrors the published
set; the existing schema test already requires installed == published).

## Phase 1: Tests first (fail until Phase 2/3)

- [x] `test-crt_receipt_compare.R`: the comparison carries `register` (the version) and
  `overrides` (fields the declaration changed, empty when none); `print()` names both
- [x] Register test reads the versioned path and checks its rows against the fields of the form
  version that register version covers (generalise `schema_fields()` from its hard-coded v1.0.0)
- [x] `test-crt_receipt_migrate.R` mapping test reads the versioned path
- [x] `test-crt_receipt_vectors.R` reads `compare.json` from `register/v<current>/`
- [x] Published-copy test (`test-crt_receipt_schema.R` pattern): `pkgdown/assets/receipt/{register,mapping}/v*/` set-equal and byte-identical to `inst/`
- [x] CHANGELOG test: every published version directory (form, register, mapping) has an entry

## Phase 2: Move and read

- [x] `git mv` register.csv, mapping.csv, compare.json into their version directories
- [x] Version constants; `receipt_register()` and `receipt_mapping()` read the versioned paths
- [x] `crt_receipt_compare()` returns `register` and `overrides`; `print()` header becomes e.g.
  `different (receipts only; register v1.0.0)` / `...; register v1.0.0, 2 fields overridden by the package's declaration)`
- [x] `data-raw/receipt_vectors.R` writes `compare.json` to `register/v1.0.0/`; re-run it and
  `cmp` the output with the moved file (must be byte-identical); `receipt_vectors_crosscheck.py`
  path updated and re-run (not needed: the crosscheck never reads compare.json)

## Phase 3: Publish and freeze

- [x] Copies under `pkgdown/assets/receipt/{register,mapping}/v1.0.0/`
- [x] `pkgdown/assets/receipt/CHANGELOG.md`: the rules (any row change is a new version; a
  register row's `action` changing changes published verdicts; a released version is never
  edited) and v1.0.0 entries, naming the form version register v1.0.0 covers
- [x] `.github/workflows/pkgdown.yaml` freeze gate: extend the globs and the `published` regex
  to `receipt/{register,mapping}/v*/*.csv`; prove it against both answers locally with
  `SCHEMAS_PUBLISHED_REF` (an edited copy fails, an untouched one passes)

## Phase 4: Docs

- [x] roxygen in `crt_receipt_compare.R` (`@return` gains `register`, `overrides`; path) and `crt_receipt_migrate.R`
- [x] `vignettes/receipt.Rmd`: register/mapping paths, the published URLs, the three version
  numbers in one short paragraph, and where `compare.json` lives
- [x] `vectors/v1.0.0/README.md` (drop the compare row, point to `register/v1.0.0/`); new `register/v1.0.0/README.md` (landed in Phase 2: the vector test's file set needs it)
- [x] `research/provenance_receipt.md`: the versioning decision; `CLAUDE.md` Status line
- [x] `devtools::document()`, `pkgdown::check_pkgdown()`

## Phase 5: Cross-repo

- [ ] File the new crate issue: form v1.1.0 — `crt_receipt_read()` reads v1.0.0, and a migrated
  receipt records its mapping version; link it from 58
- [ ] File a stacs issue: register/mapping/compare.json moved; pin them by published version URL
  instead of tag + blob sha (stacs's tag pin keeps working until it re-vendors)

## Review fixes (Plan review, planning/active/review-plan.md)

- [x] Published-copy test calls internals as `crate:::` (the pkgdown step runs it with crate unattached; reproduced)
- [x] `overrides` carries each field's declared action, named by field
- [x] Version constants instead of a literal v1.0.0 in data-raw and the tests
- [x] Changelog test: the current register covers the current form
- [x] CHANGELOG rule: a code change that moves an expected verdict or a transform is a new version
- [x] R-CMD-check expected skips: nine
- [x] README pasted `print()` output and contract list; stale "planned" stacs claims in README, vignette, CLAUDE.md

## Owed at the end (reported, done after merge)

- [ ] Confirm `receipt/register/v1.0.0/register.csv` and `receipt/mapping/v1.0.0/mapping.csv`
  are served and byte-identical once Pages deploys (a gh-pages commit is not yet a served page)

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

How each change is proved: the new tests go red before the move and green after; mutate a
version directory (edit a row, drop a file, drop a CHANGELOG entry) and watch each guard fire;
`compare.json` regenerated byte-identical; freeze gate run against an edited and an untouched
copy; `lintr` per-file diff against `origin/main`; `R CMD check` (the byte-identity tests skip
there, so `devtools::test()` must run too); vignette rendered and the published paths in it opened.

Note: [crate#59](https://github.com/NewGraphEnvironment/crate/issues/59) and
[crate#60](https://github.com/NewGraphEnvironment/crate/issues/60) will likely change
`mapping.csv`; whichever lands first after this becomes mapping v1.1.0, the first use of the rule.
