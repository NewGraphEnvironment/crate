# Review round 1: branch 59-the-stac-mapping-has-no-implementation-a (`git diff 857418b...HEAD`, at ada0d16)

## Checklist read

- code-check-python.md: in full.
- code-check.md: the prose of all 14 H3s under `## Mechanisms` (table rows and evidence blocks skipped). Of the stand-alone, Security and Spreadsheets/PDFs headings, read none in full (0 of 21); none names a tool or shape this diff uses beyond what the index line states.
- code-check-r.md: read 7 headings in full: "`$` on a list partial-matches, so a longer sibling key answers for a missing one"; "`nzchar(NA)` is TRUE — non-empty checks silently pass NA"; "`identical()` on two reader results tests the reader, not the file"; "`expect_false(identical(x, y))` cannot fail when the two are different types"; "`[[` on a named ATOMIC vector with an absent key is an error, not `NULL`"; "A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared"; "ajv honours keywords beside a `$ref`; Python's jsonschema ignores them". The rest were checked against the index line only (about 115 not read).
- code-check-shell.md: 0 headings read; the diff has no shell code and does not change the workflow.
- code-check-spatial.md: 0 headings read; the diff has no spatial code.

## What I ran (in a detached worktree at HEAD, since removed)

- The test files for stac, vectors, write, compare and migrate, with `NOT_CRAN=true` and `load_all`: 0 failed, 0 errors, 0 skips (49, 122, 116, 196 and 118 expectations). The jsonvalidate item test ran.
- `Rscript data-raw/receipt_vectors.R` regenerated every vector file, `stac.json` included, byte for byte (`git status` clean afterwards).
- Python cross-check (`uv run python -I ...crosscheck.py`): `vectors/v1.0.0` passed (2637/10/7/13 cases) and `mapping/v1.1.0` passed (13 cases), so `parse_int=float` did not disturb the hashing vectors. A copy of `stac.json` with one `file:size` changed by +1 was reported as 1 mismatch.
- The vignette, purled and sourced: the new chunks run, and the receipt asset's checksum is `1220` followed by the digest the writer returned.
- `pkgdown::check_pkgdown()`: no problems found. The released v1.0.0 files (vectors, register, mapping) are untouched by the diff. The inst and pkgdown copies of mapping v1.1.0 are the same blob (e672e12). Migration skips the `STAC item` rows (`R/crt_receipt_migrate.R:55,71`), so the CHANGELOG's "a migration under v1.1.0 holds what it held under v1.0.0" holds by construction.
- Note: to run the generator I also ran `R CMD INSTALL` from the worktree, so the R library's installed `crate` is now this branch's HEAD (ada0d16).

## Findings

- **[severity: fragile]** data-raw/receipt_vectors_crosscheck.py:466 (`SHA256 = re.compile(r"^[0-9a-f]{64}$")`, used through `.match`) and `stac_fields()` at :473–505. The script is described as "a reference for stacs' `stacs.receipt`", and R's roxygen (`R/crt_receipt_stac.R:101-102`) says every implementation runs `stac.json`, "so two of them agree on every item". Two things break that, and no vector can catch either:
  1. In Python, `$` also matches just before a trailing newline. So `SHA256.match("a"*64 + "\n")` is True, and the script would publish `file:checksum: "1220<hex>\n"`. R's `grepl()` refuses the same input (I checked: `crt_receipt_stac(wc, receipt_asset = "r", receipt_sha256 = paste0(d, "\n"))` errors), and so does the schema's ECMAScript pattern. Use `SHA256.fullmatch` (or `\Z`).
  2. R refuses a receipt whose published fields are malformed: a `recipe_id` that is not a SHA-256, a `context.time` that is not UTC ISO 8601, a non-string or empty `version`, fractional `bytes`, or a part `sha256` that is not hex. The Python reading mirrors all of these unchecked. The five refusal codes in `stac.json` cover only argument errors, and every case's receipt is valid. So an implementation written from this reference passes all 13 vectors and still publishes, for example, `receipt:recipe_id: "abc"` or `file:checksum: "1220zz"`, both of which R refuses.

  The fix is either to narrow the "agree on every item" claim to valid receipts, or to add refusal codes for invalid field values to `stac.json` (a new mapping version once released; v1.1.0 is not tagged yet) and implement them in the cross-check.
  - **Rule:** code-check.md "A fixture that cannot reach the failure mode"

Nothing else found. `crt_receipt_write()` hashes the temporary file before the rename and returns that digest. The empty `receipt_key` row is confined to the `STAC item` rows that migration skips, and the migrate test pins it as the only empty one. `stac_extensions` serializes as `[]` when empty and `assets`/`properties` as `{}`. The R function reads every field with `[[`, and its NA/empty guards on `assets` names, hrefs and `version` are correct.
