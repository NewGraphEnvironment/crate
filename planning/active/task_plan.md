# Task: The STAC mapping has no implementation and no vectors, so the first consumer defines it (#59), with #60

`mapping.csv` defines a STAC mapping, and the published field schema defines what a conforming item
looks like. Nothing in crate executes that mapping, and no vector pins it, so
`stacs.receipt.stac_fields()` (Python) is the only implementation and its reading is the de facto
contract. #60 (shipped here): the receipt asset carries a `file:checksum` that `mapping.csv` cannot
produce.

## Context

`mapping.csv` defines how a receipt becomes STAC item fields, but nothing in crate executes it and no
vector pins it, so `stacs.receipt.stac_fields()` is the de facto contract. #60: the example item's
receipt-asset `file:checksum` has no source in the mapping. The owner settled six decisions on
2026-11-09 (#59 `## Decisions`). This branch ships both issues as **mapping v1.1.0**: one PR closes both.

Explored: `R/crt_receipt_write.R` (`receipt_write_file()` at :478, `receipt_mapping_version()` at
:206), `R/crt_receipt_migrate.R` (reads the mapping but skips the `STAC item` rows, :55),
`tests/testthat/test-crt_receipt_vectors.R` (byte pins for released files, "every vector file has a
runner"), `test-crt_receipt_migrate.R:134` (mapping row checks), `test-crt_receipt_schema.R:66`
(published copies match the installed ones), `.github/workflows/pkgdown.yaml:43` (released version
dirs are frozen against tags), `data-raw/receipt_vectors.R` + `receipt_vectors_crosscheck.py`, and
stacs `src/stacs/receipt.py` `stac_fields()` / `write()` on origin/main.

## Decided at the gate

- Decisions 1–6 from #59's body (owner, 2026-11-09) are settled.
- **What `crt_receipt_write()` returns** (owner, 2026-11-10: "the soundest design, not gymnastics to
  match what our packages already do"). **Returns the SHA-256 hex of the bytes it wrote, invisibly**,
  like `stacs.receipt.write()`. Why this beats an attribute: the receipt list it returns today is
  not what it wrote (it holds `NA` where the file holds `null`, `crt_receipt_compare.R:157`), and an
  attribute would make that list one `crt_receipt_jcs()` refuses (`crt_receipt_jcs.R:56`). The file
  is the record, the digest names the file, and `crt_receipt_read()` gives back exactly what was
  written. The test for keeping an old shape: does the contract need it (cross-implementation
  agreement, published bytes), or does only today's caller? Only knowledge needs it: 4 call sites,
  measured. It moves at a cost of one `crt_receipt_read()` line each, filed as a knowledge issue.
  Breaking change, so a minor version bump at merge.
- **Defaults I'm choosing, for you to overrule at approval:**
  - Two assets whose hrefs name one part are **allowed**: both mirror it. It is the same file.
  - A `receipt_asset` key that is also in `assets` is **refused**, and so is `receipt_sha256` with no
    `receipt_asset`. stacs silently overwrites the first and ignores the second, so the vectors will
    show stacs diverging; that goes in the stacs issue.
  - `crt_receipt_stac()` validates the receipt against the form schema first (`crt_receipt_validate`),
    so a malformed receipt is not a mapping question and needs no checks of its own.
  - The receipt-asset row in `mapping.csv` has an **empty `receipt_key`**, because its value comes from
    outside the receipt. The mapping test allows an empty key on that row only.
  - `stac.json` is installed with crate and not published on the site, like `compare.json`.

## Phase 1: Tests first
- [x] `tests/testthat/test-crt_receipt_stac.R`: a normal receipt (worked_case build_1), a migrated one
      (null `recipe_id` → no `receipt:recipe_id`, no receipt extension URL), a null
      `code[repo].version` (repo left out; none versioned → no `processing:software`), a part with no
      asset (not mirrored), two assets on one part, the receipt asset (`1220` + digest, no
      `file:size`); errors: an href that is no part, `receipt_asset` without digest, digest without
      `receipt_asset`, a key collision, a digest that is not 64 lowercase hex
- [x] `test-crt_receipt_write.R`: the return value equals `digest::digest(file = <receipt>, algo = "sha256")`
      and is invisible; existing tests that read the returned list move to `crt_receipt_read()`

## Phase 2: `crt_receipt_write()` returns the digest (#60)
- [x] `receipt_write_file()` hashes the bytes it wrote (the temp file, before the rename) and returns it
- [x] `@return`, the example (`crt_receipt_read()` for the fields), and crate's own callers:
      `data-raw/receipt_examples.R`, tests, `vignettes/receipt.Rmd`

## Phase 3: `crt_receipt_stac()` (#59)
- [x] `R/crt_receipt_stac.R`: `crt_receipt_stac(receipt, assets = NULL, receipt_asset = NULL,
      receipt_sha256 = NULL)` takes a receipt as a path or a list, like `crt_receipt_compare()`, and
      `assets` as a named character vector (asset key → href relative to the item). It returns
      `list(stac_extensions, properties, assets)`, with the extension URLs in the example item's
      order (file, processing, receipt) and only those whose fields are present. Runnable example on
      the worked case
- [x] `devtools::document()`; `pkgdown::check_pkgdown()` (`starts_with("crt_receipt_")` covers it)

## Phase 4: Mapping v1.1.0 and `stac.json`
- [x] `inst/extdata/receipt/mapping/v1.1.0/mapping.csv`: the v1.0.0 rows, with notes stating
      omit-on-null for `receipt:recipe_id` and `processing:software`, the unmatched part and asset
      rules on `assets.*.file:checksum`, and a new `assets.{receipt}.file:checksum` row (multihash of
      SHA-256 over the published receipt bytes, which the writer returns, never from a part; no
      `file:size`, deliberately)
- [x] `stac.json` beside it, written by a new section of `data-raw/receipt_vectors.R`. Each case is
      `{name, receipt, assets, receipt_asset, receipt_sha256, expected | error}`, compared as
      canonical JSON. Cases as in Phase 1. Plus `README.md` for the directory
- [x] `receipt_mapping_version()` → `"1.1.0"`; published copy at
      `pkgdown/assets/receipt/mapping/v1.1.0/mapping.csv`; a `receipt/CHANGELOG.md` entry
- [x] Vector tests: a runner for `stac.json`, the "every vector file has a runner" set, byte pins for
      the two new files; the mapping row test allows the empty `receipt_key` on that one row only

## Phase 5: Cross-check against two other implementations
- [x] `data-raw/receipt_vectors_crosscheck.py`: an independent Python mapping that recomputes every
      `stac.json` case
- [x] Run stacs's `stac_fields()` (stacs checkout, read-only) over `stac.json`; record each divergence
      in `findings.md`

## Phase 6: Docs and follow-on issues
- [x] `vignettes/receipt.Rmd`: a "STAC items" section (a `crt_receipt_stac()` example, what an
      unmatched part and an unmatched asset mean, the receipt asset's checksum), and the test-vector
      section names `mapping/v1.1.0/stac.json`
- [x] `CLAUDE.md`: add `crt_receipt_stac` to the receipt family, and mapping v1.1.0 to the status line
- [x] File a knowledge issue: `crt_receipt_write()` now returns the digest, so read the receipt with
      `crt_receipt_read()` (4 call sites)
- [x] Edit the body of stacs#15 (re-vendor from versioned paths), or file a new stacs issue: vendor
      mapping v1.1.0, run `stac.json`, and fix the divergences Phase 5 found

## Owed at the end (reported, done after merge)
- [ ] NEWS + minor bump at `/gh-pr-merge` (breaking: `crt_receipt_write()`'s return value)

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean (once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

How each change is proved:
- `devtools::test()` (FAIL and ERROR both 0), `lintr::lint_package()` with no new lints against
  main, `devtools::check()`
- `python -I data-raw/receipt_vectors_crosscheck.py` exits 0 on `mapping/v1.1.0`
- Mutation: break the null-`recipe_id` omission and the unmatched-asset error in `crt_receipt_stac()`,
  and see the `stac.json` runner go red
- The mapping bump does not move migration: `crt_receipt_migrate()` on both legacy examples gives
  `identical()` results under v1.0.0 and v1.1.0 (from a worktree of main)
- The returned digest equals the SHA-256 of `receipt.json` on disk, for the worked case

