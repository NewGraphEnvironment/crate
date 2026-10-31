# Code check, round 3 (branch diff vs merge-base, planning/ excluded)

## Checklist read

- code-check.md: index read (37 headings). Full prose of all 14 H3s under `## Mechanisms` read
  (table rows skipped). Also read in full: "An assertion that matches an interpolated value cannot
  see the claim around it", "A pluralisation marker takes the quantity of whatever was substituted
  last", "Bare `y`, `n`... booleans in YAML 1.1" (index line). 20 stand-alone/security/spreadsheet
  headings not read in full (no git/infra/secret/PDF/URL/dry-run shape in the diff).
- code-check-r.md: index read (115 headings). Read in full: "A `data-raw/` script must load the
  source tree", "`$` on a list partial-matches", "as.POSIXct on a Date...", "as.POSIXct on character
  infers ONE format", "Under `R CMD check`, tests run ... INSTALLED package", "CSV whitespace:
  `trim_ws`...", "`cli` reads `{.name}` as a STYLE", "`[[` on a named ATOMIC vector", "A `pkg::`
  call in a test ... undeclared". 106 not read in full (index lines checked; no matching tool or
  shape in the diff).
- code-check-shell.md: index read (70 headings); 0 read in full (diff has no shell).
- code-check-spatial.md: index read (94 headings); 0 read in full (diff has no spatial code).

## Mechanism

The mapping from "what a cell in a real file holds" to "what the canonical column holds" is spread
across hand-maintained lists that agree only because one person wrote them together: the YAML
variant `cols`, the handler's `switch` ids and rename tables, the schema's canonical names and
`type`s, the fixture headers, and the real-data script's pins and expected counts. R2 closed the
**name** axis (a source column the rename does not map now aborts, and a test walks every YAML
variant through it). The same assumption recurs one axis over, on **values**: the canonical `type`
is assumed to match what a hand-typed cell holds. Only `date` got an abort for a cell that does not
fit; every other typed column goes through readr's type guess and then `crt_schema_apply()`'s
`suppressWarnings(as.integer/as.double)` / `as.logical`, which turn a non-conforming cell into NA
(or, through readr's `number` guess, into a different number) with no signal.

Reach, and whether something now checks it:

| place | checked? |
|---|---|
| YAML variant `cols` <-> rename tables (names) | checked: unmapped abort + YAML-walk test; mutation-tested (dropping the `haul_pass` rename reddens 3 tests; disabling the abort reddens the direct test) |
| YAML variant ids <-> handler `switch` ids | checked: YAML-walk test aborts on an id with no branch |
| rename target <-> the *right* canonical column (e.g. `length`->`length_mm` not `weight_g`) | checked by value tests on the 2024 and 2023-skeena fixtures |
| schema canonical names <-> handler output | by construction (fill reads the schema); `canonical_nge_fish()` in the tests reads the same YAML, so those `names()` assertions cannot fail except through the abort |
| fixture headers <-> YAML variant `cols` | checked in CI via `crt_ingest()` setequal match; exact order only in the data-raw script (not CI) |
| registry `canonical_cols` <-> YAML | checked: registry-integrity subset test |
| canonical `type` <-> cell values (numeric / integer / logical) | **unchecked** — Finding 1 |
| `date` cell <-> ISO day | checked by the day abort, but only for values readr leaves as text or as POSIXct; a bad value past readr's 1000-row guess window is NA before the abort sees it (Finding 1) |
| 2023 `pit_tag_id` (upper-cased, strict form) <-> 2024+ `pit_tag_id` (as recorded) | unchecked; measured consistent today (0 of 240 2024/25 tags off the strict upper form). A lower-case tag in a future field sheet would silently miss a recapture against 2023. Not filed as a finding |
| real-data script SHAs <-> YAML `first_seen`/`last_seen` | unchecked duplicate; all four agree today |
| decision-doc numbers <-> script asserts | 228/211 asserted; 188, 50, 29 cols, "17 tags seen twice" not asserted. All four re-measured correct today |
| `comments` "kept as recorded" | readr's default `trim_ws` strips trailing spaces (189 rows in 2024, 51 in 2025, measured); the test compares against a readr read, so it cannot see it. Whitespace only; not filed |

## Findings

- **[severity: fragile]** R/crt_handler_nge_fish_data.R (no value check on typed columns) via
  R/crt_schema_apply.R:70-73, and data-raw/fish_data_check-real.R:46-53 (checks only the time
  columns) — a hand-typed cell that does not fit its canonical type is lost or changed with no
  error and, in two of three routes, no warning. Measured through `crt_ingest()` on the 2024
  fixture with one cell edited each:
  - `length` `201mm`, `pass_number` `1b` → readr reads the column as character → conform gives
    `length_mm` NA, `haul_number_pass_number` NA, **0 warnings**. Same for a 2023 `length_mm` of
    `48 est`.
  - `alive` `Y` → `as.logical("Y")` is NA, **0 warnings**.
  - `weight` `92,4` (decimal comma) → readr guesses `number` and returns **924**, 0 warnings.
  - In a file over 1000 rows, a bad cell after row 1000 (`date` `6/9/2024`, `length` `12O`,
    `alive` `Y`) becomes NA with only readr's generic "One or more parsing issues" warning — and the
    same `6/9/2024` in a short file aborts with "not a day". So the day abort's "abort rather than
    drop" holds only within readr's guess window.
  This is the R2 defect (a canonical column silently NA where the source had a value) on the value
  axis instead of the name axis. No real file is affected today: all four pinned files have 0
  non-plain values in their numeric/logical columns and 0 values lost through conform (measured).
  It matters because this is the first `file` entry over hand-typed field sheets, and the next
  season's file is exactly where `12O` and `92,4` occur. A cheap guard: read the CSV with
  `col_types = cols(.default = "c")` (or compare against a character read) and abort on any
  non-empty raw cell that is NA after conform, naming column and value.
  - **Rule:** code-check.md, "A guard that fails toward pass" ("watch your own coercions invent
    one, since `as.integer("0.9")` is `0` with no warning")
