## Outcome

The receipt register and mapping are now versioned on their own, separately from the receipt form. A receipt's `receipt_version` means its form only. Tying the register to that number would have made a one-row action change unreadable for every written receipt, because `crt_receipt_read()` reads only the current form. That was settled in discussion with the owner at the plan gate. `register.csv` and `mapping.csv` moved to `inst/extdata/receipt/{register,mapping}/v1.0.0/` and are published at the same paths under the site's `receipt/`, with a `CHANGELOG.md` stating the rules. `compare.json` moved beside the register because it tests the register's actions; it moved byte-identical, the one edit to a frozen vector directory. A comparison now carries `register` and `overrides` (each declared action, named by field), and `print()` names them. Reading older forms and recording the mapping version on a migrated receipt are the first form change and were filed as crate#62; the stacs re-vendor is stacs#15. What was learned: the branch review ran four rounds. Rounds 3 and 4 each found a defect inside the previous round's freezing guard, all from one mechanism: a reference or a population set by hand where the claim was written (pins in the same tree, "the latest tag", a hand list of parts). It ended with an enumeration: every way a frozen file can change, each with a guard and a failing mutation (findings.md). The design record is `research/provenance_receipt.md`.

## Measurement

- register.csv, mapping.csv and compare.json have one blob each from v0.12.0 to HEAD (`0c5b72f`, `8665711`, `45495a5`). These equal what stacs vendors, so register v1.0.0 and mapping v1.0.0 are the rows stacs already runs. All six released contract files have had one blob across all 19 tags, which is what makes a first-tag reference sound.
- Tests: devtools::test 1994, then 2004 pass after review fixes. R CMD check: 0 errors, 0 warnings, 0 notes, 9 skips (stac 5, receipt schema 3, registry 1), matching the R-CMD-check comment.
- Mutations (findings.md tables): Phase 3 published-file gate, 5 cases; Phase 2/3 tests, 10; round 2 guards, 7; release-tag check, 18 across rounds 3 and 4. Every tampering case failed, and every clean or by-design case passed.
- Plan review blocker reproduced, not assumed: running the schema test as the pkgdown step does (installed package, crate unattached) failed on bare internal calls.

## Owed

- Shared with #54 (PR #56), done by whichever merges second: README's pasted compare output gains `; register v1.0.0`, and the CLAUDE.md Status line keeps #58's register/mapping sentence (both PRs edit it)
- Confirm `receipt/register/v1.0.0/register.csv` and `receipt/mapping/v1.0.0/mapping.csv` are served and byte-identical once Pages deploys (a gh-pages commit is not yet a served page) — done 2026-11-09: both, and `receipt/CHANGELOG.md`, return 200 and byte-identical to `pkgdown/assets/receipt/` after the v0.15.0 deploy (gh-pages built from 60933ef)

Closed by: PR for #58 (branch 58-register-csv-and-mapping-csv-are-unversi)
