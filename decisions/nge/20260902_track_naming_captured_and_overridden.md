# A track's name is captured in the field, and annotations override it

**Date:** 2026-09-02
**Schemas:** `schemas/nge/track_sessions.yaml`, `schemas/nge/track_annotations.yaml`
**Amends:** `20260824_track_canonical_two_tables.md`, "Annotations separate"

## Decision

`nge/track_sessions` declares four crew-supplied columns — `track_name`,
`track_type`, `track_description`, `named_by` — as optional (`required: false`)
strings. They are captured: written once by the person who walked the track, at
the moment they stopped recording, and immutable after. A capture source without
them conforms and a reader yields `NA`.

`nge/track_annotations` is reshaped to mirror the first three of those columns,
same names and types, and drops `notes`. The rule, stated once and applying to
any future crew-supplied column: **a non-key annotation column — not `project`,
`session_id` or the `time_start_m` fingerprint — sharing a captured column's
name is an override of it.** At read time the override wins where it
is non-`NA` and the captured value stands otherwise —
`coalesce(annotation, captured)`.

`track_type` stays an open string. The allowed values are a convention of the
capture tool, recorded in the variant description, not an enumeration crate
enforces.

A layer carrying *some* of the four columns but not all is drift. crate cannot
detect it from the frame alone; the reader must abort on it.

## Trigger

rfp#186 added the four columns to the position-tracking layer it deploys
(`rfp_tracking_fields_add()`, `rfp_qgs_tracking_fields_add()`), so a crew can
name a session in the field rather than reconstructing it off a map weeks later.
Measured on a real project's layer: four sessions, three carrying a
crew-supplied name, all four a `track_type` and a `named_by`. trap's
`trp_track_read()` returned the canonical eleven columns and none of the four,
and nothing warned. `crt_schema_conform()` was doing what it was asked; the
schema was out of date.

The 2026-08-24 decision had put the human-supplied name in a separate table on
the premise that the capture shape is owned upstream and cannot be changed, so a
name cannot come from capture. rfp measured that premise against the installed
plugin's source and
found the augmentation safe — the plugin's own reconcile path is unreachable for
an rfp-deployed project, and it never enumerates or prunes columns. So the
premise no longer describes this source, and `track_sessions.track_name` and
`track_annotations.track_name` had become one field seen from two sides with no
rule saying which wins.

## Rationale

**Captured beats annotated, for anything a crew can say at walk time.** A
captured value is immutable, re-harvest safe by construction, needs no join and
no fingerprint, and was written by the person best placed to know. Annotation
is what remains: correcting a value typed wrong, and naming a session from a
source that has no naming fields — a layer the plugin created on its own, or a
GPX import.

**Same name means override.** The alternative spellings — a differently named
annotation column, or a rule that applies to `track_name` only — each need
their own paragraph, and each future crew-supplied column would need another.
One rule keyed on the name covers all of them and reads the way the data is
meant: not two fields, one field corrected.

**The coalesce is load-bearing, not cosmetic.** trap's `trp_track_annotate()`
carries every non-key annotation column onto sessions by plain assignment,
`sessions[[col]] <- annotations[[col]][idx]`. Once `track_sessions` has
`track_name`, that overwrites the captured name with `NA` for every session
nobody annotated. The precedence has to be written down here because two
readers implementing it differently would silently disagree about what a track
is called.

**Why reshape rather than accrete.** Measured on 2026-09-02: `trp_track_annotate()`
never branches on a column name; `trp_annotations_empty()` derives its columns
from crate's YAML; the GPX reader never carries a track's `<name>` into its
output — it reads it only for messages (rfp's `rfp_gpx_import()` rewrites
every name it touches, so a GPX name is an rfp-minted label, not a crew's);
the one live annotation table,
`working.trp_track_annotations`, was seeded empty and never written. Four
fixture rows across two trap test files and one example use `notes`. That is
the cheapest a reshape will ever be, and `notes`' stated job — "why a session
ended, whether it is a route or a bushwhack" — is exactly what the capture now
records under `track_type` and `track_description`. Keeping both would be the
same thing twice under two names, explained forever.

**`track_type` as an open string.** The value list has already changed once
between rfp's roxygen (`reach walk, bushwhack, access route, drive, other`) and
its shipped lookup (`day log, stream survey, bushwhack, access route, drive,
other`, default `day log`). Owning it here would make every field-app tweak a
crate release, and enforcing it needs the `enum` slot `crt_schema_validate()`
reserves but does not implement. Declaring the column typed and carried, with
the current list recorded as convention, is what the data needs today.

**Optional, not required — and what that does not mean.** A source without the
four is still a complete session — the plugin's own layer, every historic GPX.
`required: true` would refuse a bare plugin-shaped frame handed straight to
`crt_schema_conform()`. The bcfp schema's metadata columns are the precedent,
and the registry row keeps listing required columns only, as bcfp's does.

But `crt_schema_conform()` does not invent an absent optional column: a
plugin-shaped frame conforms to eleven columns, an rfp-shaped one to fifteen.
Two canonical frames with different column sets would drift the moment they
were stacked, and trap already asserts that a GPX-read and a Mergin-read
session have identical names. So the canonical table **always carries all
four**, and it is the reader's job to emit them `NA`-filled when the source
lacks them. `required: false` exists so a frame conforms without them; it is
not permission to leave them out of the table. The alternative — `required:
true` with the reader filling `NA` — was rejected only because it would refuse
the bare frame; the reader obligation is the same either way.

**`required: true` on the override side is presence, not value.** The
annotation table is ours, so its shape is fixed rather than a floor: a writer
that drops `track_type` has changed the contract, and the coalesce downstream
would silently never fire for it. Every value may still be `NA`. The asymmetry
with the captured side is deliberate — one table's columns are dictated by
sources we do not control, the other's by us.

**`NA` means no override, and `""` is `NA`.** A text widget opened and cleared
writes an empty string; a reader normalises it to `NA` before coalescing.
Consequently a captured value can be replaced but not erased — there is no
override *to* blank. Nothing needs that today; if something does, it is a new
column with its own semantics.

**Partial set is drift, and crate cannot enforce it.** A plugin-only layer
legitimately has none of the four; a deployed layer that lost one has been
altered. "Partial" means some but not all of the four *present as columns* in
the source layer — an rfp layer where every `track_name` was left blank is
complete, not partial. `crt_schema_validate()` is per-column with no
all-or-none grouping, and `crt_schema_conform()` sees a frame, not a variant,
so it cannot tell "none" from "some" in any principled way. The reader can —
it has the file — and the variant description says so. A variant-aware conform
would need an all-or-none declaration key on the column group; that is the
shape to propose if the reader-side check proves insufficient.

**`named_by` has no override.** Who named a session at capture and who
corrected it afterwards are two different claims. The second is
`annotated_by`, already reserved in `track_annotations`' `forward_compat`, and
still deferred for the reason given there: nothing reads it yet.

## Alternatives considered

- **Rename the annotation column** (e.g. `track_name_override`). Rejected: it
  makes the override relationship a naming convention a reader has to know,
  where sharing the name makes it the obvious reading. It also leaves `notes`
  and `track_description` as two free-text fields with different provenance.
- **Drop `track_name` from annotations, captured only.** Rejected: loses the
  ability to correct a field typo, and loses the only naming path for sources
  with no captured naming — plugin-only layers and every GPX track.
- **Keep `{track_name, notes}`, coalesce `track_name` only.** The minimal
  change. Rejected for the reshape because nothing exists to break and two
  vocabularies for one idea would be explained at every reading.
- **crate owns `track_type`'s values, declared or enforced.** Rejected: see
  above. Enforcing is a new feature; declaring without enforcing is a list
  that will drift from the tool that actually constrains the widget.
- **Variant-aware conform now** — `crt_schema_conform(df, ..., variant =)`
  checking the frame against a named variant's column list. A real feature and
  roughly the size of this issue again. Deferred; the partial-set check lives in
  the reader until then.

## Consequences

- trap: `trp_track_annotate()` must coalesce rather than assign, normalising
  `""` to `NA` first; `trp_track_read()` and `trp_track_read_gpx()` must always
  emit all four, `NA`-filled where the source lacks them, and the Mergin reader
  must abort on a partial set; fixtures and the example move from `notes` to
  the three override columns; `working.trp_track_annotations` (empty) is
  reseeded in the new shape; trap's crate pin moves past the release carrying
  this. `trp_annotations_empty()` follows the YAML and needs no change.
- The fingerprint (`time_start_m`) stays required on the override path even
  though captured naming needs none. An override is keyed on `session_id`,
  and that key is only sound within one file lineage.
- rfp: the roxygen table on `rfp_tracking_fields_add()` disagrees with the
  shipped lookup and should be regenerated from it.
- A GPX-sourced session has `NA` in all four columns, and is named only by
  annotation. Adding a captured name for GPX would mean rfp stopped rewriting
  track names on import, which is rfp's call.
- The "captured tables are immutable and capture-shaped; annotations are ours
  and live beside them" principle from 2026-08-24 stands. What changed is what
  capture can carry, not where edits live.

## References

- `schemas/nge/track_sessions.yaml`, `schemas/nge/track_annotations.yaml`
- crate#18 — this decision
- rfp#186 — the four fields, and the safety argument for adding them
- `rfp/inst/lookups/rfp_tracking_fields.csv` — the field set's source of truth
- trap#14 — where the annotation table came from
- trap#28 — the consumer changes this decision requires
- rfp#255 — the roxygen/lookup disagreement found on the way
- `20260824_track_canonical_two_tables.md` — the decision this amends
