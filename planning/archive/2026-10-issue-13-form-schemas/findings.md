# Findings — Canonical schemas for field forms: vintage in columns, not filenames (#13)

## Issue context

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

## Proposed

Canonical schemas under `inst/extdata/schemas/nge/` for the field-form family, written on **what the
columns mean**, not on which vintage produced them.

### Start from the field definitions the forms are built from

> **Added 2026-10-30.** The forms are not hand-built. Most are generated from a per-form CSV with
> one row per field, which is the only place today that says what each field is. Writing these
> schemas from scratch beside those CSVs would create two definitions that drift.

Each CSV row mixes two kinds of fact, and only one belongs here:

| belongs in crate: what the column means | stays with the form builder: how the form shows it |
|---|---|
| `field`, `type`, `help`, units, the allowed values in `options` | `widget`, `group`, `order`, `label`, `default` and `constraint` expressions, `read_only` |

So the schemas here take the meaning columns from those CSVs. The form builder then reads meaning
from crate and keeps only the rendering. Its rebuild test, which regenerates the deployed forms
byte-for-byte, is what makes that move safe. A few forms were never generated from a CSV and exist
only as captured QGIS styles; for those, the measured column inventory is the starting point.

### Scope: the fish passage family first

`pscis`, `fiss_site`, `monitoring_fish_passage`, `monitoring_general` and `monitoring`, because
those are the forms with a season waiting to be harvested. The `pscis` and `fiss_site` CSVs already
rebuild the deployed forms byte-for-byte, which makes them the cheapest to land. The
vegetation-inventory QA case above stays the worked example of two vintages, and its domain question
is #22.

### Vintage as columns, not filenames

Every record carries the `nge/form_capture` envelope (#14): `project`, `form`, `record_id`,
`source_version`, `schema_version` and `captured_at`. A schema change is then a column that is null
for older vintages, and `schema_version` explains why, so the null becomes interpretable.

> **Corrected 2026-10-30.** This said every record carries `captured_at`, `schema_version` and
> `source_project`, and the note below said the envelope had five columns. The envelope that shipped
> has six, and it names the source `project`.

**`schema_version` is a fingerprint, not a declared version.** `nge/form_capture` defines it as
`<n>-<digest>` over the sorted `name:type` pairs of the columns actually captured. That works for
stacking vintages, but on its own it cannot say which build of a form a record came from. So each
per-form schema also lists that form's known versions, each with the fingerprint a capture of it
produces. A fingerprint then names its version, for forms already in the field back to 2023, with no
change to the deployed forms. A fingerprint not in the list is a new vintage, which is worth
flagging rather than guessing at.

> **Considered 2026-10-30:** having the form builder stamp a version into each form it generates.
> It is more direct, but it covers only forms built from now on, and it changes every deployed form
> file, which the sync service then pushes to every device.

> **Corrected 2026-09-01 (#14).** This originally also listed `harvested_at`. It must not be a
> column: it moves on every run, so it rewrites a consumer's snapshot bytes on every harvest with
> nothing behind the diff. That is the failure a snapshot manifest's no-op guard exists to prevent,
> and the same call already made there for the upstream source version. When a harvest ran is a
> property of the harvest, not of the observation. It is recorded in `nge/form_capture`'s
> `forward_compat` with the reason, so it is not re-proposed.

> **Measured 2026-09-01 (#14).** The permissive-schema model below assumes a narrower vintage is a
> subset of a wider one. It holds for the case above: **zero** of the 28 captured columns were absent
> from the 52 (29 and 53 counting geometry). It is not guaranteed for a form whose columns were ever
> *renamed*, which is what #6 is about.

### Permissive schema, strict question

Fields added mid-season are `required: false`, so an earlier vintage conforms with nulls rather than
failing validation. Whether a record can answer a given question is a **separate predicate**, not a
property of the schema. In the case above, a record is *harvestable* if it has identity and position,
and *audit-grade* if it also carries the provenance fields. That keeps the earlier vintage without
silently counting it as something it is not.

Getting this backwards in either direction is the trap. `required: true` on the new fields makes the
older vintage unharvestable, and a schema with no notion of grade makes it silently equivalent.

### Allowed values are QC rules

A dropdown's `options` are the field's vocabulary. Carried into the schema, they are also the check
that catches a value typed or dictated outside it, such as a near-miss from speech-to-text in a free
field. Those checks belong with the QC rules in #1, and should flag a record, not fail it.

### Photo references travel with the record

Photo columns hold capture-relative paths (`<subdir>/<file>.jpeg`). A conform step that carries the
rows and not the assets produces dangling references. The schema should say what those paths are
relative to, so the store can resolve or rehost them rather than guess.

## Acceptance

- Schemas registered for the fish passage form family, each documenting units, vocabulary and what a
  null means, with meaning taken from the existing field CSVs rather than restated.
- Each schema lists its form's known versions with their fingerprints, and an unknown fingerprint is
  reported.
- Two vintages of the same form conform to one canonical table, distinguishable by `schema_version`.
- A record from the narrower vintage validates, and is correctly excluded by the grade predicate.
- The grade predicate is tested against a fixture that can actually fail it. A fixture where every
  row passes proves nothing.
- Allowed values are exposed so a QC rule (#1) can flag a value outside them.

Sub-issue of #1. Sibling of #6: the same reconciliation problem, a different dataset family.

---

**Partially unblocked 2026-09-01.** `nge/form_capture` (#14, crate v0.2.0) declares the envelope, so
a harvest can start before this issue lands. It deliberately says nothing about what any form column
means, which is still the whole of this issue. See
[the decision entry](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20260901_form_capture_envelope.md).

Consumers: the capture store's form harvests, the first done in 2026-09 and the 2026 fish passage
season next; and the form builder, which reads meaning from here once these land.


## trap's fingerprint hashed R's serialization (2026-10-30)

`trp_schema_version()` (trap `R/trp_form_read.R:348`) calls `digest::digest(pairs, algo = "xxhash64")`.
digest's default `serialize = TRUE` hashes R's serialization of the length-1 string (format v2,
header skipped by `skip = "auto"`), not the string. Measured on rfp's shipped form_pscis:
serialized `36743b027ac0c93f`, plain `c084e87fbf17e20e`. Published XXH64 vectors
(`""` -> `ef46db3751d8e999`, `"abc"` -> `44bc2cf5ad770999`) match digest with `serialize = FALSE`.
No trap code or test pins a value (`git grep '[0-9]+-[0-9a-f]{16}'` over R/tests/data-raw/inst: 0);
stored values live in five restricted form tables. User chose the plain string.

Declared types in rfp's shipped GPKGs include `MEDIUMINT` for integer fields (a known rfp issue), so the
fingerprint is over declared SQLite types, not crate types: pscis = 51 TEXT, 27 REAL,
19 MEDIUMINT, 2 DATETIME.

## Mutation table (2026-10-31, in a scratch copy of the tree)

Each new guard, with its defect restored, fails its tests:

| defect restored | filter | result |
|---|---|---|
| a form schema's envelope `schema_version` made optional | registry_integrity | FAIL 1 |
| a listed fingerprint off by one hex digit | form_schemas | FAIL 3 |
| a grade requiring an undeclared column | registry_integrity | FAIL 1 |
| grades checking column presence only | schema_meaning | FAIL 3 |
| conform not checking fingerprints | form_schemas | FAIL 1 |
| fingerprint hashing R's serialization again | schema_fingerprint | FAIL 3 |
| an unquoted `Yes` in `values` | registry_integrity | FAIL 1 |

## Code-check convergence (2026-10-31)

Round 2 found a defect inside round 1's fix (the NULL choice matched by its editable label),
so the loop ended by enumeration, not by a quiet round. Round 3 named the mechanism: **a derived
value depending on more than its input** — the session (locale, `digits`) or upstream's current
spelling (a default label, a sentinel number, a column name standing for a primary key).

Set (a), every "no value" representation the derive recognises or emits (27 rows, review-round3.md):
one defect (YAML precision from `getOption("digits")`, fixed); four proxies closed after round 3
(row id by `pk` not the name `fid`; `Label = code` trimmed as rfp trims; ±DBL_MAX as an unset
range; ASCII upper-casing of declared types in the derive); one divergence recorded, not fixed:
a blank checkbox state is dropped where rfp would store `""` (none occurs at the pinned SHA).

Set (b), every point in the branch where text becomes bytes or is compared as bytes (enumerated by
grep over `git diff base...HEAD -- R data-raw` for toupper/sort/digest/write*/read*/yaml/enc2/
Encoding/match/%in%/regex): fingerprint names (marked, round 2), fingerprint types (chartr, round 3),
radix sort (bytes in en_US and C, measured), YAML writes (UTF-8 locale enforced), schema reads
(`crt_schema_read()` reads bytes as UTF-8, round 3 — predates the branch), derive `toupper` on
declared types (chartr, after round 3), fixture CSV reads (ASCII, and names re-marked by the
fingerprint), fingerprint `match()`/`%in%` (ASCII hex). All hold. Suite passes under `LC_ALL=C`
and `en_US.UTF-8` (1201 each); derive re-run under `options(digits = 4)` changes no file.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| monitoring dropdowns carried QGIS's `map` wrapper as a choice, `value: .na.character` | Found by the Phase 5 QC test. xpath now takes descendant Options with both `name` and `value`; integrity guard tightened, since yaml reads `.na.character` back as a character NA and `is.character()` passed it |
