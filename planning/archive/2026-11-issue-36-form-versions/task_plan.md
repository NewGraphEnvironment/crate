# Task: List the 2023–2025 versions of the fish passage forms, read from the sync service's history (#36)

## Problem

#13 registered the fish passage form schemas with the versions deployed today: the form builder's builds, and one 2025 `form_monitoring` shape still in the field. A record captured with an earlier build of these forms (2023–2025) has a fingerprint none of them lists, so `crt_schema_conform()` reports it as `crate_unknown_fingerprint` and `crt_schema_variant()` returns `NA`.

Local copies of those seasons show about 15 more `form_pscis` and 10 more `form_fiss_site` fingerprints, but many of those files are processed copies — a `_raw` file and its processed twin give different column sets — so a local file's fingerprint is not evidence of a form build.


### What exploration found (2026-11-16, crate at ecadfc6, the form-tooling package 0.94.0 installed = its main)

- **The form-tooling package already has every reader this needs**, so crate gets no Mergin client:
  `rfp_mergin_list()` (projects), `rfp_mergin_history()` (versions with dates),
  `rfp_mergin_changeset(project, version)` (files added/updated/removed, with checksums) and
  `rfp_mergin_file_get(project, file, path_out, version)` (one file at a version, checksum-checked).
  Auth is `MERGIN_USERNAME`/`MERGIN_PASSWORD`, present on this machine.
- **The population (read-only probe):** 21 projects in the `newgraph` workspace, about 1,100
  versions in all. Form GeoPackages are not only `form_<name>.gpkg` at the project root: there are
  season archives (`data_field/2023/form_pscis_2023.gpkg`), `_raw` files, backups,
  `_archived_dont_use`, conflicted copies, and deployments under other names
  (`form_pscis_newgraph`, and others). A file at HEAD is
  not the whole story either: removed paths show up only in changesets, so the walk has to cover
  every version.
- Table names inside old files may not equal `form_<name>` (e.g. `form_pscis_2023`), so a
  file's layer is read from `gpkg_contents`, not assumed.
- `data-raw/forms_derive-schemas.R` writes the five YAMLs and the build fixtures from the form builder at a
  pinned SHA. It has its own `gpkg_decl()` (declared types, excluding pk and geometry: the input
  `crt_schema_fingerprint()` and the harvester hash), and the measured 2025 variant is hardcoded in it as
  `extra_variants` / `extra_cols`. The YAMLs say "Edit the script, not this file".
- `test-crt_form_schemas.R` already recomputes every listed fingerprint from
  `fixtures/forms/form_<form>__<variant>.csv` and requires that fixtures and variants match one to
  one, so each new variant is checked automatically once its fixture exists.
- crate is **public**: no project names, paths, hosts or people in YAML, fixtures, tests, NEWS,
  decisions or research. Variants are described by month and count, as #13's were.

## Decided at the gate

1. **Columns an older version has that the build lacks are declared, typed** (user, 2026-11-16,
   AskUserQuestion): added to the form's canonical cols, typed from their GeoPackage declaration,
   each with a note naming the variants that carry it, as #13 did for the 2025 monitoring columns.
   Where variants declare one name differently, the type is `string`.
2. **A column set counts as a version if records went into it** (user, 2026-11-16): some version
   of a form file in that shape had more records than the version before it, whatever the path.
   A copy uploaded once and never captured into is counted in findings, not listed.
   *Made precise after the plan review (review-plan.md):* the previous version must be the same
   path, table and shape (growth across a shape change is a rebuild carrying records over); a
   removal starts a new chain; "more records" is a higher count **or** a higher max primary key
   (a delete plus an insert keeps the count). The version's `user_agent` (mobile app vs QGIS
   plugin / Python client), readable from Mergin's version record, is measured beside it; if
   shapes grew only through desktop pushes, that goes back to the user before Phase 2.
   *Made precise again after the measurement (user's question, 2026-11-16):* a new record is one
   under a key the previous version lacked whose content none of its records had, so a
   duplicated row or a renumbering re-export is not growth. The one desktop-only shape was such a
   duplicate and is not listed.
3. **(2026-11-16, asked with the results)** `form_monitoring.site_id` is `string` in every
   version: a 2024 version holds site names there. Columns only earlier versions carry get a
   `variants` key naming them, returned by `crt_schema_cols()`.

Defaults taken (mechanism, stated here rather than asked):
- **Scope:** the five registered forms only. A file is assigned to a form by its name (the longest
  match first, so `monitoring_fish_passage` before `monitoring`), then checked by column overlap
  with that form's build. Below 50% overlap it is listed in findings for review, not registered.
  Other forms (`fhap`, `edna`, …) are out of scope.
- **Window:** versions created from 2023-01-01 to today, across every project in the workspace.
  A shape that only 2026 test projects carry is reported, and is listed only if it also meets
  decision 2.
- **Variant ids:** `capture-YYYY-MM`, the month the shape first gained records, with `-a`/`-b`
  where two share a month. `first_seen` is that month. A shape whose fingerprint is already listed
  is not added again; if the server shows it earlier than its listed `first_seen`, findings say so.
- **The existing `capture-utm-columns-2025` variant** keeps its id (a published variant id in
  crate's YAML; harvested tables store the fingerprint, not the id) but moves out of the hardcoded `extra_variants` into
  the same measured-variants table as the new ones: reshape, don't accrete.
- **What the script logs:** a per-project measurement log, written outside the repo (project
  names stay private). The repo gets fixtures, one aggregated table and counts.

## Phase 1: Read the history (measurement)

- [x] `data-raw/forms_read-history.R`: walk `rfp_mergin_history()` + `rfp_mergin_changeset()` for
      every project since 2023, collecting each version of every path that names one of the five
      forms. Download each distinct (path, checksum) once with `rfp_mergin_file_get()` into a
      cache outside the repo, then record per version: layer, declared column types, fingerprint,
      row count. Runs as one R process, in the background, with resume from the cache.
- [x] Move `gpkg_decl()` into `data-raw/forms_gpkg-decl.R`, sourced by both scripts, so the
      fingerprint input is defined once.
- [x] Apply decision 2 (record growth within one path, per shape) and the 50% overlap check.
- [x] Record in `findings.md`, as counts with no project names: projects/versions/files walked;
      distinct shapes per form; how many gained records vs only-copied; the overlap rejects;
      shared columns whose declared type differs from the build's (**if any, ask before Phase 2**:
      the canonical type follows the build, and a text value in a numeric column would conform
      to NA); shapes that grew, **per season**, stopping to ask if a season 2023–2025 has none;
      tables whose primary key is not a single INTEGER (the harvester's column set would differ).
- [x] Overlap is taken against the build and the versions already accepted (best of them), and
      every reject is reviewed by hand and listed in findings. `layer_styles` is excluded by name.
- [x] Ask with the results, batched: whether old-only columns get a machine-readable marker
      (e.g. a key listing the versions that carry them) so a consumer of `crt_schema_cols()`
      does not read them as live fields.
- [x] Write a fixture `tests/testthat/fixtures/forms/form_<form>__capture-YYYY-MM.csv` (name,
      type) for each new shape, and `data-raw/forms_variants-measured.csv` (form, id, first_seen,
      n_versions, n_projects), including the 2025 monitoring row.

## Phase 2: Tests first

- [x] In `test-crt_form_schemas.R`, for every measured variant: its capture conforms with no
      warning and `crt_schema_variant()` names it; its description says "rename" exactly when
      each side has columns the other lacks (a version that only lacks columns nests in the
      build; one that only adds columns has the build nested in it), computed from the fixtures; every column it has is
      declared by the schema (decision 1); all of a form's variants stacked with `bind_rows()`
      conform to one table, which is the check that the types agree.
- [x] Run them: they fail until Phase 3 registers the variants.

## Phase 3: Register the variants

- [x] `forms_derive-schemas.R` reads `forms_variants-measured.csv` and the fixtures in place of
      `extra_variants` and `extra_cols`. It writes each variant's description from the fixture
      against the build (column count, how many build columns it lacks, the columns only it has,
      and "nests" or "renames"), and declares the old-only columns per decision 1, with a note
      naming the variants that carry them.
- [x] Extend the envelope-clash check to old-only columns; map every declared type met
      (`decl_map`, and the test's `capture()` fill).
- [x] Re-run at the same `rfp_sha`: the build variants and the existing columns stay
      byte-identical in meaning (diff the YAML), except two regenerated texts: the build
      description's "every 2026 capture … except the variant below", and the 2025 variant's
      hand-written description (now generated like the rest); the new variants follow the build in order of
      `first_seen`. A second run is byte-identical.
- [x] Phase 2's tests pass, along with the rest of the suite.

## Phase 4: Record it

- [x] `decisions/nge/20261030_form_schemas_fish_passage.md`: replace "The 2023–2025 back-catalogue
      … is not listed yet" with what was measured and the rule from decision 2.
- [x] `research/form_versions.md` (and a row in `research/README.md`): the method (the history
      walk and the record-growth rule), the counts, and how to re-run it for a new season.
- [x] NEWS.md entry. CLAUDE.md's Status line, where it describes the form schemas.

## Validation

- [x] Tests pass (`devtools::test()`), with no new lints (`lintr::lint_package()`, compared per file
      against main).
- [x] `/code-check` clean (once over the branch with `/code-check branch`).
- [x] PWF checkboxes match landed work.
- [ ] `/planning-archive` on completion, its README carrying Measurement and Evidence.

How each change is proved:
- **Each fingerprint:** recomputed from its fixture by the existing test, and spot-checked against
  three files downloaded independently with `rfp_mergin_file_get()` and fingerprinted by hand.
- **The record-growth rule:** a hand count for one project and one form, checked against the
  script's verdict, including at least one processed copy it rejects.
- **The derive:** byte-identical across two runs; a YAML diff against main that shows only the
  added variants, columns and descriptions.
- **The privacy guard:** a grep of the branch diff for every Mergin project name in the workspace,
  and every form file stem the walk found, returns nothing.
- **The spot-check** recomputes fingerprints through the harvester's column set (`trp_form_read()`), not
  `gpkg_decl()`, so it is not circular.

