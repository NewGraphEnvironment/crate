# Findings — The STAC mapping has no implementation and no vectors (#59), with #60

## Issue context

### #59

**If we do it:** the STAC half of the contract gets the same treatment as the hashing half — an implementation and vectors any language can run. **If we never do:** the mapping's meaning is whatever the first implementation guessed, and the second one will differ somewhere nobody notices.

## Scope

Done together with #60 (the receipt asset's `file:checksum`). Both change how the STAC item is built, and any change to the mapping is mapping v1.1.0, so one branch ships both in one `inst/extdata/receipt/mapping/v1.1.0/` directory, and its PR closes both. `/planning-init 59` takes #60's checkboxes in as a phase.

## Decisions

Decided by the owner, 2026-11-09, before planning. Three match what `stacs.receipt.stac_fields()` already does; checked against stacs's code and crate's example item (`pkgdown/assets/stac/receipt/examples/item.json`), not against published items.

1. **A migrated receipt (null `recipe.recipe_id`):** the item omits `receipt:recipe_id`; it never publishes `null`.
2. **A null `recipe.code[repo].version`:** that repo is omitted from `processing:software`; with no versioned repo the property is omitted.
3. **The receipt asset's `file:checksum`** (#60): multihash of SHA-256 over the published receipt bytes, supplied by the writer, never from a part.
4. **Unmatched parts and assets:** a part with no asset is allowed and not mirrored (an item may publish fewer files than the build made). An asset asked to be mirrored whose href matches no part is an error, never a guessed or omitted checksum.
5. **Implementation:** crate gets `crt_receipt_stac()`, taking what `stac_fields()` takes (the receipt, asset hrefs relative to the item, the receipt asset and its digest) and returning `stac_extensions`, `properties` and `assets`. crate generates `stac.json`'s expected outputs from it, and stacs runs the same vectors, so the two implementations check each other.
6. **The receipt asset carries `file:checksum` and no `file:size`** (#60), stated as deliberate in the mapping notes; the example item stays as it is. `crt_receipt_write()` returns the digest of the bytes it wrote.

## Problem

`mapping.csv` defines a STAC mapping, and the published field schema (`pkgdown/assets/stac/receipt/v1.0.0/schema.json`) defines what a conforming item looks like. Nothing in crate executes that mapping, and no vector pins it. Grepped at v0.14.1 over `R/`, `man/`, `tests/`, `NAMESPACE` and `NEWS.md`: there is no `crt_receipt_stac()` or anything like it. The receipt R files are `crt_receipt_{compare,jcs,keys,migrate,read,write}.R`.

Compare that with the hashing core, which has 2,667 vectors across four files and a crosscheck script: an independent implementation can prove it agrees to the byte.

So `stacs.receipt.stac_fields()` (Python) is currently the **only** implementation of the STAC mapping, which makes its reading of `mapping.csv` the de facto contract — and it is unvalidated by anything crate ships. Four readings it had to settle with no vector to check them against:

1. **`file:checksum` form.** Multihash `1220` + the 64 hex of the part's `sha256`. The published example item agrees, so this one is anchored by one example.
2. **Which part a given asset maps to.** The mapping's note says "the asset's href relative to the item is the part's path". So a part key is matched against a relative href — but nothing says what to do when an asset's href matches no part, or when two assets resolve to one part.
3. **A migrated receipt.** `recipe.recipe_id` is `null`, and the mapping gives it `receipt:recipe_id`. stacs **omits** the property rather than publishing `null`, because the field schema's pattern would otherwise accept a null identity. Nothing in crate says which is intended.
4. **A null `recipe.code[repo].version`.** The schema allows it; `processing:software.<repo>` then has no value, and stacs omits the entry.

Each of those is a place two implementations can diverge while both pass the schema.

*Since #58: the mapping is versioned on its own (`inst/extdata/receipt/mapping/v1.0.0/mapping.csv`, published at `receipt/mapping/v1.0.0/mapping.csv`), and a released version directory is frozen: the pkgdown workflow fails a file added to one. So the STAC vectors go in a new version directory rather than beside the v1.0.0 vectors, and any row change to the mapping is mapping v1.1.0 (`receipt/CHANGELOG.md`).*

## Proposed

- [ ] A `stac.json` vector file beside the others: receipt in, the expected item `properties` and per-asset fields out. At least a normal receipt, a migrated one (null `recipe_id`), a receipt with a null `code[repo].version`, and a receipt whose part matches no asset
- [ ] Either `crt_receipt_stac()` in crate, run against those vectors, or a line in the vignette saying crate publishes the mapping as data only — so an implementer knows whether they are the first
- [ ] Say in the mapping's notes, or the vignette, what an unmatched part and an unmatched asset each mean

Found while implementing the contract in Python: https://github.com/NewGraphEnvironment/stacs/issues/12 and https://github.com/NewGraphEnvironment/stacs/pull/13.

### #60

**If we do it:** the receipt asset's own `file:checksum` has a stated source, so two implementations compute the same value. **If we never do:** the one worked example an implementer copies carries a digest the mapping cannot produce, and each of them guesses.

## Scope

Ships in #59's branch (the STAC mapping's vectors and implementation): both change how the STAC item is built, and any change to the mapping is mapping v1.1.0, so one `mapping/v1.1.0/` directory carries both. Do not start this separately.

## Decisions

Decided 2026-11-09 (#59, `## Decisions` 3 and 6): the receipt asset's `file:checksum` is the multihash of SHA-256 over the published receipt bytes, supplied by the writer; it carries no `file:size`, stated as deliberate in the mapping notes, and the example item stays as it is; `crt_receipt_write()` returns the digest of what it wrote.

## Problem

The published example item gives its receipt asset a checksum:

```json
"receipt": {
  "href": "receipt.json",
  "type": "application/json",
  "roles": ["metadata"],
  "title": "Provenance receipt",
  "file:checksum": "12207d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730"
}
```

`mapping.csv`'s only asset rows are

```
STAC item,assets.*.file:checksum,result.parts[*].sha256,multihash,file:checksum
STAC item,assets.*.file:size,result.parts[*].bytes,,file:size
```

which cannot produce that value: the receipt is not one of its own parts, and it cannot be — a digest of the receipt's bytes would have to include itself. So the example's `12207d86…` has no source in the contract, and three things are left unsaid:

1. **Where the value comes from.** Presumably SHA-256 of the receipt bytes as published, taken by the writer after the file is written. Nothing says so.
2. **Whether it is expected at all**, or optional on the receipt asset.
3. **Whether `file:size` is deliberately absent.** The data asset in the same example carries both `file:size` and `file:checksum`; the receipt asset carries only the checksum. A reader cannot tell whether that is the rule or an omission in the example.

This is load-bearing downstream rather than cosmetic. `stacs.receipt.write()` returns the SHA-256 of the bytes it wrote precisely so a caller can fill this field, and its `verify` compares a served item's receipt asset against the published receipt — against a field crate's mapping does not define. If crate later says the digest is of something else (the canonical form, say, rather than the published bytes), every item already published disagrees.

*Since #58: `mapping.csv` is versioned (`inst/extdata/receipt/mapping/v1.0.0/mapping.csv`, published at `receipt/mapping/v1.0.0/mapping.csv`) and v1.0.0 is frozen, so a row added or changed for the receipt asset is mapping v1.1.0 (`receipt/CHANGELOG.md`).*

## Proposed

- [ ] A `mapping.csv` row, or a sentence in the vignette, stating that the receipt asset's `file:checksum` is the multihash of SHA-256 over the **published receipt bytes**, computed by the writer after the receipt is written, and never from a part
- [ ] Say whether `file:size` is expected on the receipt asset, and make the example carry both fields or neither
- [ ] If it is the writer's job, have `crt_receipt_write()` return or report that digest, so the caller filling the item does not re-read the file and risk hashing a different version

Found while implementing the contract in Python: https://github.com/NewGraphEnvironment/stacs/issues/12 and https://github.com/NewGraphEnvironment/stacs/pull/13.

## Exploration (2026-11-10)

- stacs `stac_fields()` (origin/main `src/stacs/receipt.py:1079`): omits a null `recipe_id`, omits
  repos whose version is null, errors on an href that is not a part, **silently overwrites** an
  `assets` key equal to `receipt_asset`, and **ignores** `receipt_sha256` when there is no
  `receipt_asset`. Extensions in the order file, processing, receipt.
- stacs vendors crate at tag v0.12.0 (`tools/crate_receipt_vendor.sh`); stacs#15 already asks to
  re-vendor from the versioned paths.
- `crt_receipt_write()` returns the in-memory receipt, which holds `NA` where the file holds `null`
  (`crt_receipt_compare.R:157`). knowledge calls it in 4 places (`R/evidence_receipt.R`,
  `R/grade_receipt.R`, `R/publish.R`, `data-raw/database_receipts.R`); its two exported writers'
  examples read `r$recipe$recipe_id`.
- `crt_receipt_jcs()` refuses any attribute but `names` (`crt_receipt_jcs.R:56`), so an attribute on
  the returned receipt was ruled out.
- `crt_receipt_migrate()` skips the `STAC item` rows (`crt_receipt_migrate.R:55`), so mapping v1.1.0's
  STAC-only changes cannot move a migration.
- Released version dirs are frozen by the pkgdown workflow against release tags, and by byte pins
  in `test-crt_receipt_vectors.R`.

## Errors Encountered

| Error | Resolution |
|-------|------------|
