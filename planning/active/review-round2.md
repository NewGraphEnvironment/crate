# Code-check round 2: branch 59 (`git diff 857418b...HEAD`, HEAD b33bfb2)

## Checklist read

- code-check-python.md: in full.
- code-check.md: the prose of all 14 H3s under `## Mechanisms`, table rows skipped. Rules-that-stand-alone, Security and Spreadsheets: none read; their index lines name nothing this diff uses.
- code-check-r.md (by heading): "`$` on a list partial-matches…", "`nzchar(NA)` is TRUE…", "A `data-raw/` script must load the source tree…", "testthat counts an uncaught error under `error`…", "`tryCatch()` nests its handlers…". About 130 other headings not read.
- code-check-shell.md: no heading read. The diff has no shell code.
- code-check-spatial.md: no heading read. The diff has no spatial code.

## How it was checked

- **Worktree probe.** In a detached worktree at HEAD (now removed), I ran each of the 11 refusal cases in stac.json through `crt_receipt_stac()` and read the message. Each refuses on the field its code names.
- **Population probe.** I built 54 one-field variants of the worked receipt and ran each through four readers:
  - R `crt_receipt_stac()`
  - the cross-check's `stac_fields()`, reading JSON with plain ints
  - the same, reading with `parse_int=float`
  - stacs's `receipt.stac_fields()` (stacs at 3b08621)

  The values covered null, booleans, empty strings, ±0, negative and huge sizes, upper-case hex, a trailing `\n`, non-ASCII digits, arrays and objects in scalar slots, and non-object blocks.
- **Suites.** The cross-check gives 19 cases and 0 mismatches. `test-crt_receipt_stac.R` (49), `-vectors.R` (134) and `-write.R` (116) all pass, with 0 failed and 0 errors.
- **Released files.** `git diff --stat` over mapping/v1.0.0, vectors/, register/ and the published mapping/v1.0.0 is empty. v1.1.0's installed and published mapping.csv are byte-identical. v1.1.0's non-STAC rows are unchanged from v1.0.0.

**R and the cross-check agree on every scalar field value probed.** That covers integers vs doubles, booleans, null, empty strings, negative and non-finite sizes, upper-case hex and a trailing newline. They disagree only on malformed block shapes (finding 3).

## Findings

- **[severity: fragile]** inst/extdata/receipt/mapping/v1.1.0/stac.json (data-raw/receipt_vectors.R:371-387): the vectors pin one bad value per field, so the other implementation still publishes malformed values and passes them.
  - **The gap.** The trailing-newline case exists only for `receipt_sha256` (line 371). `recipe_id`, the part `sha256` and `context.time` each get one bad value, and none of those values is a trailing-newline form. `bytes` gets only `1.5`; `version` gets only `1L`.
  - **What stacs does.** I ran stacs's `receipt.stac_fields()` on values no case pins. It publishes every one of them with no error:
    - `receipt:recipe_id` = `"<hex>\n"`
    - an asset `file:checksum` = `"1220<hex>\n"`
    - `processing:datetime` = `"2026-11-04T18:22:05Z\n"`
    - `processing:datetime` = `"٢٠٢٦-11-04T18:22:05Z"` (Arabic-Indic digits; stacs's `_UTC_TIME` uses `\d`)
    - `file:size` = `-1` (stacs's `_whole` has no `>= 0`)
    - a `version` of `""`

    Its `_SHA256_HEX` and `_UTC_TIME` are `^…$` used with `.match`. That is exactly the defect round 1 named in the cross-check.
  - **Why stacs#15 does not cover it.** stacs#15 tracks four divergences on stac.json. Once stacs fixes those four, it passes all 19 cases and still publishes every value above. The round-1 fix closed the hole for one field, not for the population. R and the cross-check refuse all of these values (probed), so the missing cases would cost nothing on crate's side.
  - **Fix.** Add one refusal case per value, under the codes that already exist:
    - `recipe_id`, part `sha256` and `context.time`, each with a trailing `\n`
    - `context.time` with non-ASCII digits
    - `bytes` of `-1`
    - `version` of `""`
  - **Rule:** code-check.md "A fixture that cannot reach the failure mode"

- **[severity: fragile]** data-raw/receipt_vectors.R:380, together with data-raw/receipt_vectors_crosscheck.py:157-162: the `version_not_string` case carries a stale `recipe_id`. Its receipt is therefore not "invalid in that field alone", as the mapping README (line 33) and the cross-check's comment both claim.
  - **What happens.** `bad()` sets `recipe.code.link.version` to `1L` and does not rehash. The probe confirms that this case's `recipe_id` does not match its recipe. The other four field cases do match (`recipe_id_not_sha256` is moot).
  - **Why it matters.**
    - An implementation that checks `recipe_id` against the recipe refuses this case for that reason. It then passes the case without ever checking `version`, and the README tells runners to check only that a case is refused.
    - The cross-check's consistency check skips every case whose `error` is set. So the claim it states is never asserted, which is how this got through.
  - **Fix.**
    - Rehash after `bad()` for a field inside `recipe` other than `recipe_id`. `crt_receipt_recipe_id()` hashes a recipe with `version = 1L` fine (measured: `2e1c68ae…`).
    - Have the cross-check assert the `recipe_id` match on every case except `recipe_id_not_sha256`.
  - **Rule:** code-check.md "A fixture that cannot reach the failure mode" (Assert the premise beside the property)

- **[severity: fragile]** data-raw/receipt_vectors_crosscheck.py:111, 125-126, 139: on malformed block shapes, the Python reading refuses a different set of receipts from R's (and from stacs's), and the docstring offers it as stacs's reference.
  - **Differences, measured:**
    - **`recipe` (also `result`, `context`) of `""`, `false` or `0`.** `receipt.get(k) or {}` treats these as absent and publishes an item with no `receipt:recipe_id` and no `processing:*`. R refuses ("present but not an object"), and so does stacs.
    - **A `code` entry that is `"x"`, `null` or `[]`, or `code` given as an array.** The Python reading raises `AttributeError`, not `Refused`. R silently skips them. For `code` = `[{…}]`, R drops `processing:software` with no error, because an unnamed list has no names to loop over.
    - **A part that is `"x"`, `null` or `[]`.** Python raises `AttributeError`; R refuses.
  - **Impact.** No stac.json case reaches these shapes, so no runner sees the disagreement. A reader who follows the Python reference would publish an item with its provenance silently stripped from a receipt R refuses.
  - **Fix.** Pick one rule for a present-but-non-object block and entry. stacs already refuses (`_mapping`). Apply it in both readings, then pin it with one case.
  - **Rule:** code-check.md "A fix lands in one of two callers that share a harness"
