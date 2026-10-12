# Changelog

## crate 0.6.1 (2026-10-12)

Every PR and every push to `main` now runs `R CMD check` and the whole
test suite
([\#11](https://github.com/NewGraphEnvironment/crate/issues/11)). Before
this, nothing ran the suite in CI.

- The check fails on warnings. Every run prints its skipped tests, and a
  skip for a reason other than the six expected ones adds a warning to
  the run summary.
- Those six tests need the source tree, which `R CMD check` does not
  have, so a second pass runs the suite from the checkout, where any
  skip fails the run.
- `CITATION.cff` is no longer in the built package.

## crate 0.6.0 (2026-10-11)

`lidarbc` v1.1.0 adds `lidarbc:datetime_unknown`, a boolean that is
`true` when neither LidarBC’s file name nor its path carries a date, so
the item’s `datetime` is a placeholder. stac-elevation-bc’s 2,288 albers
items will carry it once their rewrite
(NewGraphEnvironment/stac_dem_bc#2) publishes. The schema is at
`https://newgraphenvironment.github.io/crate/stac/lidarbc/v1.1.0/schema.json`
([\#26](https://github.com/NewGraphEnvironment/crate/issues/26)).

- v1.0.0 is unchanged and stays published for the items that name it.
  This is the first version added under the never-edit rule.

## crate 0.5.0 (2026-10-10)

crate now publishes JSON Schemas for the custom fields NGE’s STAC
catalogues write, starting with `lidarbc:` (LidarBC’s objectstore paths
and file names) and `las:` (the LAS format’s version and point format),
at
`https://newgraphenvironment.github.io/crate/stac/<prefix>/v1.0.0/schema.json`
([\#23](https://github.com/NewGraphEnvironment/crate/issues/23)).

- An item lists the URL in `stac_extensions`, and pystac then checks
  each field’s type: a point format of 11 or an unknown `lidarbc:` field
  fails validation.
- A released version is never edited. A change is a new version beside
  it, and the site build fails if a version already on `gh-pages` would
  change or disappear. See the [decision
  entry](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20261010_stac_field_schemas.md).

## crate 0.4.0 (2026-09-02)

`nge/track_sessions` declares the four columns a crew fills in when they
stop recording — `track_name`, `track_type`, `track_description`,
`named_by` — and `nge/track_annotations` becomes the table of overrides
for them.

- The four are optional strings. An rfp-deployed tracking layer carries
  them (new upstream variant `mergin-tracking-rfp-2026-08`); a layer the
  plugin created on its own, or a GPX import, does not, and still
  conforms. A layer carrying some but not all is drift the reader must
  abort on — crate sees a frame, not a variant.
- `track_annotations` now carries `track_name`, `track_type` and
  `track_description`, same names and types as the captured columns, and
  drops `notes`. The rule, stated once: a non-key annotation column
  sharing a captured column’s name overrides it where non-`NA`,
  `coalesce(annotation, captured)`. A reader that assigns instead of
  coalescing blanks every unannotated session, which is why the rule is
  written down rather than left to each consumer.
- `track_type` is an open string; the value list is the capture tool’s
  convention, recorded in the variant description and not enforced. See
  the [decision
  entry](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20260902_track_naming_captured_and_overridden.md)
  for why captured beats annotated and why the annotation table was
  reshaped rather than extended.

## crate 0.3.0 (2026-09-01)

`nge/form_capture` gains `source_version`, the upstream version a record
was captured at.

- Deliberately a column rather than a consumer-side manifest field,
  which is the opposite of the usual rule. That rule exists because
  stamping the upstream’s *current* version on every row churns a
  snapshot’s bytes for reasons unrelated to the data; a per-row capture
  version is fixed at capture and never moves. It is also what keeps
  `(project, form, source_version, record_id)` unique once a rebuild has
  restarted `record_id` at 1.
- `schema_version` now documents **how it is computed** — `<n>-<digest>`
  over sorted `name:type` pairs of the capture’s own columns, hashing a
  joined string rather than a vector. Two producers computing it
  differently would give two genuinely different vintages the same
  version by accident, so the rule belongs with the declaration rather
  than with each caller.

## crate 0.2.0 (2026-09-01)

New `schema_only` entry `nge/form_capture`: the envelope every captured
field-form record carries — `project`, `form`, `record_id`,
`schema_version`, `captured_at` — and nothing about what any observation
means.

- Vintage is a column, not a filename. Two shapes of one form are one
  logical table, distinguished by `schema_version`; a column absent from
  the older vintage is null there and `schema_version` says why, which
  is what separates “not asked” from “not answered”.
- Per-form column meaning is still
  [\#13](https://github.com/NewGraphEnvironment/crate/issues/13). The
  envelope leans on
  [`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md)’s
  documented floor-not-ceiling behaviour, so a form’s own columns pass
  through untouched until
  [\#13](https://github.com/NewGraphEnvironment/crate/issues/13) defines
  them. See the [decision
  entry](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20260901_form_capture_envelope.md)
  for why an envelope rather than waiting, and why `harvested_at` is not
  a column.

## crate 0.1.0 (2026-08-24)

crate can now declare a canonical shape for data it does not read, and
can type a column as an instant.

- [`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md)
  takes a data frame you already have and holds it to a registered
  canonical schema.
  [`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
  calls it rather than reimplementing validation and typing, so a file
  and a caller-supplied frame get identical treatment.
- New canonical type `datetime`. It never moves an instant: a `POSIXct`
  has its timezone attribute stamped to UTC rather than converted,
  because several readers return correct UTC instants carrying no
  timezone label and “correcting” the rendering injects a real
  whole-hour error into every join.
- The registry gains a `kind` column. `schema_only` entries declare a
  shape crate does not read;
  [`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
  aborts on them naming
  [`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md).
- First `schema_only` entries: `nge/track_sessions`,
  `nge/track_vertices` and `nge/track_annotations`, the canonical shape
  of a GPS track. See the [decision
  entry](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20260824_track_canonical_two_tables.md)
  for why a track is two tables and why annotations are a third.
- `test-crt_registry_integrity.R` walks the registry and the schemas
  directory rather than a hand-written list, so a row without a YAML, a
  YAML without a row, or a declared type nothing implements fails the
  suite.

## crate 0.0.2 (2026-04-29)

Schema-as-contract scope settled and Convention C naming locked in (see
[crate#4](https://github.com/NewGraphEnvironment/crate/issues/4)).

- Every function in the crate namespace now prefixed `crt_*`,
  family-namespaced (`crt_schema_*`, `crt_registry_*`, `crt_handler_*`).
- New `crt_schema_*` family:
  [`crt_schema_read()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_read.md)
  (load YAML by relative path),
  [`crt_schema_apply()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_apply.md)
  (canonical type enforcement),
  [`crt_schema_validate()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_validate.md)
  (required-cols enforcement).
- [`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
  now validates required cols and enforces canonical types after handler
  dispatch — schema YAML is the single source of truth.

## crate 0.0.1 (2026-04-28)

Initial release. Source-explicit dispatcher (`crt_ingest`) plus
first-instance handler for `bcfp/user_habitat_classification` (handles
both pre-2026-04-26 long and current 2026-04-26 wide upstream variants →
canonical wide).
