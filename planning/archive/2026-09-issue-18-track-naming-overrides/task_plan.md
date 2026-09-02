# Task: nge/track_sessions drops the four crew-supplied naming columns an rfp-deployed tracking layer carries (#18)

`nge/track_sessions` declares eleven columns. A Mergin Maps position-tracking
layer deployed through `rfp` carries **four more** — `track_name`, `track_type`,
`track_description`, `named_by` — and a reader that conforms to the canonical
schema drops all four silently. These are not drift: rfp adds them deliberately so
a crew can name a session at the time they walk it. Measured on a real field
project: four sessions, three carrying a crew-supplied name, all four a
`track_type` and a `named_by`; `trp_track_read()` returned the canonical eleven
and none of the four. The schema is what is out of date.

**Decisions taken with the user (2026-09-02):**

1. Annotations mirror captured columns as overrides: `track_annotations` carries
   `track_name`, `track_type`, `track_description` and drops `notes`. Rule: an
   annotation column sharing a captured column's name overrides it where non-`NA`;
   the read resolves `coalesce(annotation, captured)`.
2. `track_type` stays an open string; rfp's value map is the convention, not enforced.
3. Missing-set reporting is out of scope; a *partial* set is drift the reader aborts on.
4. The early-stage design principle (reshape rather than accrete) lands in `CLAUDE.md`.

## Phase 1: Declare the four captured columns in `nge/track_sessions`

- [x] `inst/extdata/schemas/nge/track_sessions.yaml`: add `track_name`, `track_type`,
      `track_description`, `named_by` to `canonical.cols`, all `type: string`,
      `required: false`. Notes say: written at capture by the person who walked it,
      immutable after, `NA` where the capture source has no such column;
      `track_type` is an open string whose value list is rfp's convention (record the
      current six values and the `day log` default); `named_by` defaults to the
      capturing account, so it equals `tracked_by` unless someone changed it.
- [x] Same file: add upstream variant `mergin-tracking-rfp-2026-08` — the plugin's
      layer with the four columns appended by `rfp::rfp_tracking_fields_add()` and
      widgets from `rfp::rfp_qgs_tracking_fields_add()`; `cols` = plugin's six + the
      four; note rfp's safety argument is asserted against the installed plugin's
      source, and that rfp's lookup CSV, not its roxygen, is the value-map authority.
- [x] Same file: correct the `mergin-tracking-plugin-2026-08` variant — remove "the
      capture shape is fixed by the plugin and cannot be extended, which is why a
      human-supplied name cannot live in it"; state the four are absent (conform
      leaves them absent; the reader yields `NA`), and that a layer carrying *some* of
      the four is drift the reader must abort on.
- [x] Same file: refresh `description` (naming can now come from capture; annotations
      override it). The `decisions:` reference to the new entry moves to Phase 3 so
      this commit stays green — the integrity test asserts every referenced entry exists.
- [x] `tests/testthat/test-crt_schema_conform.R`: a sessions frame carrying the four
      conforms with them typed `character`; the plugin-shape frame (no four) still
      conforms. Restore-the-bug check done against the parsed schema handed to
      `crt_schema_validate()` directly (a temp file is unreachable through
      `system.file()`): premise asserted (all four `required: false`), then one flipped
      to `TRUE` aborts naming `track_name`.
- [x] Registry row for `track_sessions` left as-is (lists required columns only, per
      the bcfp precedent and the integrity test's stated contract).

## Phase 2: Reshape `nge/track_annotations` into override columns

- [x] `inst/extdata/schemas/nge/track_annotations.yaml`: replace `track_name` +
      `notes` with `track_name`, `track_type`, `track_description` (`string`,
      `required: true` — the table is ours, so its shape is fixed; values may be `NA`).
- [x] Same file: rewrite `description` — the override rule (same name as a captured
      column = override where non-`NA`; read resolves `coalesce(annotation, captured)`);
      why the table still exists (corrections to what was typed in the field, and
      sources with no captured naming: plugin-only layers, GPX); remove "capture
      schemas are fixed by the tool that writes them, so a name cannot come from
      capture". Plan review G3 added: `""` normalises to `NA` before coalescing, and
      there is no override *to* blank.
- [x] Same file: `forward_compat` keeps `annotated_by` / `annotated_at` /
      `review_status`; add a note that `named_by` is deliberately not mirrored — its
      override-side twin is `annotated_by`.
- [x] `inst/extdata/crate_registry.csv`: `track_annotations` row `canonical_cols`
      becomes `project,session_id,time_start_m,track_name,track_type,track_description`
      (same commit as the YAML, or the integrity test fails).
- [x] `tests/testthat/test-crt_schema_conform.R`: annotations test uses the new three
      columns; a frame missing an override column is refused naming both; parity test
      in the plan reviewer's shape (every non-key annotation column has a captured
      twin of the same type; `named_by` is not an override). Restore-the-bug: renaming
      `track_type` in one YAML fails it at the setdiff and identical assertions.
      Phases 1 and 2 land in one commit because they share this test file.

## Phase 3: Decision entry, README, NEWS, CLAUDE.md

- [x] `decisions/nge/20260902_track_naming_captured_and_overridden.md` in the
      README's format: Decision; Trigger (rfp#186, four sessions measured, three named);
      Rationale (captured beats annotated for anything sayable at walk time; override
      rule; open-string `track_type`; partial set = drift); Alternatives (rename the
      annotation column; drop annotation `track_name`; crate-owned enum; variant-aware
      conform now); Consequences (trap coalesce; GPX all-`NA`; reader aborts on partial
      set; `working.trp_track_annotations` reseed); References. Plan review added:
      reader always emits all four (B1), `required` on the override side is presence
      not value (A2), `""` is `NA` / no override-to-blank (G3), partial means columns
      present not values and crate cannot enforce it (G4), fingerprint stays (Ac2).
- [x] `decisions/nge/20260824_track_canonical_two_tables.md`: one line under the title
      pointing at the new entry as amending the "Annotations separate" premise. Body
      untouched.
- [x] `README.md` "What crate handles today": `track_sessions` bullet mentions the
      crew-supplied naming columns; `track_annotations` bullet becomes the override
      table; both link the new decision entry. Also (G5) the `crt_files()` sample
      output and the `schema_only` list gain `form_capture`, which they had missed.
- [x] `NEWS.md` development-version entry.
- [x] `CLAUDE.md` project section (above the soul marker): add the early-stage design
      principle from the user; refresh the stale Status paragraph (still said v0.0.2 and
      one source family).
- [x] `inst/extdata/schemas/README.md` (G6): the registry's `canonical_cols` lists
      required columns only — written down rather than inferred from bcfp.
- [x] Both track YAMLs reference the new decision entry (deferred from Phase 1 so
      that commit stayed green).

## Phase 4: Cross-repo follow-ups (file, do not fix here)

- [x] trap issue: `trp_track_annotate()` must coalesce (currently overwrites captured
      values with `NA` for unannotated sessions); both readers always emit the four,
      `NA`-filled (plan review B1); the Mergin reader aborts on a partial set; fixtures
      and the example move off `notes`; `working.trp_track_annotations` (empty)
      reseeded; crate pin bumped (G1). Filed as
      [trap#28](https://github.com/NewGraphEnvironment/trap/issues/28) with the full
      breakage inventory.
- [x] rfp issue: roxygen table in `rfp_tracking_fields_add()` disagrees with the
      shipped lookup (`reach walk…` vs `day log…`; `track_description` missing). Filed
      as [rfp#255](https://github.com/NewGraphEnvironment/rfp/issues/255).
- [x] crate#18 body: rewritten — stale `track_type` table corrected (A3), the three
      "Open" items replaced by a "Decided" section, follow-ups linked.

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
