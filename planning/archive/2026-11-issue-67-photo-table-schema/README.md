## Outcome

Registered two `schema_only` tables for photos, `nge/photo_files` (one row per file, keyed by
`(checksum, path)`, with the SHA-256 of its bytes as identity and `derived_from` linking a copy to
its original) and `nge/photo_links` (what each photo shows, keyed to the full form-record key or
to site and view), with `identified` and `record` grades. At the plan gate the owner chose two
tables over one, a three-column time (`time` as a UTC instant only when the camera wrote an
offset, `time_local`, `time_offset`) and `gps_lon`/`gps_lat`; asked whether `nge` could become
`newgraph`, which was measured and split out as #68. Decision log:
`decisions/nge/20261116_photo_tables.md`.

What was learned: every defect review found (a plan review and four `/code-check` rounds) was the
same mechanism, prose restating a fact another artifact owns: the datetime parser, form_capture's
NA `source_version`, the schema's own key, EXIF's datum tag, Camtrap DP's constraints. A
paraphrase of an external spec failed twice in a row; quoting the published constraint, and
pointing the decision log at the schema instead of repeating it, ended the class. The loop closed
on `review-enumeration.md`, 86 candidate lines with every owner checked.

## Measurement

Full suite 260 tests across 26 files, 0 failed, 0 skipped (`devtools::test()`, about 14 s), before
and after the review fixes; `test-crt_photo.R` 10 tests, integrity 16, schema meaning 13. Review:
plan review 0 blockers, then rounds of 2, 1, 2 and 4 findings, one inside a previous round's fix
(round 4). Blast radius of renaming `nge`: 48 files in crate plus callers in two other packages
(#68).

## Owed

- Tell the photo indexer's issue that the schemas are registered (released version, the two `file_name`s)

Closed by: PR (this branch, 67-photo-table-schema-one-row-per-photo-fil)
