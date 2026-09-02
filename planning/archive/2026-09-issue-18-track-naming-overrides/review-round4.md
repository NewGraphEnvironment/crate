# Code-check round 4 — Phase 3 staged diff (decision entry, README, NEWS, CLAUDE.md, schemas README, YAML decision refs)

Scope: `git diff --cached` at `phase3.diff`. Checklist: `soul/conventions/code-check.md`,
every section applicable to prose + YAML data files (no shell, no infra in the diff).
Verified against `R/crt_schema_{validate,apply,conform}.R`, both track YAMLs, the
registry, `DESCRIPTION`, `test-crt_schema_conform.R`, `test-crt_registry_integrity.R`,
and read-only against trap (`trp_track_annotate.R`, `trp_track_read.R`,
`trp_track_read_gpx.R`, `DESCRIPTION`, `test-trp_track_annotate.R`,
`test-trp_track_read_gpx.R`, `data-raw/track_hornby_2026.R`) and rfp
(`inst/lookups/rfp_tracking_fields.csv`, `R/rfp_tracking.R`, `R/rfp_gpx_import.R`).

## Findings

No bug, security or data-loss issue. Three prose-precision items, all low:

- **[fragile]** `decisions/nge/20260902_track_naming_captured_and_overridden.md:17-18`,
  `README.md:122`, `NEWS.md:6` — the override rule is restated **unqualified**
  ("an annotation column sharing a captured column's name is an override of it")
  in all three summaries, while the contract it summarises
  (`track_annotations.yaml:16-19`) and the parity test
  (`test-crt_schema_conform.R:262-268`) both carve out `project`, `session_id`
  and `time_start_m`, which also share names with `track_sessions`. Round 2
  flagged exactly this over-breadth in the YAML and it was fixed there; the
  Decision section — the durable normative statement a future reader goes to —
  now carries the pre-fix wording. A reader implementing literally from the
  decision entry would coalesce the fingerprint. One clause ("a non-key
  annotation column…") in the decision's Decision paragraph closes it; README
  and NEWS are summaries and can stay as they are if the decision is precise.
- **[fragile]** `decisions/nge/20260902_track_naming_captured_and_overridden.md:41-42`
  — the quoted premise "the capture shape is fixed by the plugin and cannot be
  extended" appears verbatim in neither the 2026-08-24 decision nor trap.
  Grepped both: the 08-24 entry says "The capture shape is owned upstream and
  cannot be changed" / "A name cannot come from capture"; trap's roxygen says
  "The capture schema is fixed by the tracking plugin". Same meaning, but it is
  presented as a quotation of a specific document a reader will go and grep.
  Drop the quotation marks or quote the real sentence.
- **[fragile]** `decisions/nge/20260902_track_naming_captured_and_overridden.md:74`
  — "the GPX reader never reads a track's `<name>`" is literally false:
  `trp_track_read_gpx.R:378,413,452` read `tracks$name` to label a track in
  warnings/aborts. It never *carries* the name into the canonical tables, which
  is the fact the blast-radius argument depends on, and that part is true.
  "never carries a track's `<name>` into the output" says what was meant.

## Verified, not flagged

- **Version / status claims.** `DESCRIPTION` is `0.3.0`; `NEWS.md` has a 0.3.0
  section dated 2026-09-01 and a development-version section above it. CLAUDE.md
  "v0.3.0 (2026-09-01); NEWS.md is current" is accurate. Registry has 5 rows:
  `bcfp` ×1 (`file`, handler present) and `nge` ×4 (`schema_only`, no handler) —
  matches "two source families… three GPS-track tables and the form_capture
  envelope". `crt_schema_read/apply/validate/conform` all exist in `R/`.
- **README `crt_files()` sample.** `crt_files()` returns `crt_registry_load()`
  unfiltered, so row order is registry order: bcfp, track_sessions,
  track_vertices, track_annotations, form_capture — matches the sample. 5 × 6
  (the sixth column is `canonical_cols`, truncated in the sample) is correct.
- **Schemas README claim "canonical_cols lists the schema's required columns"**
  — probed programmatically across all 5 registry rows: for every row the
  registry list is set-equal to the YAML's `required: true` columns
  (bcfp's 4 optional metadata cols and track_sessions' 4 naming cols are the
  only optional ones, and neither appears in the registry). The integrity test
  (`test-crt_registry_integrity.R:95-108`) asserts only registry ⊆ schema, as
  the README says.
- **Relative links.** Every relative link in `README.md`, both decision entries
  and `inst/extdata/schemas/README.md` resolves to a tracked file
  (`decisions/README.md`, `decisions/nge/20260901_form_capture_envelope.md`,
  `20260824…`, `20260902…`, registry CSV, bcfp YAML, bcfp handler, schemas
  README). The 08-24 entry's same-directory link to `20260902…` resolves.
  `NEWS.md` links the new decision by its `blob/main` GitHub URL; the file is
  staged (`A`), so the link is to a tracked artifact and resolves on merge.
- **YAML `decisions:` refs.** Both track YAMLs now reference
  `decisions/nge/20260902_track_naming_captured_and_overridden.md`, which
  exists at that path; the integrity test's decisions-exist check passes in
  the source tree.
- **Issue references.** crate#18 (open, this issue), rfp#186 (closed, "Add
  editable fields to the position tracking layer"), trap#14 (closed, "Move the
  tracking schema into crate; decide where annotations live"), crate#9,
  crate#4 — all exist with titles matching how they are cited.
- **Claims about trap, against its current source.** `trp_track_annotate()`
  assigns `sessions[[col]] <- annotations[[col]][idx]` for every non-key column
  (`:131-134`) — the assign-not-coalesce description is exact (accepted
  tradeoff, tracked in trap). `trp_annotations_empty()` derives columns from
  crate's YAML (`:165-176`). `trp_track_read()` builds exactly the eleven
  required columns (`:144-156`); `trp_track_read_gpx()` likewise (`:247-259`).
  `test-trp_track_read_gpx.R:383-386` asserts GPX and Mergin session names
  identical, as the decision says. trap pins `crate@v0.3.0`
  (`DESCRIPTION:38`), so "trap's crate pin moves past the release carrying
  this" is a correct consequence. `notes` is used in trap's `annotation_for()`
  fixture, the GPX annotate test fixture, the `trp_track_annotate()` example,
  and two hardcoded name vectors — "four fixture rows across two test files and
  one example" is a fair blast-radius count. `data-raw/track_hornby_2026.R`
  seeds `working.trp_track_annotations` only if absent and never writes it
  otherwise, consistent with "seeded empty and never written".
- **Claims about rfp.** `rfp_tracking_fields_add()` and
  `rfp_qgs_tracking_fields_add()` exist (`rfp_tracking.R:584`, `:690`). Shipped
  lookup: all four TEXT; `track_type` valuemap
  `day log|stream survey|bushwhack|access route|drive|other`, default
  `'day log'`; `named_by` default `@mergin_username`. Roxygen table
  (`rfp_tracking.R:529`) still says `reach walk, bushwhack, access route,
  drive, other` — the "roxygen disagrees with the shipped lookup" consequence is
  accurate. `rfp_gpx_import()` prefixes every track/waypoint name
  (`rfp_gpx_import.R:97`), so "rewrites every name it touches" holds.
- **Claims about crate internals.** `crt_schema_validate()` gates on
  `isTRUE(required)` per column with no grouping — "per-column with no
  all-or-none grouping" is exact. `crt_schema_apply()` skips absent columns
  (`:62`) — "does not invent an absent optional column; eleven vs fifteen" is
  exact. The `enum` slot is reserved in the validator's roxygen (`:20`) and not
  implemented. `crt_schema_conform()` sees a frame, not a variant.
- **Column-set claims.** README's `form_capture` bullet lists
  `project, form, record_id, source_version, schema_version, captured_at` —
  matches the registry row and the YAML's required set. `track_annotations`
  "drops `notes`": no `notes` column survives in any YAML `cols:` list; the
  only remaining mention is the prose explaining its removal.
- **Checklist items with no hit.** No shell, heredocs, paths, secrets, or
  generator side-effects in the diff. YAML 1.1 boolean trap: no new bare
  `y/n/on/off` keys (only the `decisions:` lines changed). "A link to a
  repo-hosted artifact must be tracked": all link targets are tracked or
  staged. Planning artifacts are additive records of prior rounds; nothing in
  them is load-bearing.

## Verdict

Clean of bugs. Three low-severity prose precision items above, the first of
which is worth a one-clause edit before merge because it is the normative
statement of the rule; the other two are wording.
