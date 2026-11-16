## Outcome

The five fish passage form schemas now list the column sets crews captured records into from
2023 on, read from the sync service's version history by the new `data-raw/forms_read-history.R`
and registered by `data-raw/forms_derive-schemas.R`: 7 new `upstream_variants` (pscis 2,
fiss_site 3, monitoring 2), with `capture-utm-columns-2025` moved into the same measured table.
A column set counts if a file in that shape gained a record under a new key with content the
version before it lacked, so processed copies, re-exports and a duplicated row are not listed.
Columns only earlier versions carry are declared with a `variants` key, which `crt_schema_cols()`
returns; `form_monitoring.site_id` became a string. Learned on the way: the sync service rebuilds
a version pushed as a geodiff, so its bytes never match the client's checksum and the form-tooling package's fetcher
refuses it (filed against the form-tooling package); the harvester refuses every 2023 version's zone-less datetimes
(filed against the harvester); and a cache keyed by the object it came from also depends on the code, the
runtime and what a name meant, which four review rounds closed one place at a time. The durable
verdict is `research/form_versions.md`.

## Measurement

Read 2026-11-16 (the form-tooling package 0.94.0): 21 projects, 1,106 versions; 12 projects held a form file: 141
paths, 635 form-file versions, 575 distinct files. 84 column sets (per form), 12 took records:
four builds, the 2025 monitoring version, 7 earlier ones; the other 72 are copies never captured
into. 185 versions grew a form file, 174 from the field app.

- **Fetching:** the first full read failed 274 of 575 fetches on checksum. Diagnosed as the
  server's rebuild of geodiff versions (every failure a geodiff; no whole upload failed; 87 other
  geodiffs matched). Rebuilt files were accepted on SQLite's integrity check, and then all 361
  geodiff versions with a predecessor were checked: record count equals the predecessor's plus
  the diff's inserts minus deletes, 0 disagree.
- **The growth rule, revised by measurement:** the first reading ("a higher count or largest
  key") listed one fiss_site shape whose only new record was record 35 duplicated under a new id,
  dropped a day later; the owner asked whether it was an error copy, and it was. Growth became "a
  new key with new content"; over all 635 versions that changed three verdicts (that version, and
  two build resets now counting).
- **Types:** `form_monitoring.site_id` held 17 site names among 18 distinct values in a 2024
  version, all NA as a double, so it is a string; a 2023 pscis DATE conforms losslessly to the
  build's datetime.
- **Checks:** three fingerprints recomputed through the harvester's own column set on fresh
  downloads, all matching; one project's 59 pscis versions read by hand against the verdicts; the
  derive byte-identical across runs and under a French locale.
- **Downstream:** 5,268 of 5,268 datetime values in the 2023 versions, and 4,083 of 5,216 in the
  pscis and fiss_site build captures, carry no timezone.
- **Review:** four `/code-check` rounds. Round 1 found a stale failure list letting `write` drop
  unread versions; rounds 2–4 found the same mechanism (a cache entry's presence taken as proof it
  is complete and current) in the file cache, the record cache and the change-list cache, round 4
  inside round 3's fix. Ended by enumerating every cache entry with its check (findings.md).

## Evidence

The per-project measurement stays outside the repository because it names projects:
`tools::R_user_dir("crate", "cache")/forms_history/` (`shapes.csv`, `seasons.csv`,
`versions.rds`), rebuilt by `Rscript data-raw/forms_read-history.R read` then `write`. Review
findings: `review-round*.md` in this directory.

Closed by: PR for #36
