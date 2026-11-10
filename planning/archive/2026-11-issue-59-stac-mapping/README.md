# #59 (with #60): the STAC mapping, executed and pinned

## Outcome

The receipt mapping's `STAC item` rows now have an implementation and vectors. `crt_receipt_stac()`
maps a receipt to the item fields that mirror it. Mapping v1.1.0 (`inst/extdata/receipt/mapping/v1.1.0/`)
states what v1.0.0 left open:

- a migrated receipt leaves `receipt:recipe_id` out, and a missing id on any other receipt is refused
- a null `version` is left out
- a part with no asset is not mirrored, and an asset whose href names no part is refused
- the receipt asset's `file:checksum` is the digest of the published receipt's bytes, with no `file:size` (#60)

`crt_receipt_write()` now returns that digest instead of the in-memory receipt, by the owner's
decision at the gate: the list it returned held `NA` where the file holds `null`, so the file is the
record and the digest names it. knowledge#188 moves knowledge's four call sites.

Every refusal is a classed condition carrying a code. `stac.json` (142 cases) is generated: every
path the mapping reads, crossed with every state. A test derives those paths from `mapping.csv` on
its own and checks the coverage.

What was learned is the review's own story. Four code-check rounds each found the cases narrower
than the claim: valid receipts only, then one bad value per field, then no null-versus-absent and no
published keys, then an enumeration that had been read off the code it was checking. Rounds 2 to 4
each found a defect inside the previous fix. It ended when the cases stopped being written by hand
and were generated, with an independent coverage check, refusal codes as data, and a mutation table.
The design is in `research/provenance_receipt.md` ("The STAC rows are executed and pinned").

## Measurement

- **`stac.json`: 142 cases, 125 of them refusals across 17 codes.** It grew from 13 to 142 over
  the four review rounds.
- **Python check (`data-raw/receipt_vectors_crosscheck.py`):** it matches all 142 cases with the exact
  refusal code. The hashing vectors still pass (2637/10/7/13).
- **Mutation:** 21 of 21 mutants turn the `stac.json` runner red, between 1 and 58 failing
  expectations each. There is one mutant per guard in `crt_receipt_stac()`, plus one that drops a
  path from the generator, which the coverage test catches.
- **Wrong turns:**
  - Two first mutants were equivalent to the code they replaced. `props[[k]] <- NULL` deletes the
    element, and the unmatched-asset check failed later anyway.
  - Two mutants were mangled by a `|` delimiter meeting `||` in the code, and were rerun.
  - The coverage test first concretized `[*]` without its brackets.
- **stacs `stac_fields()` (origin/main 3b08621):** it agrees on 87 of 142. Each of the 55 others is a
  case stacs accepts and crate refuses, grouped in stacs#15's body.
- **Migration is unchanged by the mapping bump.** `crt_receipt_migrate()` gives identical canonical
  JSON on both legacy examples under v1.0.0 (a worktree of main) and v1.1.0.
- **Released files:** regenerating every vector file left each released one byte-identical.
- **Tests and check:** the full suite passes, 2547 expectations; `R CMD check` gives 0 errors and 0
  warnings, with 1 environmental note (future timestamps); lintr adds no lints over main.

## Owed

- NEWS + minor bump at `/gh-pr-merge` (breaking: `crt_receipt_write()`'s return value)

Closed by: the PR from branch `59-the-stac-mapping-has-no-implementation-a` (closes #59 and #60)
