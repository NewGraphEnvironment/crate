# Code-check round 3: #59/#60 branch (`git diff 857418b...HEAD`)

## Checklist read

- code-check-python.md: in full.
- code-check.md: the prose of all 14 H3s under `## Mechanisms`, in full. Stand-alone, Security and Spreadsheet headings checked against the index only (24 not read in full); none names a tool or shape this diff uses.
- code-check-r.md, read by heading (8): "A `data-raw/` script must load the source tree, not the installed package"; "Tests that silently do not run"; "testthat counts an uncaught error under `error`, not `failed`"; "`$` on a list partial-matches, so a longer sibling key answers for a missing one"; "`nzchar(NA)` is TRUE — non-empty checks silently pass NA"; "Under `R CMD check`, tests run from a temp dir against the INSTALLED package"; "`[[` on a named ATOMIC vector with an absent key is an error, not `NULL`"; "A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared". The rest were checked against the index and not read.
- code-check-shell.md, code-check-spatial.md: index only, 0 headings read. The diff has no shell or spatial code.

## Mechanism

The enumeration takes one row per value that `crt_receipt_stac()` reads, and puts beside it the form schema's **type** constraint on that value. Both readings, and the enumeration, share three assumptions:

1. **A lookup that returns nothing means absent.** R's `x[[name]]` and Python's `.get(name)` and `obj(None)` treat three states as one: absent, present with a `null` value, and (in R only) present with the key `""`, which `[[` cannot reach. The schema's `required` keyword and its `if/then/else` on `output.migrated_from` are the constraints that tell these states apart, and neither reading copied them.
2. **Only values are published.** But object **keys** reach the item too: each repository name becomes a key of `processing:software`, and `receipt_asset` becomes an item asset key. The table has no row for these keys, and neither reading guards them.
3. **Refused is taken to mean refused for the case's code.** Only the Python reading checks the code. R's runner accepts any error, and the claim that R refuses each case for its own field rests on a script that is not committed.

Every finding below comes from one of these three.

## Findings

- **[severity: bug]** R/crt_receipt_stac.R:85-86, 141; data-raw/receipt_vectors_crosscheck.py:126-130. A `recipe_id` that is null or absent is left out whether or not the receipt is migrated. Neither reading looks at `output.migrated_from`. The schema allows a null `recipe_id` only under `then` (when `migrated_from` is present); under `else` it must be a SHA-256. mapping.csv row 41 says "left out when recipe_id is null (a migrated receipt)". I took the worked case `build_1`, set `recipe$recipe_id` to NULL and left it non-migrated. `crt_receipt_validate()` reports `/recipe/recipe_id must be string`, `must match "else" schema`. `crt_receipt_stac()` still returns `processing:datetime` and `processing:software`, with no `receipt:recipe_id` and no error. That is the item "stripped of its identity" that the generator's comment at data-raw/receipt_vectors.R:404 says the refusals exist to prevent. It reads exactly like a migrated item. No case pins it.
  - **Rule:** code-check.md "Zero-length, empty, and unset are three different things" ; code-check.md "A fixture that cannot reach the failure mode"

- **[severity: bug]** data-raw/receipt_vectors.R:372; inst/extdata/receipt/mapping/v1.1.0/README.md:37. The case "no context.time: no processing:datetime" is pinned as valid, but its receipt is invalid against the form. `crt_receipt_validate()` on that case's receipt gives `/context must have required property 'time'`. The installed README tells implementers "Every other receipt is valid against receipt form v1.0.0". An implementation that validates the receipt before mapping it, which a careful one may do, refuses this case and fails a vector that should not be there. The enumeration's schema column gives `context.time` only as "pattern" and leaves out `required`. Its "null: no-time case" is also wrong: `bad(b1, c("context","time"), NULL)` deletes the key, and stac.json's case has no `time` member. A `time` that is present and null is pinned nowhere.
  - **Rule:** code-check.md "A fixture that cannot reach the failure mode" ; code-check.md "A guard's scope, escape hatches, and remedies"

- **[severity: bug]** data-raw/receipt_vectors_crosscheck.py:100-104, 120. The Python reading accepts a null **receipt**, and R refuses it. `obj(None)` returns `{}`, so `stac_fields(None, {}, None, None)` returns `{"assets":{},"properties":{},"stac_extensions":[]}`. R's `crt_receipt_stac(NULL)` aborts with "`receipt` is not an object". The case format can express this (`"receipt": null`), and the R runner would read it as refused. Round 2 fixed this class for the blocks, and it survives one level up, at the top, because `obj()` is shared. The enumeration's row says the Python guard is "dict". It is "dict or None". This file is described as the reference for stacs.
  - **Rule:** code-check.md "A fix lands in one of two callers that share a harness" ; code-check.md "Zero-length, empty, and unset are three different things"

- **[severity: bug]** R/crt_receipt_stac.R:144-146; data-raw/receipt_vectors_crosscheck.py:100-104; README.md:34. A block or entry that is **present with the value null** is read as absent on both sides. That covers `recipe`, `result`, `context`, `recipe.code`, each `recipe.code[repo]` and `result.parts`. The README publishes the contrary rule: "A block or entry present but not an object … `block_not_object`, never read as absent". I measured it on both sides. `{"recipe": null, …}` maps to an item with no `receipt:recipe_id`. `{"recipe":{"code":{"link":null},"recipe_id":null},"context":{"time":null}}` maps to an empty item. Neither side refuses. An implementation that follows the README, and treats null as present and not an object, diverges from crate, and no vector shows it. (A part entry that is null is refused on both sides, but as `part_sha256_not_sha256`, not `block_not_object`.)
  - **Rule:** code-check.md "Zero-length, empty, and unset are three different things" ; code-check-r.md "`$` on a list partial-matches, so a longer sibling key answers for a missing one"

- **[severity: bug]** R/crt_receipt_stac.R:97-103; data-raw/receipt_vectors_crosscheck.py:135-141. Repository names are published as the keys of `processing:software`, and the enumeration does not list them. Neither reading guards them, and the two readings diverge on them:
  - A repository keyed `""` with `version: "9.9"`: R drops it without a word, because `code[[""]]` is NULL, so it is read as having no version. Python publishes `{"": "9.9"}`. The schema refuses it: `propertyNames` `minLength` is 1.
  - A duplicated key `link` (first `"FIRST"`, then `"0.31.2"`): R publishes the first, `"FIRST"`. Python keeps the last, `"0.31.2"`.
  Both were measured. The same R `[[` lookup reads the blocks and the part entries, so a duplicated `recipe`, `result` or part key also resolves first-wins in R and last-wins in Python.
  - **Rule:** code-check.md "A fix lands in one of two callers that share a harness" ; code-check.md "A guard's scope, escape hatches, and remedies"

- **[severity: fragile]** R/crt_receipt_stac.R:62. `receipt_asset = ""` is accepted, and the item gets the asset key `""`. Measured: R returns `"assets":{"":{"file:checksum":…}}`, and Python does the same. `chk::chk_string()` allows an empty string, while `stac_assets_arg()` refuses empty keys in `assets`. So the same kind of value, an item asset key, is guarded in one argument and not in the other. The case format can express it, and no case pins it.
  - **Rule:** code-check.md "A fix lands in one of two callers that share a harness"

- **[severity: fragile]** tests/testthat/test-crt_receipt_vectors.R:165. The R runner checks only `expect_error(call())`, so it cannot see why a case was refused. I deleted the guard at R/crt_receipt_stac.R:147 (block not an object) in a worktree. Four of the eight `block_not_object` cases still "passed": `result a string`, `recipe.code.link a string`, `context a string` and `result.parts.walks.csv a string` were each refused by R's own `subscript out of bounds`. The suite went red only because of the other four. test-crt_receipt_stac.R has no message-level pin for a block that is not an object, apart from `list(1)`. The enumeration's claim that "R refuses each of the 37 … with a message naming the case's field (checked by script)" holds only in a script that is not committed. CI runs no Python, so nothing in CI pins the reason R refuses a case. A round-2-style defect (a case refused for the wrong reason) would pass CI on the R side.
  - **Rule:** code-check.md "A proxy is not the property" ; code-check.md "Restore the bug and prove the guard fires"

## Checked and holding

- Each of the 37 refusal cases is refused in R today with a message that names its own field. I ran all 46 cases. Every case pinned as valid except "no context.time" passes `crt_receipt_validate()`. For each `recipe.*` case, the recipe_id matches its recipe except where `recipe_id` is the bad value.
- In R, `[0-9]` refuses Arabic-Indic digits, and `$` refuses a trailing newline in all three SHA-256 slots and in the time. Python uses `fullmatch` throughout.
- `crt_receipt_write()` hashes the temporary file before the rename. `crt_receipt_migrate(path=)` ignores the new return value and still returns the receipt, which is in scope as decided.
- The released mapping v1.0.0 is unchanged against 857418b. The published v1.1.0 mapping.csv is byte-identical to the installed copy.
