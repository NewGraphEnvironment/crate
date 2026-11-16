# A photo is its bytes, and what it shows is a second table

**Date:** 2026-11-16
**Schemas:** `schemas/nge/photo_files.yaml`, `schemas/nge/photo_links.yaml`

## Decision

A photo canonicalizes to two `schema_only` tables. `photo_files` has one row per file:
its path, the SHA-256 of its bytes (`checksum`), its size, and what the file says about
itself: time, position, pixels, media type, camera, and `derived_from`, the checksum of
the photo a copy was made from. `photo_links` has one row per thing a photo shows, a
form record or a site and view, joined to the file on `checksum`.

1. **Identity is the checksum.** The key of `photo_files` is `(checksum, path)`: one
   file's bytes at two paths are two rows. A resized copy that keeps its original's name
   has its own checksum, and its `derived_from` names the original.
2. **What a photo shows is its own table.** One photo can show several records, and a
   file at two paths would otherwise repeat its links. A link to a form record carries
   the whole form-record key, `(project, form, source_version, record_id)`, because a
   rebuild of a capture layer restarts `record_id` at 1 (`form_capture.yaml`).
3. **Time is three columns.** `time` is an instant in UTC, missing whenever the camera
   wrote no offset; `time_local` is the wall clock as text, as the file wrote it;
   `time_offset` is `+HH:MM` or `-HH:MM`, or missing. A wall clock with no offset names
   no instant, so it is never stored as one.
4. **Position is `gps_lon`, `gps_lat`.** The prefix says it is the camera's fix, which
   need not be where the record it shows was made. A photo's GPS is always WGS84, so no
   CRS column.
5. **`path` is required, and where a photo is stored is not in the schema.** A store
   keys and lists its own copies and joins here on `checksum`, rather than putting its
   key in place of `path`.

## Trigger

Photos from field surveys and camera traps are matched to their records by file name,
which cannot tell a resized copy from its original, and nothing recorded which copy came
from which. A photo indexer being built for this repo's ecosystem (a folder in, a row
per file out) needs a shape to write to.

## Rationale

- The checksum is the digest a provenance receipt already carries for each file part
  (`result.parts.<path>.sha256`), so a receipt listing a photo and this table agree on
  the string, and `size` is that part's `bytes`.
- Track vertices carry `time` as a UTC instant (`track_vertices.yaml`). A photo's `time`
  in the same form joins to a track position directly; one stored as a wall clock would
  need every consumer to resolve it, and one guessed into UTC would join to the wrong
  vertex by whole hours with nothing reported.
- `crt_schema_apply()` refuses ISO text with a non-UTC offset in a `datetime` column, but
  reads text with no zone as UTC. So the caller resolves `time` itself, and never passes
  `time_local` to it; the column notes say so.

## Alternatives considered

- **`record_id`, `site` and `view` in the photo table**, as the issue first drafted:
  simpler, but one photo could show only one record per row, and a file at two paths
  repeats its links. Rejected at the plan gate.
- **`time` in UTC with the offset beside it and no wall-clock column**: a camera that
  wrote no offset would need its zone assumed to fill `time`. Rejected.
- **`time` as a wall clock only**: no instant to join on. Rejected.
- **`x`, `y`** as on `track_vertices`: consistent column names, but they lose the
  statement that this is the camera's fix. Rejected at the plan gate.
- **A column for why a file could not be read**: an indexer reports unreadable files as
  rows. Left to the producer; a schema is a floor, and extra columns pass
  `crt_schema_conform()`.

## Consequences

- `crt_schema_conform()` checks required columns are present, not filled. The
  `identified` grade on `photo_files` (`checksum`, `path`, `size` all present) and the
  `record` grade on `photo_links` (`project`, `form`, `record_id` present) are how a
  reader asks which rows it can trust. `record` does not require `source_version`, which
  form_capture leaves missing where a record has no versioned upstream; a join on the
  full key then has to match missing to missing.
- Nothing checks that `time` equals `time_local` less `time_offset`; the caller
  guarantees it, and a QC rule for it belongs with #38.
- Camtrap DP 1.0.2's media table can take `filePath`, `fileName`, `fileMediatype` and
  `timestamp` (from `time_local` and `time_offset`) from these rows. Its deployment and
  capture identifiers come from elsewhere, and a row with no offset has no timestamp
  there.

## References

- crate#67 (this schema), #38 (data consolidation umbrella)
- `schemas/nge/form_capture.yaml` (the form-record key), `schemas/nge/track_vertices.yaml`
- [Camtrap DP 1.0.2](https://camtrap-dp.tdwg.org/)
