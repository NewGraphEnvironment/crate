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

## Code-check round 2 guards (each in a fresh worktree)

| mutation | result |
|---|---|
| compare.json hand-edited | vectors: 2 failing |
| installed mapping.csv row edited | vectors: 1 failing |
| stray released file | vectors: 2 failing |
| duplicate changelog heading | schema: 1 failing |
| "covers form v1.0.0 only." (correct wording) | schema: 0 failing |
| current register covers wrong form | schema: 1 failing |
| code change moves a verdict, then `data-raw/receipt_vectors.R` | 1 refusal, 0 inst files changed |

## Code-check round 3: a defect inside round 2's fix, and the enumeration

Round 3 found that round 2's SHA-256 pins live in the same tree as the files they pin, so one commit can edit both (mechanism: a frozen-file rule checked only against a reference in the same commit). Fix: a pkgdown workflow step compares every released contract file with the latest release tag; the pins stay as the R CMD check backstop. Mutations (fresh worktrees, step script extracted from the YAML): moved compare.json edited rc=1; numbers.json edited rc=1; jcs.json gone rc=1; installed schema edited rc=1; compare.json edited together with its pin rc=1; unmutated branch rc=0 with one move warning.

Enumeration of every frozen file in the contract and its independent reference (one outside the commit under review):

| frozen file | independent reference |
|---|---|
| `pkgdown/assets/stac/*/v*/schema.json` | gh-pages (freeze gate) |
| `pkgdown/assets/receipt/v*/schema.json` | gh-pages (freeze gate) |
| `pkgdown/assets/receipt/{register,mapping}/v*/*.csv` | gh-pages (freeze gate), from their first deploy |
| `inst/extdata/receipt/schema/v*/schema.json` | latest release tag (new step); also byte-identical to the published copy (test) |
| `inst/extdata/receipt/vectors/v*/*.json` | latest release tag (new step) |
| `inst/extdata/receipt/register/v*/{register.csv,compare.json}` | latest release tag once released; compare.json now via its move from `vectors/` (bytes equal v0.14.1) |
| `inst/extdata/receipt/mapping/v*/mapping.csv` | latest release tag once released |

The one gap is inherent: register.csv and mapping.csv v1.0.0 are first released by this PR, so no deploy or tag holds them at their new paths yet. Their bytes equal the unversioned files at v0.12.0 through v0.14.1 (blob shas checked, and by round 3). Not frozen by design: READMEs and CHANGELOGs (prose, revised in place).
