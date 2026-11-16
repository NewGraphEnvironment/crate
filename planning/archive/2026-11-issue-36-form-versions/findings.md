# Findings — List the 2023–2025 versions of the fish passage forms, read from the sync service's history (#36)

## Issue context

## Problem

#13 registered the fish passage form schemas with the versions deployed today: the form builder's builds, and one 2025 `form_monitoring` shape still in the field. A record captured with an earlier build of these forms (2023–2025) has a fingerprint none of them lists, so `crt_schema_conform()` reports it as `crate_unknown_fingerprint` and `crt_schema_variant()` returns `NA`.

Local copies of those seasons show about 15 more `form_pscis` and 10 more `form_fiss_site` fingerprints, but many of those files are processed copies — a `_raw` file and its processed twin give different column sets — so a local file's fingerprint is not evidence of a form build.

## Proposed

Read each form's version history from the sync service rather than from local copies: for every version of `form_<name>.gpkg` in each fish passage project, the GeoPackage's declared column types, then `crt_schema_fingerprint()`. Each distinct column set becomes an `upstream_variant` with its fingerprint and a fixture under `tests/testthat/fixtures/forms/`, as the existing variants have. Name variants by when they first appear, not by project.

## Acceptance

- Every column set a fish passage form was captured with since 2023 is listed, each with a fixture that recomputes its fingerprint.
- A variant that renames rather than nests (as `form_monitoring`'s 2025 shape does) says so in its description.

Follows #13.


## The history, measured (2026-11-16)

Read by `data-raw/forms_read-history.R` (the form-tooling package 0.94.0) from the sync service's history of every
project the account sees; per-project detail stays in the cache outside the repo.

- **Walked:** 21 projects, 1,106 versions. 12 projects ever held a file named for one of the five
  forms: 141 paths, 635 form-file versions (158 added, 437 updated, 40 removed), 575 distinct files,
  first 2023-05, last 2026-11.
- **Fetching:** 274 of the 575 were refused by `rfp_mergin_file_get()`'s checksum check. Every one
  is a version pushed as a geodiff, which the server rebuilds from the base file and diffs, so its
  bytes cannot match the pushing client's checksum (filed against the form-tooling package). No file uploaded whole was refused;
  87 other geodiff versions matched anyway. Each rebuilt file passed SQLite's integrity check, and
  all 361 geodiff versions with a predecessor hold exactly their predecessor's records plus the
  diff's inserts minus its deletes (0 disagree), so the record counts the rule reads are right.
- **Shapes (distinct fingerprints) per form, and how many took records:** pscis 39 / 3,
  fiss_site 30 / 4, monitoring 12 / 4, monitoring_fish_passage 2 / 1, monitoring_general 1 / 0.
  The other 72 are copies uploaded and never captured into. 185 versions grew a form file: 174
  pushed from the mobile app, 11 from desktop.
- **Overlap rejects:** none. Every shape that took records shares at least 0.77 of its columns
  with the build or an accepted version. The one shape under 0.5 (0.01 under `pscis`, a
  fiss_site table in a file named for pscis) never took records, so growth had excluded it
  already; the overlap floor is untested on real data (code-check round 2).
- **Primary keys:** every form table's key is a single INTEGER.
- **Per season (shapes that took records):** pscis 2 / 2 / 1 / 1 in 2023–2026, fiss_site
  3 / 2 / 1 / 1, monitoring 0 / 3 / 3 / 1. `form_monitoring` was first uploaded in 2024-09, so 2023
  has no monitoring form at all, not a missing one; the two 2026 monitoring forms took records
  only in 2026 (monitoring_general none yet).
- **Builds already listed:** the pscis and fiss_site builds took records from 2024-09, and the
  monitoring build from 2025-09; the 2025 monitoring variant from 2024-09, earlier than the 2025
  #13 recorded, so its `first_seen` becomes the measured 2024-09 (its id stays: it is published).
- **New variants:** 7 — fiss_site 3 (2023-08 ×2, 2023-09), pscis 2 (2023-06, 2023-08),
  monitoring 2 (2024-09 ×2). The
  64-column monitoring shape is a deployment's cut-down copy of the monitoring form (its earlier
  123-column shape is also in the plain monitoring file); under the rules it is a monitoring
  variant.
- **Shared columns typed differently from the build:** `form_pscis.date`, DATE in both 2023
  shapes and DATETIME in the build: conformed, a date becomes midnight UTC that day, so nothing is
  lost. `form_monitoring.site_id`, TEXT in the 64-column shape and REAL in the build: 17 of its 18
  distinct values are site names, not numbers, which conform to NA as a double. Gate answer (2026-11-16): `string` for every monitoring version.
  `form_monitoring_general` already declares `site_id` TEXT.

## Proving it (2026-11-16)

- **Fingerprints, independently:** three variants (`capture-2023-08` pscis, `capture-2023-09`
  fiss_site, `capture-2024-09-b` monitoring), each fetched fresh with `rfp_mergin_file_get()` at a
  version uploaded whole, read with the harvester's own column set (0.13.0) (`sf::st_read(fid_column_name =
  "record_id", optional = TRUE)` minus `record_id` and geometry, types from `trp_gpkg_types()`)
  and fingerprinted with `crt_schema_fingerprint()`: all three match, record counts too. the harvester's
  own `schema_version` differs for every file because it still hashes R's serialization; an open
  harvester issue owns that.
- **The growth rule, by hand:** one project's pscis files, 59 versions over 10 paths. On the
  live form file, 1 → 7 → 14 records are growth, a reset to 1 after the season archive is not, and
  max row id 1 → 25 → 35 → 36 is growth while the count dips (records deleted in the same sync).
  Every season archive, backup and resaved copy is correctly no growth, including the 2023
  archive, whose shape changed four times while it held 80-81 records.
- **Whether the rule lists only what crews used — a duplicated row is not a record (user's
  question at the desktop-only gate, 2026-11-16):** under the first reading of "more records"
  (a higher count or largest row id), one fiss_site shape (150 columns, 2025-02) was listed: a
  `_raw` season archive written by R (`wetted_width_m.channel_width_m_time`) that gained one
  record through a desktop push. That record equals record 35 in all 151 columns but the row id,
  and the next version dropped it: an accidental duplicate. So growth is now a record under a key
  the previous version lacked whose content none of its records had (each record hashed, geometry
  included). Re-run over all 635 versions, the rule changes three verdicts: that version no
  longer counts (the shape drops out), and two desktop resets of build files to one record with
  new content now count (both builds, already listed). Every listed shape took records from the
  field app; the measured table carries `grew_from` and each description says it.
- **Harvesting it is blocked downstream:** the harvester refuses a form file whose DATETIME values carry
  no timezone, and every 2023 shape's values do (5,268 of 5,268), as do most pscis and fiss_site
  build captures (4,083 of 5,216). Filed against the harvester. Not this issue's to fix: the variants are
  listed whichever way the harvester decides.
- **The build ids' `first_seen` is the form builder's file date (2026-08), not the shape's:** the pscis and
  fiss_site build shapes took records from 2024-09. Left as is (the plan's call); the decision
  record says so.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| 274 of 575 form-file fetches refused with `Checksum mismatch` by `rfp_mergin_file_get()` (2026-11-16) | Every one checked is a version whose change for that path is a geodiff (the version record's `changes$updated[]` entry carries `diff`); the server's `/raw` endpoint rebuilds it from base file + diffs, so its bytes cannot match the pushing client's checksum. Tracked in the form-tooling package. The history script now fetches such a file without the check, keeps it only if the change is a geodiff and `PRAGMA integrity_check` is `ok`, and `write` checks every geodiff version's record count against the diff's own insert − delete. |
| Earlier fingerprint for `capture-utm-columns-2025` typed from #13's notes (`122-1ab1…`) | Those notes predate the fingerprint fix; the derive's fingerprint check caught it; the correct value is `122-795b55de0708d6bf`. |
| `write` re-run after registration listed 1 variant instead of 9 | It took every fingerprint the schema lists as pre-registered, and the schema now lists the measured variants. Only the build (first variant) is pre-registered now, and kept ids are left out of the month-suffix count. Ids and fixtures unchanged on re-run. |
| A listed shape's only growth was a duplicated row (user asked whether it was "an extra weird error version") | It was: record 35 copied under a new id, dropped the next day. Growth now needs a record with a new key and content the previous version lacked; the shape and its fixture are gone. |

## Lints (2026-11-16)

Against `origin/main` per file, linter and line: the branch adds four `object_usage_linter`
"no visible global function" lints, all calls to `gpkg_tables()`, `gpkg_decl()` and `gpkg_nrow()`,
which `data-raw/forms_gpkg-decl.R` defines and both scripts `source()`; lintr does not follow a
`source()`. The rest (braces, semicolons, nested `ifelse()` indentation, an unused variable)
are fixed. Tests: 2772 pass after merging main.

## Code-check (2026-11-16)

Round 3 named the mechanism behind rounds 1 and 2: a cache entry's presence taken as proof it is
complete and current (`failures.txt`, a partial download, and the meta records), and output
computed from the run's environment assumed stable across runs (ids, month names). It walked every
cache artifact and every run-dependent output. The one open place, `meta/*.rds` keyed only by the
file checksum, now carries the reader's version (a digest of the code that reads a file), and
both `read` and `write` treat a record from other code as unread.

Round 4 found the mechanism one level down, inside round 3's fix: each cache is keyed by the
server object it came from (a file checksum; a project name plus version number), but its value
also depends on the code that made it, the runtime, and which project a name meant then. Round 3's
reader stamp covered only the code. Now the stamp also carries R's, RSQLite's, DBI's and digest's
versions; each cached changeset carries its version's creation time and is fetched again when the
history's differs; and `write` refuses a version record whose time is not the walk's.

**Enumeration that ended the review (2026-11-16, after the re-read):** every top-level entry of the
cache, with its check, measured: `files/` 575 (301 match their sha1; the 274 that do not are exactly
`rebuilt.txt`; none outside the walk); `meta/` 575 of 575 stamped with the current reader;
`changesets/` 1,106 of 1,106 stamped with their time; `raw/` 357 of 357 form-file versions present
with the walk's time; `agents/` 357 of 357 equal to their raw record; `failures.txt` empty, and
written as "in progress" at each `read`'s start; `walk.rds` rewritten by every `read`;
`versions.rds`, `shapes.csv`, `seasons.csv`, `stems.txt` rewritten by every `write`; `rebuilt.txt`
only counted. In the repository, fixtures and the measured table are reproduced byte for byte, and
the derive refuses a fixture whose fingerprint is not the table's. Each new guard was made to fire
(a missing meta file, a changed reader, a tampered version record's time, a dropped listing).
