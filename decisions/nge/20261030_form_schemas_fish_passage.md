# Fish passage forms get canonical schemas, derived from the form builder's definitions

**Date:** 2026-10-30
**Schemas:** `schemas/nge/form_pscis.yaml`, `form_fiss_site.yaml`,
`form_monitoring_fish_passage.yaml`, `form_monitoring_general.yaml`, `form_monitoring.yaml`

## Decision

The five fish passage field forms each get a `schema_only` entry, keyed
`nge/form_<name>`, so a captured record's `form` value is its schema's
`file_name`. Each schema declares:

- the six `nge/form_capture` envelope columns, verbatim, and the record's
  position (`x`, `y`, `source_epsg`) — these are the only required columns;
- every column of the form, all optional, with what it means: type, units,
  allowed values, range, what a file path is relative to, and when a null
  means something other than "not recorded";
- **grades**: `harvestable` (identity and position present) on every form, and
  `crew_attributed` on `form_monitoring`;
- the form's **known versions**, as `upstream_variants` carrying the
  fingerprint a capture of each produces.

`crt_schema_fingerprint()` is now the one definition of that fingerprint, and
it hashes the joined string's bytes rather than R's serialization of it.

## Trigger

#13, with two consumers waiting: the 2026 fish passage season's harvest, and
the form builder, which is to read what a column means from crate and keep only
how the form shows it.

## Why derived, not written

The forms are generated from per-form CSVs, one row per field, and those rows
are the only place that says what each field is. Writing schemas beside them
would make two definitions that drift. So `data-raw/forms_derive-schemas.R`
takes the meaning columns (name, type, help, units, options) from the CSVs at a
pinned commit and leaves the rendering ones (widget, tab, order, label,
expressions) with the builder. `form_monitoring` was never built from a CSV, so
its meaning comes from its captured style file and GeoPackage: types,
vocabularies and ranges, but no help, because that file carries none.

The script is a bootstrap. Once the builder reads meaning from crate, its CSVs
stop carrying it and these YAMLs are the source of truth.

Rules the derivation applies, each measured on the CSVs:

- **A dropdown with non-numeric choices is `string`**, whatever the CSV
  declares. Seven `fiss_site` method columns were declared `real` with text
  choices, so typing them as numbers would have made every value NA.
- **Units come from an allow-list, not any parenthesis.** 12 of the 23 labels
  ending in parentheses hold a scale or an example, not a unit. Where the label
  has none, the name's suffix (`_m`, `_percent`, `_m_s_cm`) supplies it, which
  is where the builder's own README says a field-local unit lives.

## Known versions are upstream variants with a fingerprint

`schema_version` describes a column set, so on its own it cannot say which
build of a form a record came from. Listing each form's known versions with the
fingerprint a capture of them produces names the version of forms already in
the field without changing a deployed form, which the sync service would push
to every device. Stamping a version into each form at build time was the
alternative: more direct, but it only covers forms built from now on.

They are recorded as `upstream_variants`, the concept crate already has for "a
shape this data arrives in", not as a new list. An unlisted fingerprint is
reported by `crt_schema_conform()` as a classed warning
(`crate_unknown_fingerprint`), not refused: a new vintage is something to
notice, and refusing it would stop the harvest that found it.

Measured 2026-10-30 across the four fish passage projects' live forms: every
2026 capture of `pscis`, `fiss_site`, `monitoring_fish_passage` and
`monitoring_general` carries the builder's column set. `form_monitoring` has
two shapes in the field, and they are **not nested**: the 2025 variant lacks
`surveyor_1`–`surveyor_3`, `habitat_comment`, `utm_corrected` and
`assessment_comments_og`, and carries `rowid`, `utm_zone`, `easting` and
`northing` instead. #14 measured the narrower vintage of one form to be a
subset of the wider; for this form that does not hold, which is the #6 rename
class. Both shapes conform to one table because every form column is optional,
and `schema_version` says which columns a record's form had.

Forms deployed under another name with the same columns (a project's
`form_pscis_newgraph`, for instance) carry the base form's fingerprint, so a
reader maps them to the base schema.

`form_monitoring` is the earlier, combined monitoring form, retired for new
work: `form_monitoring_fish_passage` and `form_monitoring_general` replaced it
in 2026 (the first writes one statement per metric where the old form rated
1 to 5). It is registered anyway, because projects still deploy it and earlier
seasons' records are in its shape. Its schema's description says so.

The 2023–2025 back-catalogue of earlier builds is not listed yet. Many of those
files are processed copies, whose column sets are not a form's, so they are to
be read from the sync service's version history instead.

## Why the fingerprint moved, and changed

It was computed only by the harvesting package, as `digest(pairs, "xxhash64")`.
digest serializes its input by default, so that hashed R's serialization of the
string — which the envelope's own notes say not to do, because a serialization
format can move without any schema change and no other language can reproduce
it. Measured on `form_pscis`: serialized `36743b027ac0c93f`, the string's own
bytes `c084e87fbf17e20e`. The new definition matches published XXH64 test
vectors. No code pinned an old value; the tables already harvested carry them
and are re-harvested once, and until then their fingerprints are reported as
unlisted. The test suite keeps one check of the old value, to prove the
`form_pscis` fixture is the column set measured in the field.

## Grades

Every form column is optional, so an earlier vintage conforms; whether a record
can answer a given question is a grade, a separate predicate. `harvestable`
needs `project`, `form`, `record_id`, `x` and `y` present: a record with no fix
cannot be placed. `source_version` is left out because it is NA where there is
no versioned upstream. `crew_attributed` on `form_monitoring` also needs
`surveyor_1`, which the 2025 variant does not have; it records its crew only in
free text, so it cannot say who did the assessment in a structured form.

Other domain grades belong to the QC rules (#1), not to this entry.

## What this does not decide

- `captured_by`: still in `form_capture`'s `forward_compat`.
- How a QC rule reports a value outside `values` or `range`: #1. This entry
  only declares them, and `crt_schema_cols()` exposes them.
- The 2023–2025 versions, as above.

## Related

- #13 — this entry
- #14 and `20260901_form_capture_envelope.md` — the envelope these repeat
- #6 — the same reconciliation problem for another dataset family
- #1 — QC rules that read `values` and `range`
