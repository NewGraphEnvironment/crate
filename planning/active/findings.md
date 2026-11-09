# Findings — register.csv and mapping.csv are unversioned, and every verdict is a function of their rows (#58)

## Issue context

**If we do it:** a non-R implementation can pin the register and the mapping the way it pins the schema, and a verdict says which register produced it. **If we never do:** the 43 rows that decide every verdict can change under a published comparison with nothing recording which version answered.

## Problem

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

## Proposed

- [ ] Move both to the versioned path beside the schema: `inst/extdata/receipt/v1.0.0/register.csv` and `.../mapping.csv`, with the readers following
- [ ] Publish them at the versioned URL too, as the schema is (`newgraphenvironment.github.io/crate/receipt/v1.0.0/`), so an implementation in any language can fetch the exact rows its verdicts were computed from
- [ ] Carry the register version on the comparison object and in `print()`, so a reported verdict names what produced it
- [ ] A `CHANGELOG.md` beside them, under the rule the STAC extensions already use: a row's `action` changing is a version change, because it changes a published verdict

Found while implementing the contract in Python: https://github.com/NewGraphEnvironment/stacs/issues/12 and https://github.com/NewGraphEnvironment/stacs/pull/13.

## Exploration (2026-11-09)

- `crt_receipt_read()` (`R/crt_receipt_read.R:34`) refuses any receipt whose `receipt_version` is not the current one, so the register row `output.receipt_version,warn` cannot fire through a path-based comparison. This is why the receipt's number must mean the form only: tying the register to it would make a one-row action change unreadable for every existing receipt.
- `vectors/v1.0.0/compare.json` stores each difference's action, so it already froze the register implicitly, under the form's number.
- Org code search 2026-11-09: knowledge writes real v1.0.0 receipts (`R/publish.R`, `data-raw/database_receipts.R`); nobody calls `crt_receipt_migrate()` in code (only stacs research notes and a soul planning file).
- stacs vendors at crate tag v0.12.0 with blob shas (`src/stacs/data/receipt/SOURCE`): register.csv, mapping.csv and compare.json paths will move; its tag pin keeps working until it re-vendors.
- Freeze gate: `.github/workflows/pkgdown.yaml` step "Check the published schemas against what is on gh-pages" covers only `schema.json`.

## Errors Encountered

| Error | Resolution |
|-------|------------|

## Mutation table (2026-11-09, each in a fresh worktree of c6f7eff)

| mutation | test file | failing tests |
|---|---|---|
| none (baseline) | schema | 0 |
| published register row edited | schema | 1 |
| changelog register entry removed | schema | 1 |
| register entry names no form | schema | 1 |
| changelog names an unpublished version | schema | 1 |
| extra published version with no installed copy | schema | 2 |
| current mapping version points at no directory | schema | 1 |
| overrides keep restated actions | compare | 1 |
| print drops the register | compare | 2 |
| compare.json back in the vectors dir | vectors | 2 |

Freeze gate (pkgdown.yaml) in a scratch repo against gh-pages f7dbbbc: clean rc=0; published and unchanged rc=0; edited release rc=1; dropped release rc=1; copy not reaching the site rc=1.
