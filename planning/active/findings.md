# Findings — nge/track_sessions drops the four crew-supplied naming columns an rfp-deployed tracking layer carries (#18)

## Issue context

`nge/track_sessions` declares eleven columns. A Mergin Maps position-tracking
layer deployed through `rfp` carries **four more**, and a reader that conforms to
the canonical schema drops all four silently:

| column | what it holds |
|---|---|
| `track_name` | what the session was, typed in the field |
| `track_type` | value map — reach walk, bushwhack, access route, drive, other |
| `track_description` | free text |
| `named_by` | defaults to the Mergin username; who named it, where that differs from who walked it |

These are not drift. `rfp::rfp_tracking_fields_add()` adds them to the GeoPackage
and `rfp::rfp_qgs_tracking_fields_add()` gives them widgets in the project,
deliberately, so that a crew can name a session **at the time they walk it**
rather than reconstructing it off a map weeks later.

Measured on a real field project's tracking layer: four recorded sessions, three
of them carrying a crew-supplied name and all four a `track_type` and a
`named_by`. `trp_track_read()` returned the canonical eleven columns and none of
the four. Nothing warned — `crt_schema_conform()` is doing exactly what it is
asked to do, and the schema is what is out of date.

`trap` built a separate mutable annotation table (`nge/track_annotations`, with
its own `track_name`) on the reasoning that a capture schema is fixed by whatever
wrote it. That reasoning no longer describes this source. The two `track_name`s
are a genuine overlap rather than two independent fields.

Open questions from the issue: relationship of the two `track_name`s; who owns
`track_type`'s allowed values; whether a missing set should be reported.

## Where the drop actually happens (2026-09-02)

Not in crate. `crt_schema_conform()` passes undeclared columns through (documented
floor-not-ceiling; `R/crt_schema_conform.R:25-28`). The drop is in trap's
`trp_track_read()` (`R/trp_track_read.R:144-156`), which builds the sessions
tibble from an explicit column list. Declaring the four in crate is what gives trap
a contract to carry them under.

## rfp's source of truth for the four columns (2026-09-02)

`rfp/inst/lookups/rfp_tracking_fields.csv`, read by `.rfp_tracking_fields()`:

| field | type | widget | default | options |
|---|---|---|---|---|
| `track_name` | TEXT | text | | |
| `track_type` | TEXT | valuemap | `'day log'` | `day log\|stream survey\|bushwhack\|access route\|drive\|other` |
| `track_description` | TEXT | textmulti | | |
| `named_by` | TEXT | text | `@mergin_username` | |

The roxygen table in `rfp/R/rfp_tracking.R:526-530` is stale: three rows, and
`reach walk, bushwhack, access route, drive, other` for the value map. The issue
body quoted the roxygen. The CSV is what ships. → rfp follow-up issue.

## What trap and the GPX path use of `track_annotations` (2026-09-02)

- `trp_track_annotate()` (`R/trp_track_annotate.R:131-134`) carries every non-key
  annotation column by plain assignment `sessions[[col]] <- annotations[[col]][idx]`.
  It never branches on `track_name`. Consequence once `track_sessions` has
  `track_name`: an unannotated session's captured name is **overwritten with `NA`**.
  The coalesce precedence is load-bearing, not cosmetic.
- `trp_annotations_empty()` derives its columns from crate's YAML — follows a
  reshape automatically.
- `trp_track_read_gpx()` never reads the GPX `<name>`; mentions `track_name` only to
  explain why `session_id` is not name-derived. `rfp_gpx_import()` appends a surveyor
  suffix to every track name, so a GPX name is an rfp-minted label, not a crew-typed
  one. All four are legitimately `NA` for the GPX variant.
- Persistence: `trap/data-raw/track_hornby_2026.R:141-161` seeds an empty
  `working.trp_track_annotations` and never writes it again.
- Fixtures naming `notes`: `test-trp_track_annotate.R` (helper `annotation_for()`),
  `test-trp_track_read_gpx.R:389-402`, the `trp_track_annotate()` example.
- `trap/inst/testdata/tracking_layer.gpkg` is plugin-shaped (no four) — the case that
  must keep conforming.

## crate mechanics that constrain the change

- `test-crt_registry_integrity.R:95-108`: registry `canonical_cols` may be a subset
  of the schema but never name a column the schema lacks. Removing `notes` from
  `track_annotations.yaml` requires the registry row to change in the same commit.
- `bcfp/user_habitat_classification.yaml:39-54` is the `required: false` precedent;
  its registry row lists required columns only — `track_sessions`' row stays as-is.
- `crt_schema_validate()` honours `required: false` (`R/crt_schema_validate.R:40-41`);
  `crt_schema_apply()` types a column only when present. No R code change needed.
- `crt_schema_validate()`'s `enum` slot is reserved, not implemented — why
  `track_type` stays an open string without a new feature.

## Errors Encountered

| Error | Resolution |
|-------|------------|
