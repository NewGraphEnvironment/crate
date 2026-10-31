# Review round 1: branch diff for #6 (nge/fish_data)

## Checklist read

All four indexes read in full.

- **code-check.md**: I read the prose of all 14 H3s under `## Mechanisms`: "A guard that fails toward pass", "A fixture that cannot reach the failure mode", "A proxy is not the property", "Verification that reads its own output", "A guard's scope, escape hatches, and remedies", "A fix lands in one of two callers that share a harness", "Restore the bug and prove the guard fires", "A shared working tree, and what generators leave in it", "A wrapper's exit is not the work", "Zero-length, empty, and unset are three different things", "The probe is broken before the world is", "Written data outlives the fix", "Serialization loses meaning silently", "One fact derived twice". I also read "Documentation Staleness" and "A pluralisation marker takes the quantity of whatever was substituted last". 21 of 37 H3s were not read.
- **code-check-r.md**: I read the full sections of 21 headings: "`download.file(quiet = TRUE)` never tells you the HTTP status", "A URL handed to a reader goes through R's 60 s connection timeout", "A `data-raw/` script must load the source tree, not the installed package", "Regenerated binaries churn git even when nothing changed", "Tests that silently do not run", "A `skip_if_not()` skips only its own `test_that()` block", "`expect_gt()` and friends take no `info` argument", "as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone", "as.POSIXct on character infers ONE format for the whole vector", "`nzchar(NA)` is TRUE", "Under `R CMD check`, tests run from a temp dir against the INSTALLED package", "CSV whitespace: `trim_ws` and `strip.white` do not do what the name suggests", "`match()` treats NA as a matchable VALUE", "`as.integer(\"NaN\")` is `0`", "`cli` reads `{.name}` as a STYLE", "`[[` on a named ATOMIC vector with an absent key is an error", "`tempfile()` lives in the session tempdir", "R's `yaml` returns a mixed int/float sequence as a list", "A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check`", "Inside a dplyr verb, a column named like a local variable wins", "`ifelse()` with an all-NA test returns a logical vector". 94 of 115 were not read.
- **code-check-spatial.md**: I read 2 sections: "An offset regex must be anchored to a time, or a date looks like a zone" and "A reader that accepts a UTC offset may not be applying it". 92 of 94 were not read.
- **code-check-shell.md**: none read in full, because the diff has no shell. 70 of 70 were not read.

## What was probed (in a copy, /private/tmp/.../scratchpad/r1/repo, never the checkout)

- **The four real files at their pinned SHAs, read through `crt_ingest()`.** For every raw column I compared the non-NA count before and after conform. No column lost a value. That covers integer coercion of `reference_number`, `haul_pass`/`pass_number`, `ef_seconds`, `voltage`, `frequency` and `row_id`; none of them holds a fractional value. It also covers hms becoming string, POSIXct `date` becoming ISO day, and numeric `wp_*` becoming string. No waypoint has a leading zero. Every 2024 and 2025 `pit_tag_id` is upper case with the `3DD.` prefix, so a cross-season join cannot miss on case. `alive` holds only TRUE, FALSE or blank.
- **`data-raw/fish_data_check-real.R`, run end to end.** Every `stopifnot` passes: 1359 rows, 228/211 for 2023, the four 2024→2025 recaptures, and no 2023 tag recurring.
- **`data-raw/example_fixtures_nge_fish_data.R`, run.** Every header matches its variant.
- **Grep of the raw 2023 comments for tag spellings the regex could miss** (a missing dot, a different prefix, two codes in one comment). The only one found is the documented partial `3DD.003E192B9I`.
- **The decision's claim that the 2024 file is byte-identical in the Peace and Skeena repos.** The md5 of the Peace 2024 `main` copy matches the pinned Skeena copy.
- **The date-abort messages, rendered at n=1 and n=2.** The pluralisation is correct.

## Clean

No issues found.

Non-blocking observations (no failure, recorded for the author):
- README.md, "What crate handles today", **`file`** list (around line 121): it still names only `bcfp/user_habitat_classification`. The new `nge/fish_data` `file` entry is not listed there, though the `crt_files()` output at the top of the README now shows it. Before this branch the section already omitted several `schema_only` entries, so it is not maintained as an exhaustive list. (code-check.md "Documentation Staleness")
- R/crt_handler_nge_fish_data.R:109: the time-of-day abort lists an `NA` when the column also holds missing days, for example `("03:00:00" and NA)`. This affects the message only; the abort still fires correctly.
