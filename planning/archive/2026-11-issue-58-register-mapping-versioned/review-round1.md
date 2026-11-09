# Code-check round 1: crate#58, branch diff (HEAD b3e51a2, three-dot against origin/main af8574b)

## Checklist read

- code-check-python.md: in full (no Python in the diff; nothing applies).
- code-check.md: read the prose of all 14 H3s under `## Mechanisms` (tables skipped). From "Rules that stand alone" applied by index line: "Documentation Staleness", "A link to a repo-hosted artifact must be *tracked*, not merely present". The other 25 stand-alone, security and spreadsheet headings were not read, because their index lines name no tool or shape in this diff.
- code-check-r.md: read 15 headings: "Read-back shape must match write-back shape", "A `data-raw/` script must load the source tree, not the installed package", "Tests that silently do not run", "A `skip_if_not()` skips only its own `test_that()` block", "`R CMD build` ships every top-level directory not in `.Rbuildignore`", "`$` on a list partial-matches, so a longer sibling key answers for a missing one", "`paste()` with a zero-length argument returns length ONE, not zero", "`identical()` on two reader results tests the reader, not the file", "CSV whitespace: `trim_ws` and `strip.white` do not do what the name suggests", "`sort()` and `order()` collate by `LC_COLLATE`, so a canonical form is locale-dependent", "`match()` treats NA as a matchable VALUE, so two unknowns join to each other", "Regenerated binaries churn git even when nothing changed", "`[[` on a named ATOMIC vector with an absent key is an error, not `NULL`", "Under `R CMD check`, tests run from a temp dir against the INSTALLED package", "A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared". The other 102 were not read.
- code-check-shell.md: checked the freeze-gate step against the index lines for git plumbing, `for x in $(cmd | grep … || true)`, `grep`, globs and `set -u`. No section read in full, because the step's shapes (assignment on its own line under `set -euo pipefail`, `|| true` on a grep of an already-assigned value) are the ones those rules prescribe. 0 of 70 read in full.
- code-check-spatial.md: none apply (no spatial code). 0 of 94 read.

## What was run (in a detached worktree, removed afterwards)

- `devtools::test(filter = "receipt")`: 67 tests, 0 failed, 0 errors, 0 skipped.
- `test-crt_receipt_schema.R` run as the pkgdown workflow runs it (`testthat::test_file()`, crate unattached, installed branch): 7 tests, 0 failed, 0 skipped.
- `data-raw/receipt_vectors.R` premise: after `devtools::load_all()`, `crate:::receipt_register_version()` returns the source tree's value. A mutated "9.9.9" in the worktree came back as 9.9.9, so `crate:::` in that script does not reach the installed copy.
- The new guards, each restored and shown to fire: a one-row edit to the published register.csv fails 1 test; deleting the `## mapping v1.0.0` changelog entry fails 1; "covers form v1.1.0" fails 2; counting a restated action as an override (`changed <- TRUE`) fails 2 in test-crt_receipt_compare.R.
- Grepped every tracked file outside planning/ for the old paths (`receipt/register.csv`, `receipt/mapping.csv`, `vectors/v1.0.0/compare.json`).

## Findings

- **[severity: fragile]** pkgdown/assets/stac/receipt/README.md:9: this README still says "crate's receipt mapping table (`inst/extdata/receipt/mapping.csv`) lists each pairing". The branch moved that file to `inst/extdata/receipt/mapping/v1.0.0/mapping.csv`, published at `receipt/mapping/v1.0.0/mapping.csv`. The README is live on gh-pages (`stac/receipt/README.md` is in the current gh-pages tree), and it is the only tracked pointer outside the released NEWS entry that still names the old path. So a STAC reader who follows it finds no file. The freeze gate does not cover this README (it is not under `v*/`), so it can be corrected in place.
  - **Rule:** code-check.md "Documentation Staleness"

Nothing else found. Checked and found sound:

- `receipt_register()` overrides. Duplicate keys cannot reach it, because yaml refuses a duplicate map key. NA is impossible, since `crt_receipt_keys()` validates every action and unknown fields abort first. The empty case is `setNames(character(), character())`, and the radix order is locale-free.
- The freeze-gate glob and regex keep `receipt/v*/schema.json` disjoint from `receipt/register/…` and `receipt/mapping/…`, and CHANGELOG.md is not frozen, which is correct for a changelog.
- The R-CMD-check skip count of nine (5 + 3 + 1) matches the three source-tree skips now in test-crt_receipt_schema.R.
- `crate:::` in tests follows the pattern main already uses.
