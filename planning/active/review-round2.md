# Code check, round 2: branch diff for #6 (nge/fish_data)

## Checklist read

- **code-check.md:** I read all 37 index headings. I read the prose of all 14 H3s under `## Mechanisms`, with the table rows skipped. I also read in full "An assertion that matches an interpolated value cannot see the claim around it" and "Documentation Staleness". Not read in full: the other 21 standalone, security and spreadsheet headings, because no tool or pattern they name appears in this diff.
- **code-check-r.md:** I read all 115 index headings. I read these 14 sections in full:
  - "A `data-raw/` script must load the source tree, not the installed package"
  - "Tests that silently do not run"
  - "Under `R CMD check`, tests run from a temp dir against the INSTALLED package"
  - "`nzchar(NA)` is TRUE — non-empty checks silently pass NA"
  - "CSV whitespace: `trim_ws` and `strip.white` do not do what the name suggests"
  - "Cross-function consistency for label/string normalization"
  - "A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared"
  - "`match()` treats NA as a matchable VALUE, so two unknowns join to each other"
  - "Inside a dplyr verb, a column named like a local variable wins"
  - "`[[` on a named ATOMIC vector with an absent key is an error, not `NULL`"
  - "`$` on a list partial-matches, so a longer sibling key answers for a missing one"
  - "A URL handed to a reader goes through R's 60 s connection timeout"
  - "`download.file(quiet = TRUE)` never tells you the HTTP status — read it from `curl`"
  - "`expect_false(identical(x, y))` cannot fail when the two are different types"

  101 not read in full.
- **code-check-shell.md:** I read all 70 index headings and none in full (70 not read). The diff has no shell code.
- **code-check-spatial.md:** I read all 94 index headings and none in full (94 not read). The diff has no spatial code.

## Method

- **Real data.** I copied the repo to the scratchpad and fetched the four pinned real files. `data-raw/fish_data_check-real.R` passes (exit 0).
- **Value loss.** I compared each real file's raw text, read with `col_types = "c"`, against the `crt_ingest()` output:
  - No values were lost in coercion.
  - No integer column held a non-integer value.
  - Every time of day was already `HH:MM:SS`.
  - Every `date` stamp is midnight (674/674 in 2024, 97/97 in 2025).
- **Claims.** These all reproduce:
  - 228 tagged rows and 211 tags in 2023; 188 tags in 2024 and 50 in 2025.
  - 17 tags in 2023 are seen exactly twice (194 once, 17 twice).
  - One partial code, `3DD.003E192B9I`.
  - The four 2024→2025 recaptures, and no 2023 tag recurs in a later season.
  - The species spellings match those quoted.
  - `row_id` is non-null exactly where `pit_tag_id` is non-null.
  - The 2024 file in the Peace 2024 repo (main) is byte-identical to the Skeena copy.
  - There are 29 canonical columns and 28 columns in the 2024 shape.
- **Mutations.** I patched the copy, ran both test files with `test_file()`, and counted `failed > 0 | error`:

| mutation | red blocks |
|---|---|
| baseline | 0 / 19 |
| drop the `(?<![0-9A-Fa-f])` lookbehind | **0 / 19** |
| drop the `(?![0-9A-Fa-f])` lookahead | 1 (tag extraction) |
| drop `ignore.case = TRUE` | 1 (tag extraction) |
| drop the 2024 `pass_number` rename | **0 / 19** |

## Findings

- **[severity: fragile]** R/crt_handler_nge_fish_data.R:56-62 (`crt_handler_nge_fish_fill`), with the renames at lines 43-47 and 34-35.
  - **What happens.** `df[, cols, drop = FALSE]` silently drops any column the rename step did not map, and the fill puts an all-NA canonical column in its place. So a rename that falls out of step with a variant's `cols` loses that column's data with no error.
  - **Why the required check cannot catch it.** The fill guarantees that `local_name` and `species` are present, so `crt_schema_validate()`'s check of the registry's required columns can never fire for this entry.
  - **Measured.**
    - With the `pass_number = "haul_number_pass_number"` entry removed, all 19 test blocks stay green. The real 2024 file then ingests with 0/674 pass values.
    - With the `common_name` → `species` rename removed, the real Skeena 2023 file ingests with `species` NA on all 417 rows and no error, although `species` is required.
  - **Answer to the brief.** "Extra columns cannot occur" holds only while the rename tables match the YAML variants, and nothing checks that they do.
  - **Fix.** In the fill, abort when `setdiff(names(df), cols)` is non-empty. The 2024 test should also assert `haul_number_pass_number`, which no test reads for that shape.
  - **Rule:** code-check.md "A guard that fails toward pass"
- **[severity: fragile]** tests/testthat/test-crt_handler_nge_fish_data.R:93-112 tests the regex at R/crt_handler_nge_fish_data.R:72.
  - **What happens.** Deleting the leading hex boundary `(?<![0-9A-Fa-f])` leaves the suite green. No test input has a hex character directly before `3DD` (for example `A3DD.003E192B88`), which would then read as a valid tag.
  - **What is covered.** The trailing boundary (`3DD.003E192B88A`), case-insensitivity (`3dd.003e…`), `toupper()` and `unique()` each turn the test red.
  - **Impact.** None in the current real data: no 2023 comment has a hex character before `3DD`. So this is a gap in the tests, not a wrong result today.
  - **Rule:** code-check.md "Restore the bug and prove the guard fires"
- **[severity: fragile, prose]** decisions/nge/20261031_fish_data_canonical.md:51-53 and R/crt_handler_nge_fish_data.R:5-7.
  - **The claim.** The null fill is justified by saying that without it "seasons would not bind" (the roxygen says the fill "is what lets seasons be stacked with `dplyr::bind_rows()`").
  - **Measured.** Without the fill, the conformed 2023 and 2024 outputs bind with `dplyr::bind_rows()` to 8 × 29 with no error, because `bind_rows()` fills missing columns itself. Only `rbind()`, which the `crt_ingest()` example uses, needs the full set.
  - **Fix.** The claim about a second function's behaviour is false as written. Restate it as a fixed column set per file, or name `rbind()`.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies"

No security issues. Every other quantified or factual claim I checked in the schema YAML, the decision entry, the README, CLAUDE.md and the fixture-script header holds against the code and the real data.
