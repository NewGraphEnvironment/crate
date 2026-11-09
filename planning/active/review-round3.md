# Code-check round 3 (#58), branch at 1c3ff73

## Checklist read

- code-check-python.md: in full (no Python changed; `data-raw/receipt_vectors_crosscheck.py` checked, it reads only the four hashing files, so the move of `compare.json` does not reach it).
- code-check.md: the prose of all 14 H3s under `## Mechanisms`, tables skipped. Rules-that-stand-alone and Security were read only by index line, none applies beyond "Documentation Staleness" (checked by grep, below).
- code-check-r.md: read 4 headings in full: "A `data-raw/` script must load the source tree, not the installed package", "Tests that silently do not run", "Under `R CMD check`, tests run from a temp dir against the INSTALLED package", "A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared" (checked against DESCRIPTION: `digest` is in Imports). About 106 others read by index line only.
- code-check-shell.md: read by index only, about 75 headings. The workflow edits extend an existing loop and grep, and add no new shell shapes.
- code-check-spatial.md: none read in full (94 headings); nothing spatial in the diff.

## Mechanism behind rounds 1 and 2

Each claim's population was listed by hand where the claim was written, not taken from the population itself. Round 1: one moved path, restated in many documents, missed in one of them. Round 2: "a released version is never edited" named every released file, but its guard (the gh-pages gate) covered only the published ones, and the changelog test checked a narrower thing than its comment said.

Places this reaches in the branch, each checked:

| claim | population | guard | verdict |
|---|---|---|---|
| released never edited: schema.json, register.csv, mapping.csv | published and installed copies | gh-pages gate (reference: the earlier deploy) + published==installed test | holds (gate is live from the first deploy) |
| released never edited: compare.json + 4 hashing vectors | installed only, vendored by stacs at a tag | SHA pin whose reference is in the same tree | **finding 1** |
| generator never rewrites a released file | out_dir and register_dir | `write_vectors()` md5 refusal | holds; re-ran the generator in a worktree, tree stayed clean |
| each register version covers one form; current register covers current form | CHANGELOG entries vs published dirs | changelog test + register==schema_fields test | holds |
| "rows unchanged since v0.12.0" (CHANGELOG) | git tags | measured: register f60f171d…, mapping d71d34d1… at v0.12.0, v0.12.1, v0.13.0, v0.14.0, v0.14.1 and HEAD | true |
| SHA pins equal the released bytes | v0.14.1 tag | measured: all 5 vector SHAs match `git show v0.14.1:…` | true |
| "Nine" skips under R CMD check | skip calls | 5 + 3 (lines 45, 69, 97) + 1 | true |
| stale old paths (round 1 class) | `git grep` for `receipt/register.csv`, `receipt/mapping.csv`, `vectors/v1.0.0/compare` | only NEWS.md (history, correct) | clean |
| "stacs has a Python implementation … runs the same vectors" (README, vignette, CLAUDE.md) | stacs | stacs#12 closed 2026-11-09; `src/stacs/receipt.py` and `tests/test_receipt_vectors.py` on default branch | true |
| `crate:::` in data-raw after `load_all()` | dev vs installed namespace | probe: source constant set to 9.9.9 prints 9.9.9 with 0.14.1 installed | dev namespace, fine |

Test runs in a worktree at 1c3ff73 (`NOT_CRAN=true`, `load_all`): compare 196 pass, migrate 117, schema 52, vectors 95, all with 0 fail, 0 error, 0 skip.

## Findings

- **[severity: fragile]** tests/testthat/test-crt_receipt_vectors.R:58-77 — The round-2 fix pins each released file's SHA-256 in a literal kept in the same tree it checks, and it counts every file on disk as "released" (`expect_setequal(on_disk, names(released))`). So a released `compare.json` or hashing vector can be edited in the same commit as its pin, and CI stays green. Probe (worktree): I renamed one case in `register/v1.0.0/compare.json` and swapped in its new SHA. `test-crt_receipt_vectors.R` then reports 0 fail and 95 pass. No other guard reaches these five files: the gh-pages gate covers only published files, and the compare.json runner checks verdicts against current code, not the bytes. Two things make this the likely way the guard gets defeated. First, a mismatch reports only `info = f` and two hashes, and the obvious fix is to paste the new hash. Second, each new, unreleased version directory forces an edit to the pin list on every regeneration, so editing pins becomes routine. This is round 2's defect one axis over: the rule says a released file never changes, but nothing checks these five files against what was actually released. The other three frozen files are checked against an outside reference (the earlier gh-pages deploy). Here that reference exists too: stacs vendors at a crate tag, and all five pinned hashes equal `git show v0.14.1:inst/extdata/receipt/vectors/v1.0.0/<f>`. A workflow step that compares every `inst/extdata/receipt/{vectors,register,mapping}/v*/*` present at the latest tag (`git describe --tags --abbrev=0`) byte for byte, like the gh-pages loop, would make the claim hold. The pin could stay as the in-package backstop for R CMD check.
  - **Rule:** code-check.md "Verification that reads its own output" ; code-check.md "A guard's scope, escape hatches, and remedies"

Nothing else found. The `overrides` computation, print path, `receipt_contract_file()`, generator refusal, pkgdown gate globs and regex, published==installed test and changelog test each hold for the inputs I traced.
