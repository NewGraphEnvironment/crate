# GPS tracks canonicalize to two tables, and annotations to a third

**Date:** 2026-08-24
**Schemas:** `schemas/nge/track_sessions.yaml`, `schemas/nge/track_vertices.yaml`,
`schemas/nge/track_annotations.yaml`
**Amended by:** [`20260902_track_naming_captured_and_overridden.md`](20260902_track_naming_captured_and_overridden.md) —
the "Annotations separate" premise that a capture shape cannot carry a name no
longer holds for an rfp-deployed layer; the two-table layout stands, the
annotation table becomes overrides.

## Decision

A GPS track canonicalizes to **two** tables — `track_sessions` (one row per
session) and `track_vertices` (one row per recorded position) — both
non-spatial, with X, Y, Z and the timestamp as ordinary columns. Human-supplied
fields live in a **third** table, `track_annotations`, keyed on
`(project, session_id)` and carrying a timestamp fingerprint.

All three are registered `kind = schema_only`: crate declares what the columns
mean, and the caller supplies the data via `crt_schema_conform()`.

`project` and `session_id` are defined in source-neutral terms rather than in
the vocabulary of the tool that happens to capture tracks today.

## Trigger

The first store built on these tables had the column definitions living in its
reader — twelve columns, their types, and `clock_delta_start_s`, which is not a
passthrough at all but a claim about the relationship between two clocks. That
is a statement about meaning, so it belongs here.

The same work needed somewhere to put a track's name, which the capture schema
has no room for.

## Rationale

**Two tables, not one.** A session has one row's worth of facts and thousands of
positions. Nesting the positions inside the session row would make the common
query — where was someone at a given instant — a nested read, and would put a
list column in every columnar export. Splitting them costs a join that both
tables carry the key for.

**Non-spatial.** Keeping X, Y, Z and the time as ordinary columns means the
geometry is reconstructable from `track_vertices` and nothing is lost, while
both tables serialize to columnar formats without a spatial dependency in the
read path.

**The vertex timestamp is authoritative.** Capture sources typically carry a
per-vertex timestamp *and* session-level start/end attributes. Measured on a
tracking GeoPackage on 2026-08-24, the two agree to within a second — the
attribute times are stored as ISO 8601 with an explicit `Z`, and the per-vertex
timestamps are UTC epoch seconds for the same instants.

They can nonetheless *appear* to disagree by whole hours, because a reader that
returns the attribute column with an empty timezone renders it in the session's
local zone. That is a rendering artifact, not a second clock, and "correcting"
it injects a real offset into every downstream join. Hence `type: datetime`
stamps the timezone rather than converting it, and hence `clock_delta_start_s`
and `clock_delta_end_s` are canonical columns: they carry the evidence that the
two clocks agreed, so a capture source that one day starts writing local time
shows up as a number rather than as a quiet offset in a year of joins.

**Captured versus canonical.** The capture shape is owned upstream and cannot be
changed. It is recorded as an `upstream_variant` so a reader has something to
check itself against, and so a second capture source — a GPX file from an
earlier season — can be added as a second variant against the same canonical
shape. That is why `project` and `session_id` are defined as "the dataset the
track came from" and "an id unique within it": a name tied to one tool's
vocabulary would have to be changed the first time a second tool appeared.

**Annotations separate.** A name cannot come from capture, so it must be applied
afterwards. Two options were available:

1. an annotation table joined at read time, or
2. building the sessions table and swapping it into place on each rebuild.

(2) works and is what an earlier system did, but it makes every future rebuild a
thing that has to be done carefully, and the cost is paid forever by whoever did
not know. (1) is re-harvest safe by construction: a harvest only ever writes the
captured tables.

**The fingerprint.** `session_id` is carried from the capture source rather than
reassigned, which raises whether it is stable. For a GeoPackage the identity
column is `INTEGER PRIMARY KEY AUTOINCREMENT`, so a deleted id is never
reissued — measured on 2026-08-24, a layer whose sequence stood at 6 with ids
2–6 present, id 1 having been deleted and not reused. So the key is sound.

But that guarantee holds only within one **file lineage**. A layer rewritten by
another tool restarts the sequence at 1, and every annotation would then point
at a different session with nothing to indicate it. The counter-example was
already sitting in the consuming repo: a test fixture derived from that same
layer carries ids 1 and 2, because writing it out renumbered them.

Copying `time_start_m` onto the annotation and comparing it at join time turns
that from silent mis-attribution into an abort. It costs no column that did not
already exist on the session.

## Alternatives considered

- **One table with nested vertices.** Rejected: see above.
- **Keeping the schema in the reader.** Rejected — it is the thing this repo
  exists to stop, and the reader was already inventing semantics rather than
  passing them through.
- **`source: mergin`.** Rejected. The data is ours, captured through a tool; the
  tool is a variant, not the family. Naming the family after today's capture
  tool would misfile every historic track.
- **A content hash of the vertex sequence as the fingerprint.** Stronger, and
  rejected as more than the failure needs: `time_start_m` is already present,
  already unique in practice, and a renumber changes it.
- **`annotated_by` / `annotated_at` now.** Deferred, and recorded in the
  schema's `forward_compat` so it reads as a decision rather than an oversight.

## Consequences

- A reader supplies the frames; crate validates and types them. Column meanings
  live in one place and a reader that drifts fails loudly.
- `crt_ingest()` cannot serve these entries. It reads CSV and maps one file to
  one table, and teaching it to read spatial formats would put file-format
  knowledge in a schema repo. `kind = schema_only` makes that explicit and
  `crt_ingest()` aborts on it naming `crt_schema_conform()`.
- A harvest that writes the annotation table is a bug, not a merge conflict.
  The separation is only as good as that rule being kept.
- Adding a GPX capture source later is a new `upstream_variant` and a reader,
  not a schema change.

## References

- `schemas/nge/track_sessions.yaml`, `schemas/nge/track_vertices.yaml`,
  `schemas/nge/track_annotations.yaml`
- crate#9 — `crt_schema_conform()`, the `datetime` type, and `schema_only`
  registry entries
