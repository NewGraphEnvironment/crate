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

## crt_receipt_stac() checks what it publishes, not the whole receipt (2026-11-10)

The gate default was to validate against the form schema first. `crt_receipt_validate()` needs
jsonvalidate (Suggests, V8 underneath), so that would make a Suggests package a requirement of
the catalogue path. Instead it checks each value it mirrors: `recipe_id` and part `sha256` as 64
lower-case hex, `context.time` as an ISO UTC time, a version as a non-empty string, `bytes` as a
whole number of at least 0. Null in a file and NA in memory both count as absent.

## Cross-checks of stac.json (2026-11-10)

- `data-raw/receipt_vectors_crosscheck.py` now checks whatever vector files a directory holds; its
  own Python reading of the STAC rows agrees on all 13 `stac.json` cases, and the hashing vectors
  still pass (2637/10/7/13). It also confirms every case's `recipe_id` matches its recipe. Two
  planted mismatches in a copy of `stac.json` (a changed datetime, a changed refusal code) report as
  2 mismatches.
- Mutation of `crt_receipt_stac()` in a worktree: publishing a null `receipt:recipe_id`, and
  skipping an asset whose href names no part, each turn the `stac.json` runner red. Two first-try
  mutants were equivalent and stayed green: `props[[k]] <- NULL` deletes rather than writes null, and
  dropping the unmatched-asset check still errored later in `stac_sha256()`.
- **stacs `stac_fields()` (stacs origin/main 3b08621) over `stac.json`: 11 of 13 agree.** It diverges on
  - `digest_without_receipt_asset`: it ignores a `receipt_sha256` passed with no `receipt_asset`
  - `receipt_asset_in_assets`: it silently overwrites the part's asset with the receipt asset
  Not in the vectors, because the case is not a valid receipt (review item 11): stacs does not
  type-check `recipe.code[repo].version`, so it would publish a number, where crate refuses.
| testthat failure snapshot `tests/testthat/_problems/` committed by `git add -A tests/testthat` in 95f98dd | `git rm` it; stage test files by name |

## Code-check round 1 (2026-11-10): the vectors could not reach a malformed value

Round 1 found the vectors pinned only argument errors: every receipt was valid, so an
implementation that published a malformed `recipe_id`, time, version, size or part digest passed
all 13 cases, and the Python reading did exactly that, with `re.match` and `$` also accepting a
digest followed by a newline. Fixed while v1.1.0 is unreleased: five field-value refusal cases
(each receipt invalid in one field) and a trailing-newline digest case, 19 in all; the crosscheck
refuses the same values with `fullmatch`. stacs now agrees on 15 of 19; its four divergences are in
stacs#15's body.

## Code-check round 2 (2026-11-10): a defect inside round 1's fix, and the enumeration

Round 2 found three, one of them inside round 1's fix: the `version_not_string` case changed the
recipe without recomputing `recipe_id`, so an implementation checking the identity would refuse it
for that reason and never test `version`. The cross-check skipped the identity check on every
refused case, which hid it. Also: one bad value per field left most of each value's population
unpinned (stacs publishes a trailing-newline `recipe_id`, a negative size, an empty version), and
the Python reading treated a non-object block as absent where R and stacs refuse.

Fixes: `bad()` rehashes any recipe change but the `recipe_id` itself; the cross-check confirms the
identity on every case but `recipe_id_not_sha256`; one case per way each value can be malformed;
`block_not_object` refused on both sides (R: an object is a named list, the convention
`crt_receipt_read()` uses, since `{}` reads with names and `[]` without).

**Enumeration (terminal).** Every value `crt_receipt_stac()` reads, parsed from `R/crt_receipt_stac.R`
and the Python reading's `stac_fields()` (both read the same 16), with its guard against the form
schema (`inst/extdata/receipt/schema/v1.0.0/schema.json`) and the classes `stac.json` pins:

| value | R guard | Python guard | schema | pinned (code: classes) |
|---|---|---|---|---|
| `receipt` | named list | dict | object | block_not_object: array |
| `assets` (arg) | named chr, unique, no NA/empty | dict (case format) | n/a | testthat only: unnamed, duplicate, NA (cannot be written as a case) |
| asset href | in `names(parts)` | in parts | n/a | href_not_a_part |
| `receipt_asset` (arg) | string, not in `assets` | not in assets | n/a | receipt_asset_in_assets, receipt_asset_without_digest |
| `receipt_sha256` (arg) | 64 lower hex, needs asset | fullmatch, needs asset | n/a | digest_not_sha256: upper, newline, number; digest_without_receipt_asset |
| `recipe`, `result`, `context` | named list or absent | dict or absent | object | block_not_object: recipe array, result string, context string |
| `recipe.recipe_id` | null, or 64 lower hex | None, or fullmatch | sha256 or null (migrated) | recipe_id_not_sha256: not hex, upper, newline, number; null: migrated case |
| `context.time` | null, or UTC ISO, ASCII digits | None, or fullmatch `[0-9]` | pattern | time_not_utc: space, offset, newline, Arabic-Indic, number; null: no-time case |
| `recipe.code` | named list or absent | dict or absent | object | block_not_object: array, string |
| `recipe.code[repo]` | named list | dict | object | block_not_object: string |
| `...version` | null, or non-empty string | None, or non-empty str | string (minLength 1) or null | version_not_string: number, empty, true; null: two cases |
| `result.parts` | named list or absent | dict or absent | object | block_not_object: array |
| `result.parts[href]` | named list | dict | object | block_not_object: string |
| `...sha256` | 64 lower hex | fullmatch | sha256 | part_sha256_not_sha256: not hex, upper, newline, missing |
| `...bytes` | finite whole >= 0 | int/float, not bool, finite, whole, >= 0 | integer >= 0 | bytes_not_whole: fractional, negative, string, true, missing |

Each published value's guard is the form schema's constraint on it, and each guard's classes are
pinned. The one value both readings accept that a reader might not expect, a version containing a
newline, the schema allows. R refuses each of the 37 refusal cases with a message naming the case's
field (checked by script), and the Python reading refuses each with exactly the case's code. stacs
agrees on 31 of 46; its 15 divergences are in stacs#15's body.

## Code-check round 3 (2026-11-10): the enumeration missed keys, null versus absent, and the migrated rule

Round 3 tested the round-2 enumeration against the code and found what it left out. The shared
assumption, in the reviewer's words: a lookup that returns nothing means absent; only values are
published; refused means refused for its code. The schema separates absent from null (`required`,
the `if` on `output.migrated_from`), publishes keys (repository names, the receipt asset's key),
and R's runner accepted any error. So the enumeration is revised on three axes, each a column the
first table lacked:

- **values read now include `output.migrated_from`** (by presence, as the schema's `if` does),
  which decides whether a missing `recipe_id` is allowed;
- **absent, null and malformed are separate classes** for every block and value: an absent block is
  empty, a present `null` is refused; `recipe_id` absent or null is refused unless migrated, and set
  is refused if migrated; `context.time` absent or null is refused; `version` absent reads as null
  (the item is the same either way, stated in the README);
- **published keys** are rows: a repository's name (`repo_name_empty`), the receipt asset's key
  (`receipt_asset_empty`, `receipt_asset_in_assets`); asset keys are an argument, pinned in
  testthat. Duplicate keys are outside the contract (I-JSON).

The boundary that ends the class, stated in the README: a reading checks the values it publishes,
the keys it publishes, and what decides them, and validates nothing else; a whole-receipt check is
the form schema's. R's runner now pins each case's refusal to its own reason (a message fragment per
code), and seven mutants, one per guard added this round (block guard, null read as absent, missing
`recipe_id` allowed, id on a migrated receipt allowed, time optional, empty repository name,
empty receipt asset), each turn it red. `stac.json`: 61 cases, 53 refusals across 15 codes. The
Python reading matches all 61 with the exact code.

## Code-check round 4 and how the loop ended (2026-11-10)

Round 4's mechanism: the round-3 enumeration was read off the two readings' own bodies, so it
agreed with them by construction; the cases were hand-written per field, so "every block and value"
was a quantifier nobody ran; and R's runner matched message fragments, two of which matched other
codes' messages. Its instances (the form version checked only on the path route, an impossible time
published, `result: null` and a dozen states unpinned, the Python reading crashing on a non-string
`receipt_asset`) were all fixed, and the mechanism was closed by construction:

- **Refusal codes are data.** `crt_receipt_stac()` refuses with a `crate_stac_refused` condition
  carrying `code`; the generator takes each case's code from it, and the runner compares codes.
- **The cases are generated**: 14 paths x their states, plus the receipt and the arguments, 142
  cases in all; a case changes one path, recomputing `recipe_id` inside the recipe.
- **Coverage is checked apart from the generator.** `test-crt_receipt_vectors.R` derives the paths
  from `mapping.csv` (each `STAC item` row's receipt key and its ancestors, plus the two deciders) and
  asserts each has its absent, null and wrong-type cases.

**The loop ended on that enumeration and a mutation table, not on a quiet round.** 21 mutants, one per
guard in `crt_receipt_stac()` plus one dropping a path from the generator, each turn the stac.json
runner red (1 to 58 failing expectations each; `scratchpad/mutate.py` in the session, the table in
progress.md). The independent Python reading matches all 142 cases with the exact code. Five
reviewers ran on this task (one plan review, four code-check rounds); rounds 2, 3 and 4 each found a
defect inside the previous round's fix.

stacs agrees on 87 of 142; the 55 are grouped in stacs#15's body.
