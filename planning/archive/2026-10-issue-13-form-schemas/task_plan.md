# Task: Canonical schemas for field forms: vintage in columns, not filenames (#13)

## Problem

Field forms change shape between sessions, and there is no canonical schema that makes two vintages
of the same form the same logical table.

A concrete case: a vegetation-inventory QA form was captured with **28** non-geometry columns in one
session, and the form then in use carried **52**. Audit-provenance fields were added mid-season after
the first session showed the original form could not answer the question it was built for. Both
vintages are real data about the same thing. Neither is wrong.

Today vintage is carried in **filenames** (`form_<type>_<year>.gpkg`), which fails three ways:

1. "Every record ever collected with this form" is a glob-and-rbind rather than a query.
2. Two sessions in one calendar year with different schemas have nowhere to go. The year-stamped
   name is already taken, and the two column sets will not stack.
3. A null is uninterpretable. There is no way to tell *the observer left it blank* from *the form
   did not have that field yet*.

This is the same class as #6 (reconciling older column names to canonical), and it is what the
`track_sessions` schema already states as a design principle:

> "Canonical shape is deliberately not tied to any one capture tool ... so that a track recorded
> years earlier as a GPX file is the same canonical thing as one captured by a mobile plugin today,
> and fits this schema without a rename."


## Context

Field forms change shape between sessions and nothing makes two vintages of one form the same
logical table. `nge/form_capture` (#14) shipped the envelope (`project, form, record_id,
source_version, schema_version, captured_at`) and deliberately said nothing about what form columns
mean. This issue registers per-form schemas for the fish passage family — `pscis`, `fiss_site`,
`monitoring_fish_passage`, `monitoring_general`, `monitoring` — whose 2026 season is about to be
harvested (trap's 2026 harvest issue), and which rfp's form builder is blocked on ("read the schema from crate").

### What exploration found (2026-10-30, crate at 1b8837f, rfp at a901caaa)

- **rfp field CSVs** (`inst/extdata/forms/schema/{pscis,fiss_site,monitoring_fish_passage,monitoring_general}.csv`)
  match their shipped GPKG column sets exactly (99 / 149 / 35 / 50). `monitoring` has **no CSV**,
  only a captured QML + GPKG (124 cols). Meaning columns: `field, type, help`, units (in `label`
  parentheses, per rfp's README), vocabulary in `options` (valuemap `A|B` or `Label=code`, checkbox
  two stored values, range `min|max|step`). Rendering columns stay in rfp.
- **Fingerprints (trap's algorithm, `trap/R/trp_form_read.R:348`)**: `<n>-<xxhash64>` over
  radix-sorted `name:TOUPPER(sqlite decl type)`, excluding `fid` and geometry. Every live 2026 form
  in the four fish passage projects equals rfp's shipped build fingerprint
  (pscis `99-36743b027ac0c93f`, fiss_site `149-4afd59e31906de23`, mfp `35-b691942730a870fd`,
  mg `50-ac82d7713b6f1529`, monitoring `124-d5a9a23d77a7bfe1`) — **except one project's
  `form_monitoring`: `122-1ab1dc3ee75195f0`**, which is *not* a subset of the 124: it lacks
  `surveyor_1..3, habitat_comment, utm_corrected, assessment_comments_og` and carries
  `rowid, utm_zone, easting, northing`. So the "narrower vintage is a subset" assumption (#14's
  measurement) fails for monitoring — the #6 rename class, now measured.
- `form_pscis_newgraph` and `form_fiss_site_newgraph` carry the base forms' fingerprints: same
  vintage, different form name (answers an open question in trap's harvest issue).
- 2023–2025 local files show ~15 more pscis and ~10 fiss_site fingerprints, many of them
  post-processed copies (a `_raw` file and its processed twin differ). Deferred (gate decision 3).
- Runtime today: `crt_schema_conform()` = validate required presence + `crt_schema_apply()` typing
  (`integer, double, string, logical, datetime`); schema is a floor, not a ceiling.
  `crt_schema_validate()` already reserves `cols[].enum` / `range` slots. Registry integrity test
  walks every schema (`tests/testthat/test-crt_registry_integrity.R`).
- crate is **public**: no project names, local paths or hosts in YAML, decisions, tests or NEWS;
  live captures are described by month and count.
- `PKGSTALE rfp 0.92.0 -> 0.93.0`, `trap 0.7.0 -> 0.11.0` locally — irrelevant here: the derive
  script reads rfp files at a pinned SHA through `gh api`, not the installed package.

## Decided at the gate (user, 2026-10-30, via AskUserQuestion in plan mode)

1. **Key:** `nge/form_<name>` (flat), so a record's `form` value is its schema's `file_name`.
2. **Fingerprint moves into crate:** exported `crt_schema_fingerprint()` (definition per decision 4);
   `digest` joins Imports; trap switches in a follow-up trap issue.
3. **Versions listed now:** rfp's shipped builds and the measured live 2026 vintages (incl. both
   monitoring shapes). The 2023–2025 back-catalogue, read from Mergin server history, becomes a new
   crate issue.

4. **Fingerprint hashes the plain string** (user, 2026-10-30, asked mid-Phase 1): trap's
   `digest(pairs, "xxhash64")` hashed R's *serialization* (digest's `serialize = TRUE` default),
   contradicting form_capture's own rule. crate defines it over the string's bytes
   (`serialize = FALSE`); every fingerprint in this plan is recomputed that way (pscis
   `99-c084e87fbf17e20e`, was `99-36743b027ac0c93f`), and trap's five form tables get new
   `schema_version` values once, on their next harvest.

5. **Canonical type follows the values** (user, 2026-10-30, from plan review): a dropdown whose
   choices are not numeric is `string` whatever rfp declares (fiss_site's 7 `real` method
   columns); an rfp issue is filed for the declared type.
6. **Meaning is published unscrubbed** (user query 2026-10-30): the review's "names a person"
   claim was wrong (CHRIS is MoTI's system); the CSV meaning columns carry nothing private.

Defaults taken (not questions — say so in the PR):
- Known versions are recorded as **`upstream_variants` entries gaining a `fingerprint:` key**, reusing
  the existing concept (CLAUDE.md: "record each new shape as an `upstream_variant`") rather than a
  new top-level list. Ids like `rfp-build-2026-09`, `mergin-capture-2026-09-alt`.
- Unknown fingerprint is **reported, not fatal**: `crt_schema_conform()` raises a classed warning
  (`crate_unknown_fingerprint`); `crt_schema_variant()` returns `NA` for it.
- Per-form schemas **repeat the six envelope columns** (as #14's decision said they would), guarded
  by an integrity test asserting they equal `form_capture`'s verbatim; plus `x`, `y`, `source_epsg`
  (what trap emits for position). All form columns `required: false`.
- Grades: every form gets `harvestable` (envelope + non-NA `x`, `y`); `monitoring` also gets
  `crew_attributed` (requires `surveyor_1`), the grade the measured 122-column vintage cannot meet.
  Other domain grades are #1's / later issues', not invented here.
- `captured_by` stays in `form_capture`'s `forward_compat` — not decided by this PR.

## Phase 1: Fingerprint lives in crate
- [x] Tests first: `test-crt_schema_fingerprint.R` — fixture tied to trap's measured value for rfp's shipped
      pscis/fiss_site name:type sets (fixtures `tests/testthat/fixtures/forms/<form>_cols.csv`);
      order-invariant; type-sensitive; aborts on a missing type; locale-independent (radix sort)
- [x] `R/crt_schema_fingerprint.R` (exported, runnable example); `digest` to Imports
- [x] `form_capture.yaml` `schema_version` notes name the algorithm and the function

## Phase 2: Schema keys and runtime
- [x] Tests first: `test-crt_schema_meaning.R` (cols, grade, variant on an inline schema)
      (grade fixture has rows that fail as well as pass; unknown fingerprint warns with its class)
- [x] YAML keys, documented in `inst/extdata/schemas/README.md`: `cols[].units`, `cols[].values`
      (string or `{value, label}`), `cols[].range`, `cols[].relative_to` (photo paths),
      `cols[].null`, top-level `grades:` (`name`, `requires`), `upstream_variants[].fingerprint`
- [x] `crt_schema_cols(source, file_name)` — exported tibble of declarations (name, type, required,
      units, values list-col, range, relative_to, null, notes); the accessor rfp's builder and #1's QC read
- [x] `crt_schema_grade(df, source, file_name)` — exported, one logical column per declared grade
- [x] `crt_schema_variant(df, source, file_name)` — exported, fingerprint → variant id, `NA` unknown;
      `crt_schema_conform()` warns on unknown fingerprints when the schema lists any
- [x] Integrity tests: grades name declared cols; fingerprints well-formed and unique per schema;
      `values` only on string/integer cols and every value a character (Yes/No!); every `form_*`
      schema carries the envelope verbatim
- [x] Review fixes: pscis fixture tied to the measured serialized value; `enc2utf8()` names;
      `crt_schema_validate()` reserved slot renamed `cols[].values`

## Phase 3: Derive the meaning from rfp, not restate it
- [x] `data-raw/forms_derive-schemas.R`: reads the four CSVs + `monitoring`'s QML/GPKG at a pinned
      rfp SHA via `gh api`; maps types (`text→string, integer, real→double, datetime, boolean→logical`);
      units from an allow-list of unit tokens in the label's trailing parentheses, falling back
      to the name suffix (`_m`, `_c`, `_percent`...); a dropdown with non-numeric choices is
      `string`; drop QGIS `<NULL>` sentinels and int32 sentinel ranges; monitoring's photo root
      read from its QML; header says it is a one-off bootstrap until rfp's builder reads from crate;
      `values` from valuemap/checkbox options; `range` from range options; photo cols
      `relative_to: project root` (`ignore_mobile/photos/...`); blank-`group` cols get a `null` note
      (office/computed, null until filled); help → notes
- [x] Writes the column fixtures for Phase 1 from the shipped GPKGs' declared types
- [x] Idempotent: a second run leaves every YAML byte-identical (checked)

## Phase 4: Register the five schemas
- [x] `nge/form_pscis`, `form_fiss_site`, `form_monitoring_fish_passage`, `form_monitoring_general`,
      `form_monitoring` YAMLs generated; registry rows (`schema_only`, `canonical_cols` = required
      envelope cols)
- [x] `upstream_variants` per form: the rfp build (fingerprint tested against the Phase 1 fixture);
      `form_monitoring` also the measured 122-column 2026 vintage with its non-subset columns listed
- [x] Description per schema states what a null means (not answered vs. not on this vintage, read
      from `schema_version`) and that monitoring vintages rename rather than nest

## Phase 5: Acceptance tests over the registered forms
- [x] Two monitoring vintages (124 / 122 shapes) conform to one table, distinguishable by
      `schema_version`, each mapped to its variant by `crt_schema_variant()`
- [x] The narrower vintage validates and is excluded by `crew_attributed`; `harvestable` fails a
      row with no fix
- [x] Allowed values for a pscis/fiss_site dropdown come back from `crt_schema_cols()`, and a
      QC-style check over them flags a near-miss and a label stored where a code belongs
- [x] An unlisted fingerprint on a registered form warns; every listed variant's fingerprint is
      recomputed from its column fixture

## Phase 6: Docs and cross-repo
- [x] Decision entry `decisions/nge/20261030_form_schemas_fish_passage.md` (why derived from rfp,
      fingerprint ownership, variants-as-versions, grades, the measured non-subset)
- [x] README (registry output, public `crt_schema_*` list), CLAUDE.md Status line; `pkgdown::check_pkgdown()` clean (no reference index to update). NEWS is written by `/gh-pr-merge` at release, as for every prior version
- [x] Filed: crate#36 back-catalogue; trap follow-up (fingerprint from crate, re-harvest, per-form conform, `_newgraph` mapping, non-nested stack); rfp type-bug issue; rfp builder issue's body edited. Was: crate issue for the 2023–2025 back-catalogue; trap issue to call
      `crt_schema_fingerprint()` (re-harvest replaces serialized values, which warn until then;
      `trp_form_stack()` must accept non-nested vintages; `_newgraph` forms share base
      fingerprints and map to the base schema); rfp issue for fiss_site's 7 `real` text columns;
      edit the rfp builder issue's body: crate side available via `crt_schema_cols()`

## Owed at the end (reported, done after merge)

- [ ] trap switches to `crate::crt_schema_fingerprint()` (trap follow-up issue)
- [ ] rfp's builder reads meaning via `crt_schema_cols()` (rfp's work, unblocked by this PR)

## Validation
- [x] Tests pass (`devtools::test()`, single-file reruns with `NOT_CRAN=true`)
- [x] `lintr::lint_package()` clean; `devtools::document()`; `devtools::check()` clean
- [x] `/code-check` clean (once over the branch with `/code-check branch`)
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion

How each change is proved: fingerprint equality against values trap actually wrote; derive script
re-run byte-identical; grade tests that fail on purpose; restore-the-bug checks on each new guard
(drop a grade's required col, corrupt a fingerprint, remove an envelope col from one form schema).
Plan review (Plan agent) runs concurrently after the baseline; findings fold in as they land.
Version bump at merge via `/gh-pr-merge` (minor).
