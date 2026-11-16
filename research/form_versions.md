# Fish passage form versions

**Verified:** 2026-11-16 · **Issues:** #36 (this), #13 (the schemas it extends) ·
**Produced by:** `data-raw/forms_read-history.R` (rfp 0.94.0), then
`data-raw/forms_derive-schemas.R` · **Status:** settled for 2023 to 2026-11; re-run each season.

Which column sets the five fish passage forms (`form_pscis`, `form_fiss_site`,
`form_monitoring`, `form_monitoring_fish_passage`, `form_monitoring_general`) were captured
with, read from the sync service's version history. Each set records went into is listed in
its schema as an `upstream_variant`, so `crt_schema_variant()` names the version a record came
from and `crt_schema_conform()` does not warn that its fingerprint is unknown.

## Why the history, and not the files on disk

Local copies of a form are mostly processed: season archives, `_raw` files, backups, resaved
and renamed copies, and deployments under another name. Their column sets differ from the
file crews captured into, so a set found on disk says nothing about whether a crew used it. The
sync service keeps every version of every file, with the number of records in each, so it can
answer the question that matters: did records go into this shape?

## The rule

A column set is a version of its form if records went into it: some version of a file in that
shape holds a record that the version before it did not. The comparison is within one chain:
the same project, path, table and shape, restarted when the file is removed. A record went in
when it sits under a key the previous version lacked and holds content (every column but the
key, geometry included) that none of the previous version's records had. So:

- a file uploaded once, or rewritten with the records it held, is not a version;
- a deleted test record and a new one in the same sync still count;
- a duplicated row does not count. The rule first read "more records" as a higher count or
  largest key, which listed a 2025 archive copy whose one "new" record was another record
  repeated.

A file belongs to the form its name says, longest form name first, after an optional leading
year. A set must share at least half its columns with the build or with a version already
accepted (best of them), so a file named for one form that holds another is not listed under
it. `layer_styles` is not a form table.

Variants are named `capture-YYYY-MM` for the month a set first took records, with `-a`, `-b`
where two share a month, in fingerprint order. `capture-utm-columns-2025` (#13) keeps its name,
which harvested tables already carry; its `first_seen` is measured like the rest.

## What was measured (2026-11-16)

- 21 projects, 1,106 versions; 12 projects ever held a file named for one of the forms: 141
  paths, 635 form-file versions, 575 distinct files, 2023-05 to 2026-11.
- Column sets per form, and how many took records: pscis 39 / 3, fiss_site 30 / 4,
  monitoring 12 / 4, monitoring_fish_passage 2 / 1, monitoring_general 1 / 0. The other 72 are
  copies never captured into. 185 versions grew a form file, 174 of them pushed from the field
  app.
- Listed: four builds, the 2025 monitoring version, and 7 earlier versions: pscis 2 (2023-06,
  2023-08), fiss_site 3 (2023-08 twice, 2023-09), monitoring 2 (both 2024-09). Each took
  records from the field app.
- Took records per season: pscis 2 / 2 / 1 / 1 sets in 2023 / 2024 / 2025 / 2026, fiss_site
  3 / 2 / 1 / 1, monitoring 0 / 3 / 3 / 1. The monitoring form was first uploaded in 2024-09,
  so 2023 has none. The pscis and fiss_site builds took records from 2024-09 and the monitoring
  build from 2025-09, earlier than their `rfp-build-2026-08` ids suggest: those name rfp's file
  date.
- The overlap floor rejected nothing: every set that took records shares at least 0.77 of its
  columns with a reference. The one set under it (0.01, a fiss_site table in a file named for
  pscis) never took records, so the growth rule had already left it out.
- Every form table's key is a single INTEGER, so a harvester's column set (all but the key and
  the geometry) is the set fingerprinted here.

## How each fact was checked

- **Files the server rebuilt.** A version pushed as a geodiff is rebuilt by the server from its
  base file and diffs, so its bytes never match the checksum the pushing client computed, and
  `rfp_mergin_file_get()` refuses it: 274 of the 575 files. Each is fetched without the
  checksum and kept only if the version's change for that path is a geodiff and SQLite's
  integrity check passes. No file uploaded whole failed the checksum. Then every geodiff
  version with a predecessor (361) was checked: its record count is the predecessor's plus the
  diff's inserts minus its deletes, from the server's own summary. None disagree.
- **Fingerprints.** Three variants, fetched again from the service and read with the harvester's
  own column set and declared types, give the listed fingerprints and record counts.
- **The rule.** One project's pscis files (59 versions over 10 paths) were read by hand against
  the verdicts, including season archives and backups that hold records but never gained one.

## What it means for the schemas

- A column only earlier versions carry is declared, typed from its declarations (a string
  where versions disagree), with a `variants` key naming the versions that have it.
  `crt_schema_cols()` returns that key, so a form builder can leave the column out.
- A column shared with the build keeps the build's type unless an earlier declaration would
  lose values: `form_monitoring.site_id` is a string, because a 2024 version holds site names
  there. A 2023 pscis `date` (DATE) conforms to midnight UTC that day under the build's
  datetime, so it stays. The derive stops on any conflict it has not been told.
- The pre-2025 versions store datetimes with no timezone, which the harvester refuses rather
  than guess. Every 2023 version does, and so do most pscis and fiss_site build captures. Which
  zone they were written in is open.

## Re-running it for a new season

From the repository root, in a UTF-8 locale, with sync-service credentials in the environment:

```sh
Rscript data-raw/forms_read-history.R read    # resumable; caches outside the repository
Rscript data-raw/forms_read-history.R write   # fixtures + data-raw/forms_variants-measured.csv
Rscript data-raw/forms_derive-schemas.R       # the five YAMLs
```

`write` refuses while any read failed, and stops if a geodiff version's record count disagrees
with its diff. The derive stops on a shared column typed differently from the build's that is
not decided in its `shared_type`. The cache keeps the per-project detail (`shapes.csv`,
`seasons.csv`), which names projects and so stays out of the repository.
