# Code-check round 2: crate#58 branch (three-dot against origin/main, planning/ excluded)

## Checklist read

- code-check-python.md: in full (no Python in the diff; nothing applies).
- code-check.md: every H3 under `## Mechanisms` read in prose (14), skipping table rows and evidence blocks. Of "Rules that stand alone" I read "Documentation Staleness" and "A link to a repo-hosted artifact must be *tracked*, not merely present". 20 other headings not read in full.
- code-check-r.md: read by index line, and in full where they touch this diff's shapes: "A `data-raw/` script must load the source tree, not the installed package", "`$` on a list partial-matches…", "`sort()` and `order()` collate by `LC_COLLATE`…", "Under `R CMD check`, tests run from a temp dir against the INSTALLED package", "A `pkg::` call in a test passes `devtools::test()`…", "`nzchar(NA)` is TRUE…", "`R CMD build` ships every top-level directory not in `.Rbuildignore`". About 125 others not read in full.
- code-check-shell.md: by index only, plus the sections on `set -e`, globs and the `grep -c` exit, checked against the freeze-gate step. About 120 others not read in full.
- code-check-spatial.md: by index; nothing in the diff is spatial. None read in full.

## How I checked it

- I ran `devtools::test(filter = "crt_receipt")` in a detached worktree at HEAD: all pass.
- I ran the freeze-gate `grep -E` against 8 paths it must match and must not match. It matches exactly the four contract files (`receipt/v*/schema.json`, `register/v*/register.csv`, `mapping/v*/mapping.csv`, `stac/*/v*/schema.json`). It does not match `receipt/CHANGELOG.md`, `register/v1.0.0/compare.json` or a nested `register/v1.0.0/x/register.csv`.
- gh-pages carries `.nojekyll`, so `receipt/CHANGELOG.md` and the CSVs are served raw. Every URL that README, the vignette, the roxygen, the register README and `pkgdown/assets/stac/receipt/README.md` (the 151f8ee fix) link to will exist once pkgdown copies `pkgdown/assets/receipt/**`. The "unexpected page" gate looks only at the top level of `docs/`, so `receipt/CHANGELOG.md` does not trip it.
- `git grep` over R/, tests/, data-raw/, vignettes/ and inst/ finds no reader of the old paths (`receipt/register.csv`, `receipt/mapping.csv`, `vectors/v1.0.0/compare.json`). The remaining one is NEWS.md's historical entry. `data-raw/receipt_vectors_crosscheck.py` does not touch `compare.json`. stacs's vendoring is tracked in stacs#15.
- I mutation-tested the changelog test in the worktree with `test_file` after `load_all`:
  - removing "It covers form v1.0.0." gives 3 failures;
  - a duplicate `## mapping v1.0.0` heading gives 0 failures;
  - "covers form v1.0.0 only." gives 1 failure.
- Skip count: test-crt_receipt_schema.R now has 3 source-tree skips (the old one plus 2 new). 5 + 3 + 1 = 9, so the workflow's "Nine" is right, and the reason strings are unchanged.

## Findings

- **[severity: fragile]** data-raw/receipt_vectors.R:247, :284 and pkgdown/assets/receipt/CHANGELOG.md:14, :26. The published rules say a released register version is never edited (CHANGELOG:14, register README:24), and that a code change which moves any expected value in a register version's `compare.json` is a new register version (CHANGELOG:26). Nothing enforces either rule, and the documented regeneration path breaks them.
  - `compare.json`'s expected `verdict` and `differences` are produced by `crt_receipt_compare()` itself (`pair()`, line 247).
  - The file is written into `register/v<receipt_register_version()>/`, which is the released v1.0.0 directory.
  - The freeze gate covers only `register.csv` and `mapping.csv`. `compare.json` is not published, and no test pins its bytes.
  - So when a code change moves a verdict, test-crt_receipt_vectors fails. Re-running `data-raw/receipt_vectors.R`, the script's stated way to regenerate, rewrites `register/v1.0.0/compare.json` in place, the suite turns green, and the frozen version stacs vendors has been edited.
  - The same holds for the hashing vectors in `vectors/v<form>/`, and for mapping transforms, which have no vectors at all. Those are older, but this branch is what now publishes the rule.
  - Possible fix: have `write_vectors()` refuse to overwrite an existing file whose bytes differ, or add a test pinning the SHA-256 of each released vector file. Either makes "a new version directory, never an edit" a check rather than a sentence.
  - **Rule:** code-check.md "Verification that reads its own output" ; code-check.md "A guard's scope, escape hatches, and remedies"

- **[severity: fragile]** tests/testthat/test-crt_receipt_schema.R:94, :112, :124. The test is named "the receipt changelog has one entry per published version", but it compares headings with `expect_setequal()`, which ignores duplicates. A second `## mapping v1.0.0 (...)` heading passed with 0 failures (measured). Only the current register's heading gets an `expect_length(h, 1L)`. Separately, line 124 needs a literal `.` right after the version (`"[.]"`). "It covers form v1.0.0 only." passes the per-entry `covers form v[0-9]+…` check at line ~115 but fails here (measured: 1 failure). So the final check refuses a correct entry on punctuation. Low impact both ways. Possible fix: also `expect_false(anyDuplicated(...) > 0)` on the parsed headings, and anchor the version with `\\b` or `(?![0-9])` instead of `[.]`.
  - **Rule:** code-check.md "A guard that fails toward pass"

## Considered and not reported

- `overrides` against what was actually applied. `receipt_register()` lists every field whose register action the declaration changed. The comparison code then decides some of those fields itself: `result.fingerprint.*.sha256` when tables are supplied, and parts or summary values settled as `within`. So a listed override may have had no effect on a given comparison, while the print line still counts it. The roxygen documents exactly this ("lists every such field, whether or not that field differed"), recipe fields cannot be overridden (`crt_receipt_keys()` refuses them), and duplicate YAML keys abort in `yaml::read_yaml`. The count can therefore not disagree with the register as applied. Not a defect.
- `crate:::` in data-raw after `devtools::load_all()` resolves to the dev namespace, so it is correct.
