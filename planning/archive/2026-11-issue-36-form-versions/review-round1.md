# Code-check round 1 (#36): branch diff 3342381...71060b4

## Checklist read

- code-check-python.md: in full (nothing in it applies; the diff has no Python).
- code-check.md: all 14 `## Mechanisms` H3s (prose, tables and evidence blocks skipped), plus
  "Documentation Staleness". 23 headings not read.
- code-check-r.md: "A library call that dispatches on a global option is not a pure function";
  "Read-back shape must match write-back shape"; "`system2(stdout = TRUE)` warns on a non-zero exit
  instead of raising..."; "`$` on a list partial-matches..."; "A `data-raw/` script must load the
  source tree, not the installed package"; "`dbConnect(SQLite(), path)` CREATES the file...";
  "`sort()` and `order()` collate by `LC_COLLATE`...". 115 not read.
- code-check-spatial.md: "A GeoPackage is a SQLite database, and that leaks in three ways"; "The same
  leak reaches R and OGR SQL, and a GeoPackage's bytes are not its content". 92 not read.
- code-check-shell.md: none (the diff has no shell script; its `system2()` calls fall under
  code-check.md's "A wrapper's exit is not the work"). 72 not read.

Also run: both changed test files pass in a detached worktree at HEAD
(`test-crt_form_schemas.R` 202 pass, `test-crt_schema_meaning.R` 37 pass, 0 fail, 0 error);
`write` on an unchanged copy of the cache reproduces the committed fixtures and CSV byte for byte;
the committed text has no project name from the cache's `stems.txt` (the only hits are the five
form names), no private-repo issue numbers, no local path; every count in `research/form_versions.md` and the
decision entry matches the cache (84/12 sets, 185/174 grew versions, 274 rebuilt, 361 diff-checked,
575 files, 141 paths, 12 projects, per-season counts, 0.77 min overlap, all keys single INTEGER).
The cache was read only; the copy and worktree were removed after.

## Findings

- **[severity: bug]** data-raw/forms_read-history.R:358, :381-385, :229-230, :245 — an interrupted
  `read` lets `write` run on a partial history and silently drop variants. `failures.txt` is written
  only at the end of `read` (line 358), so after the first complete season a `read` that is killed
  or crashes after `walk.rds` is saved (line 304) leaves the previous run's empty `failures.txt`
  in place, and `write`'s only completeness gate (line 381) passes. `versions_table()` then turns
  every version whose `meta/<checksum>.rds` is missing into an NA row (line 230) and drops it
  (line 245) with no message. Those are exactly the new season's versions, the ones a "resumable"
  re-run is fetching. Reproduced on a copy of the cache: deleting the one meta file behind
  `capture-2023-06`'s growth, with the existing empty `failures.txt`, `write` exits 0 ("360 geodiff
  versions checked ... 0 disagree") and `forms_variants-measured.csv` loses the `form_pscis`
  `capture-2023-06` row; the derive would then drop a published variant from `form_pscis.yaml`.
  The geodiff count check catches a gap only where a later geodiff version in the same chain
  follows it, never at the end of a chain. Fix: remove `failures.txt` (or write an in-progress
  marker) at the start of `read_history()`, and in `write` refuse when any non-removed row of
  `walk.rds` lacks its meta, agent or raw file, checking completeness against the walk rather than
  trusting the failure ledger.
  - **Rule:** code-check.md "A guard that fails toward pass" ; code-check.md "Zero-length, empty, and unset are three different things"

- **[severity: fragile]** data-raw/forms_read-history.R:502-512 (and :65-72) — published variant ids
  are re-derived from scratch on every run, so the next season's re-run can rename or drop ids that
  this branch publishes. An id is `capture-<first month it grew>` plus a letter assigned in
  fingerprint order within its month, and only `capture-utm-columns-2025` is pinned (`kept_ids`).
  A newly visible project, or a newly found shape that first grew in an existing month, makes
  `capture-2023-06` become `capture-2023-06-a`/`-b`, shifts `capture-2023-08-b` to `-c` when a new
  fingerprint sorts between, and moves the month when an earlier growth turns up. A project leaving
  the account drops a variant outright (`capture-2023-06` rests on 1 version in 1 project). The
  script itself says ids are already carried by harvested tables (it pins the 2025 one for that
  reason), and `crt_schema_variant()` maps fingerprint to id, so a renamed id stops matching the
  value a stored row carries. The fixture test only catches the leftover old fixture, and its
  natural repair (delete the stale file) completes the rename. Fix: treat every id already in the
  form's `upstream_variants` as pinned (read them from the current YAML, as `kept_ids` does by hand
  for one), name only new fingerprints, and stop rather than drop when a listed fingerprint is no
  longer measured.
  - **Rule:** code-check.md "Written data outlives the fix"

- **[severity: fragile]** data-raw/forms_derive-schemas.R:141-144 — `month_name()` writes
  `format(as.Date(...), "%B %Y")` into the published YAML descriptions, and `%B` follows `LC_TIME`.
  The script's guard checks only that the session is UTF-8, so a session in another UTF-8 locale
  passes it and writes, for example, "septembre 2024" (checked: `LC_ALL=fr_FR.UTF-8` passes
  `l10n_info()[["UTF-8"]]` and formats `2024-09-01` as `septembre 2024`). That breaks the header's
  claim that a re-run at the same `rfp_sha` is byte-identical, and puts a non-English month into a
  public schema. Fix: use `month.name[as.integer(substr(ym, 6, 7))]`, or pin `LC_TIME` to `C` for
  the run.
  - **Rule:** code-check-r.md "A library call that dispatches on a global option is not a pure function"

- **[severity: fragile]** data-raw/forms_read-history.R:130 — `system2(py_bin, c(py_script,
  "changeset", "--project", p, "--version", v), ...)` passes the project name unquoted, and
  `system2()` pastes arguments into a shell command. None of today's 12 project names holds a
  shell-special character (checked), but a name with a space or `(` splits into extra arguments,
  so that project's records can never be read and `write` refuses indefinitely with an error that
  names the record, not the quoting. Fix: `shQuote(p)` (and `py_script`).
  - **Rule:** code-check.md "A wrapper's exit is not the work"

- **[severity: fragile]** inst/extdata/schemas/README.md:26-36 — the table of optional column keys,
  introduced as the keys `crt_schema_cols()` returns, does not list the new `variants` key, which the
  YAMLs now carry on 31 columns and `crt_schema_cols()` returns. For the repo's "readable without R"
  contract, this README is where a non-R reader (or a form builder written against the YAML)
  learns that such a column belongs only to earlier versions and should be left out of a new form;
  without it the column reads as an ordinary current one. One table row fixes it.
  - **Rule:** code-check.md "Documentation Staleness"
