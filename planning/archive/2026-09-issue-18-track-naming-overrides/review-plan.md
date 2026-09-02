# Plan review — crate#18 (Plan agent, 2026-09-02)

Findings relayed from the reviewer's reply (Plan agents cannot write files).
Disposition in brackets.

## Blockers

- **B1** "Absent columns conform to NA" is false: `crt_schema_apply()` skips absent
  columns (`R/crt_schema_apply.R:62`), so a plugin-shape frame conforms to eleven
  columns. Consequence: two conformed frames from different variants have different
  column sets, and trap's `test-trp_track_read_gpx.R:383-386` asserts GPX and Mergin
  session names identical. The *reader* must always emit all four, NA-filled.
  [Fixed in YAML wording and test before the review landed; trap issue and decision
  entry updated to say "always emit all four"; alternative `required: true` +
  reader-side fill recorded and rejected.]
- **B2** A temp schema copy is unreachable through `crt_schema_conform()`
  (`system.file()` resolution). Flip `required` in memory and call
  `crt_schema_validate()` directly, with a premise assertion. [Already done that way.]

## Gaps

- **G1** trap pins `crate@v0.3.0` (`trap/DESCRIPTION:38`), so nothing breaks until
  the pin bumps; the trap issue must enumerate: `annotation_for()` fixture (13 tests),
  `test-trp_track_read_gpx.R:392-398`, the `trp_track_annotate()` example,
  `test-trp_track_annotate.R:142-149` hardcoding `notes`, `test-trp_track_read.R:17-21`
  pinning eleven names, `data-raw/track_hornby_2026.R:143-145` comment. Crate needs a
  tag for trap to pin. [Folded into the trap issue; release via `/gh-pr-merge`.]
- **G2** Override-parity test shape: every annotation non-key column must have a
  captured twin of the same type; `named_by` must not be an override. Restore-the-bug
  by renaming, retyping, or re-adding `notes`. [Adopted verbatim.]
- **G3** `NA` = no override means a captured value cannot be overridden *to* blank;
  and `""` is not `NA` — a cleared QGIS widget writes `""`. [Decision + YAML: readers
  normalise `""` to `NA` before coalescing; override-to-blank unsupported, stated.]
- **G4** Partial-set rule is unenforceable in crate (validate is per-column). Define
  "partial" as columns present, not values. [Decision entry.]
- **G5** README `crt_files()` sample output and the `schema_only` list omit
  `form_capture`. [Fixed while editing that section.]
- **G6** "Registry lists required columns only" is inferred from bcfp, not written.
  [Written into `inst/extdata/schemas/README.md`.]

## Ordering

- **O1** Decision reference in YAML before the file exists reddens the integrity
  test. [Hit and handled: reference moves to Phase 3 commit.]
- **O2** Annotations YAML + registry row + test land in one commit. [Yes.]
- **O3** Release step. [`/gh-pr-merge` bookkeeping.]

## Assumptions

- **A1** `named_by == tracked_by` by default is asserted via rfp's CSV `why` column
  and roxygen (`@mergin_username` for both), not measured on data. [YAML rephrased:
  defaults to the same account variable the plugin stamps `tracked_by` with.]
- **A2** `required: true` on override columns means presence-not-value; asymmetry with
  the captured side is deliberate. [Recorded in decision entry.]
- **A3** Issue body's `track_type` table is stale. [Fixed in the #18 body rewrite.]

## Acceptance

- **Ac1** Assert a plugin-shape frame returns exactly its input columns. [Added.]
- **Ac2** Decision Consequences: crate cannot enforce partial-set; no override-to-blank;
  fingerprint still required on the override path. [Added.]
