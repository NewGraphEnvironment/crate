# Task: Photo-table schema: one row per photo file (#67)

Photos from field surveys and camera traps are matched to the records that refer to them by
file name. A resized copy usually keeps the original's name, so a match by name cannot tell
them apart, and nothing records which copy came from which original. crate registers table
schemas (`crt_files()`, `crt_schema_conform()`), and has none for photos.

## Context

Photos are matched to records by file name, so a resized copy that keeps its original's name is
mistaken for it, and nothing records which copy came from which original. crate has no photo
schema. A photo indexer in development elsewhere (a folder of photos in, one row per file out)
waits on this issue. This registers two `schema_only` entries the caller conforms to with
`crt_schema_conform()`, the same way the track and discharge tables work. No new R function.

## Decided at the gate (owner, 2026-11-16)

1. **Two tables, not one.** `nge/photo_files` holds the file (bytes, pixels, time, place, camera);
   `nge/photo_links` holds what it shows (record, site, view). One photo can show several
   records, and one file's bytes at two paths do not repeat their links. Form records are keyed
   by `(project, form, source_version, record_id)` (form_capture.yaml:36–67, record_id restarts
   at 1 on a rebuild), so the link carries all four, not `record_id` alone.
2. **Time is three columns:** `time` (UTC datetime instant, NA when the camera wrote no offset),
   `time_local` (the wall clock as written, ISO 8601 text with no zone), `time_offset` (`-07:00`,
   or NA). No time with no offset is presented as UTC (the indexer's requirement), `time` joins to
   `track_vertices.time`, and Camtrap DP's `timestamp` is `time_local` + `time_offset`.
3. **Position is `gps_lon`, `gps_lat`**, as the issue names it: the camera's fix, WGS84.
4. **`nge` vs `newgraph` (owner asked):** not locked, but not this issue. Measured 2026-11-16:
   48 files in crate (registry, schema and decision dirs, tests, examples, NEWS, and the exported
   `crt_handler_nge_fish_data`), plus callers in two other packages: an internal track and form reader (about seven R
   files) and wet (`R/wet_catalog.R`, `scripts/discharge_publish_lib.R`). It is a
   breaking rename across three packages, so it gets its own crate issue (Phase 4). The photo
   tables register under `nge` and move with the rest if it lands.

## Phase 1: Tests first

- [x] `tests/testthat/test-crt_photo.R`, failing until Phase 2:
  - a `photo_files` frame conforms: `size` double (a value above 2^31 kept exactly), `width`/
    `height` integer, `time` POSIXct in UTC, `time_local`/`time_offset` character, `gps_*` double
  - a row with `time_local` set and `time` NA conforms (no offset, no instant), and `time` stays NA
  - an original and its resized copy with the same file name are two rows, the copy's
    `derived_from` equal to the original's `checksum`
  - missing `checksum`, `path` or `size` is refused, naming the column
  - a `photo_links` frame conforms (`record_id` integer); one checksum linked to two records is two
    rows; missing `checksum` or `project` is refused
  - the `record` grade on `photo_links` (`crt_schema_grade()`) is met only with form, source_version
    and record_id present
- [x] `test-crt_registry_integrity.R` already walks every row (YAML exists, path rule, types,
  canonical_cols ⊆ schema, quoted values); no edit expected, confirm it covers the new rows

## Phase 2: Schemas and registry

- [x] `inst/extdata/schemas/nge/photo_files.yaml` — modelled on `track_vertices.yaml`; each column
  with `notes`, `units` where it has one:
  - required: `path` (string, as the caller gave it), `checksum` (string, SHA-256 of the bytes,
    lowercase hex, the value a receipt's `result.parts[].sha256` holds), `size` (double, bytes;
    double because integer stops at 2^31)
  - optional: `time` (datetime), `time_local`, `time_offset` (string), `gps_lon`, `gps_lat`
    (double, EPSG:4326; NA once stripped), `width`, `height` (integer, px), `media_type` (string,
    IANA), `camera` (string, make and model), `derived_from` (string, the original's checksum; NA
    for an original)
  - key `(checksum, path)` in the notes; where a photo is stored is not here (a store keys its own
    table and joins on `checksum`); a Camtrap DP 1.0.2 media mapping in the description
    (`filePath`←`path`, `fileMediatype`←`media_type`, `timestamp`←`time_local`+`time_offset`;
    Camtrap DP has no checksum or copy link)
- [x] `inst/extdata/schemas/nge/photo_links.yaml` — required `checksum`, `project` (string);
  optional `form`, `source_version` (string), `record_id` (integer), `site`, `view` (string, from
  the caller's form or naming rule, never guessed from names); grade
  `record: [checksum, project, form, source_version, record_id]`
- [x] Two rows in `inst/extdata/crate_registry.csv`, `canonical_cols` = the required columns
- [x] Phase 1 tests pass

## Phase 3: Decision log and docs

- [x] `decisions/nge/20261116_photo_tables.md` — the four gate decisions above, the checksum's
  identity with the receipt digest, why the store key is out, Camtrap DP mapping, the indexer as producer
- [x] `CLAUDE.md` Status paragraph: add the two photo tables to the `schema_only` list
- [x] `vignettes/reading.Rmd` prints `crt_files()` live, so it updates itself; check it renders

## Phase 4: Follow-up issue

- [x] File a crate issue (#68): rename source family `nge` → `newgraph`, with the measured blast radius
  above (crate, the internal reader, wet; the exported handler name) and the question of a shim versus a hard
  rename for the plan gate there

## Owed at the end (reported, done after merge)

- [ ] Tell the photo indexer's issue that the schemas are registered (released version, the two `file_name`s)

## Validation

- [x] Tests pass
- [ ] `/code-check` clean (once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

Verification: `devtools::test()` with error grep (the new file plus registry integrity);
`lintr::lint_package()` on changed files; `devtools::document()` shows no change (no new
exports, so no `check_pkgdown` needed); render `vignettes/reading.Rmd` and confirm both photo
rows in the `crt_files()` output. NEWS and version are `/gh-pr-merge`'s.

