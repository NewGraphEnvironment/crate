# Code-check round 4 (#59, #60): branch diff 857418b...HEAD

## Checklist read

- `code-check-python.md`: in full.
- `code-check.md`: the prose of every H3 under `## Mechanisms` (all 14), tables skipped; also
  "An assertion that matches an interpolated value cannot see the claim around it". The other
  standalone, Security and Spreadsheets headings name nothing this diff uses (about 20 not read).
- `code-check-r.md`: "Read-back shape must match write-back shape", "`$` on a list
  partial-matches…", "`nzchar(NA)` is TRUE…", "testthat counts an uncaught error under `error`…",
  "A value compared as `::text`…", "`ifelse()` with an all-NA test…", "`sub()` takes one
  replacement…". About 130 other headings were not read; their index lines name tools this diff
  does not use.
- `code-check-shell.md`: no section read. The diff contains no shell.
- `code-check-spatial.md`: no section read. The diff does nothing spatial.

## How it was tested

All probes ran in a detached worktree at HEAD, which has since been removed. The repo is untouched
apart from this file.

- Regenerating the vectors (`Rscript data-raw/receipt_vectors.R`) reproduced every vector file
  byte for byte, released ones included.
- `test-crt_receipt_vectors.R` and `test-crt_receipt_stac.R`: 0 failed, 0 error, 0 skipped.
- The crosscheck reports 0 mismatches on `mapping/v1.1.0` (61 cases) and on `vectors/v1.0.0`.
- Every `stac.json` receipt was validated against the form schema with Python jsonschema. Every
  case that is not a refusal, and every argument-refusal case, is valid. Each value-refusal case is
  invalid only in its own field. Python's `re.search` `$` explains the three trailing-newline cases
  that it reads as valid.
- 46 extra probe receipts covered the states the vectors do not hold: `{}`, absent, null, `[]`,
  `[x]`, false, empty, lower case, out of range, a migrated receipt with `recipe_id` absent, `[]` or
  false, `-0`, `1e300`, and 2^53+1 bytes. They ran through R `crt_receipt_stac()` (list route) and
  the Python `stac_fields()`. The two agree on every probe except the two in finding 4.

## Mechanism

**The round-3 enumeration was taken from the two reading functions' bodies, the code it checks.
So it agrees with that code by construction, and it cannot see three things.**

- Checks made on another route into the same function: R's path route goes through
  `crt_receipt_read()`.
- The states a source schema treats differently from the readings: the form's vacuous `if` when
  `output` is absent.
- The constraints of the destination fields the item publishes: `format: date-time`.

The case list, and the README sentence that counts it, are also written by hand per field rather
than generated as a cross product of each block or value with each state. So "every block and
value" and "one case for each way" are quantifiers that nobody ran. Every finding below is an
instance of this.

Rule for the mechanism: code-check.md "A proxy is not the property". Its paragraph on coverage
says a sweep that shares the checker's predicate agrees by construction.

## Findings

- **[severity: bug]** R/crt_receipt_stac.R:58, R/crt_receipt_read.R:31-40: `crt_receipt_stac()`
  gives different verdicts by route. Given a path, it goes through `crt_receipt_read()`, which
  refuses three receipts: one with no `output`, one whose `output.receipt_version` is not
  "1.0.0", and one with no version at all. Given the same receipt as a list, it publishes
  `receipt:recipe_id`, `processing:datetime` and `processing:software` for all three (measured).
  The Python reading publishes too.
  - So `receipt_version` decides whether mapping v1.1.0 applies at all, but it appears neither in
    the README's "what decides them" nor in the enumeration.
  - The vectors runner uses only the list route, so no case can pin it.
  - Either check `output.receipt_version` (and `output`'s presence) in `crt_receipt_stac()` and in
    `stac_fields()`, with a code and cases, or say in the README that the version is not read. As
    things stand, R's path route validates "the rest" and the README says no reading does.
  - **Rule:** code-check.md "A fix lands in one of two callers that share a harness" ; code-check.md "A proxy is not the property"

- **[severity: fragile]** inst/extdata/receipt/mapping/v1.1.0/README.md:40 ("by its presence,
  as the form schema's `if` does"): the two halves of that sentence disagree when `output` is
  absent.
  - The schema's `if` is `{"properties": {"output": {"required": ["migrated_from"]}}}`. It holds
    vacuously when `output` is absent or not an object, so the schema treats such a receipt as
    migrated. Jsonschema confirms it: the "output null" and "output an array" cases also fail
    `recipe/recipe_id is not of type 'null'`.
  - Both readings treat an absent `output` as not migrated. They publish `receipt:recipe_id`, or
    refuse `recipe_id_missing` when the id is null.
  - An implementation that follows the README's "as the schema's `if` does" literally refuses
    `recipe_id_on_migrated` instead, and that passes every case.
  - The decider's absent-parent state is unpinned, and R's path route does a third thing: it
    refuses "no output block".
  - **Rule:** code-check.md "Zero-length, empty, and unset are three different things"

- **[severity: fragile]** R/crt_receipt_stac.R:107 and data-raw/receipt_vectors_crosscheck.py:93:
  `context.time` is checked only against the form's pattern. Both readings publish
  `processing:datetime: "2026-13-45T25:61:61Z"` (measured).
  - The destination field schema declares `{"type": "string", "format": "date-time", ...}`
    (processing v1.2.0, fetched today).
  - The generator says these checks exist "so an implementation cannot publish what the field
    schema or a reader would refuse" (data-raw/receipt_vectors.R, the comment before the
    `field_cases` block).
  - The README lists "out of range" among the ways a value can be malformed, and R's own message
    calls the value "not an ISO 8601 UTC time".
  - pystac 1.15.2 does not enforce the format, so its validation passes. A validator or reader
    that parses the date-time refuses the item.
  - The other published values have no such gap: `file:size` is integer ≥ 0, `file:checksum` is
    `^[a-f0-9]+$`, `receipt:recipe_id` matches the form, and `processing:software` values are
    strings with keys `.{1,}`.
  - **Rule:** code-check.md "A proxy is not the property"

- **[severity: fragile]** data-raw/receipt_vectors.R:437-459 and README.md:30-37: the pinned set
  is smaller than the README's quantifier and round 3's claim.
  - Round 3's claim (findings.md:213) is that absent, null and malformed are separate classes
    "for every block and value". The README says "one case for each way the value can be
    malformed (the wrong type, empty, missing, null, …)". Neither holds against the cases:
    - **`result: null`: no case.** Only `result` as a string is pinned, while output, recipe and
      context each have a null case. An implementation that reads a null `result` as absent
      publishes an item from a receipt with no assets and passes all 61 cases. That is the
      round-2 defect class: Python read a non-object block as absent.
    - **Part `sha256`:** null, a number and empty are not pinned.
    - **`bytes`:** null is not pinned.
    - **`recipe_id`:** empty and non-ASCII are not pinned.
    - **`context.time`:** empty, lower-case `t`/`z` and out of range are not pinned.
    - **Absent blocks:** not pinned. For example, a migrated receipt with no `recipe.code` is
      valid under `recipe_migrated`, and nothing pins that it yields no `processing:software`.
  - Both readings agree on every one of these today (probed). So this is coverage, not a
    divergence, but the vectors are the contract other implementations run.
  - Remedy: generate the cases as the product of each read path (block or value) with each state,
    and have the R test assert that every (path, state) pair has a case, or carries a recorded
    reason why not. Do not extend the list by hand.
  - **Rule:** code-check.md "A fixture that cannot reach the failure mode" ; code-check.md "A guard's scope, escape hatches, and remedies"

- **[severity: fragile]** README.md:35-37, R/crt_receipt_stac.R:58: the README files "the receipt
  itself" under `block_not_object`, but R reads a JSON string receipt as a path. A string-receipt
  case would be refused in R with "No receipt at 'x'", a reason other than its code; Python
  refuses `block_not_object` (probed).
  - The API overloads `receipt` as an object or a path, so the README's statement does not hold
    for R. Either say so, or have the runner pass vector receipts so that a string cannot be
    mistaken for a path.
  - **Rule:** code-check.md "A proxy is not the property"

- **[severity: fragile]** data-raw/receipt_vectors_crosscheck.py:111-115,170: the Python reading
  never checks that `receipt_asset` is a string, although it publishes it as an asset key. Given a
  number, it raises `CanonicalizationError` from `jcs()`, not `Refused`. `check_stac()` catches
  only `Refused`, so the whole crosscheck aborts with a traceback instead of reporting a mismatch.
  R refuses the same input with `chk_string`.
  - The round-2 enumeration table records the asymmetry ("string, not in `assets`" against "not
    in assets") without calling it one.
  - The accepted tradeoff covers argument shape for `assets` only. Either extend it to
    `receipt_asset` explicitly, or give both readings a check.
  - **Rule:** code-check.md "A wrapper's exit is not the work"

- **[severity: fragile]** tests/testthat/test-crt_receipt_vectors.R:160-166: round 3's "each
  case refused for its own reason" pin uses message fragments that overlap. Run over every refusal
  case, two fragments match messages that belong to other codes:
  - `"sha256 must be"` (part_sha256) matches all three `digest_not_sha256` messages.
  - `"needs"` (receipt_asset_without_digest) matches the `receipt_asset_empty` message ("an asset
    needs a key") and the assets-href message.

  No current case is refused for the wrong reason, because each case carries one fault. But a
  later case with two faults, or a reordered guard, would pass on the other code's message.
  Anchor each fragment to text that only its own message carries, and assert that each case's
  message matches exactly one fragment.
  - **Rule:** code-check.md "A guard that fails toward pass" (its case "a `case` allowlist that matches substrings rather than tokens")

## Reviewed and clean

- **The `json_null`, `bad()` and `empty_key` sentinels.** `bad()` writes a present null for paths
  of length 1 and of any depth. It rehashes every recipe change except one to `recipe_id`, and
  every case's `recipe_id` matches its recipe in the crosscheck.
- **`write_vectors()`'s `gsub`.** It runs on every file, but no released file contains
  `"__crate_empty_key__"`. The md5 guard runs after the substitution and refuses any change to an
  existing file. A full regeneration left all released files byte-identical.
- **`crt_receipt_write()`'s digest.** It is taken from the temp file before the rename, and
  `crt_receipt_migrate(path =)` ignores the new return value.
- **The mapping files.** The v1.1.0 `mapping.csv` matches its published copy, and v1.0.0 is
  unchanged (pinned).
