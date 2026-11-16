# Findings — Photo-table schema: one row per photo file (#67)

## Issue context

**If we do it:** every package that lists, checks, copies or stores photos reads and writes
one shape, and a photo is identified by what its bytes are, not by what it is called. **If we
never do:** each one keeps its own columns, and a resized copy that shares its original's file
name goes on being mistaken for it.

## Problem

Photos from field surveys and camera traps are matched to the records that refer to them by
file name. A resized copy usually keeps the original's name, so a match by name cannot tell
them apart, and nothing records which copy came from which original. crate registers table
schemas (`crt_files()`, `crt_schema_conform()`), and has none for photos.

## Proposed Solution

Register a `schema_only` entry for a photo table, one row per file, which a caller conforms
its rows to with `crt_schema_conform()`:

| column | type | what it is |
|---|---|---|
| `path` | text | where the file is, as the caller gave it |
| `checksum` | text | SHA-256 of the file's bytes, in hex, the digest crate's receipts already carry for file parts |
| `size` | number | bytes |
| `record_id`, `site`, `view` | text | what the photo shows, from the caller's form or naming rule |
| `time` | datetime | when it was taken |
| `time_offset` | text | the offset from UTC, or missing where the camera wrote local time with none |
| `gps_lon`, `gps_lat` | number | where it was taken; missing once removed |
| `width`, `height` | integer | pixels |
| `media_type` | text | IANA media type |
| `camera` | text | make and model |
| `derived_from` | text | the checksum of the photo a copy was made from; missing for an original |

- **Key:** `checksum` with `path`. One file's bytes can sit at two paths, and both rows are
  kept.
- **Not in the schema:** where a photo is stored. A store defines its own key, and a row
  carries it in place of `path` once the photo is stored.
- **Camtrap DP:** its media table (1.0.2) has `filePath`, `fileName`, `fileMediatype`,
  `timestamp` and `exifData`, and no checksum or link from a copy to its original. These rows
  can fill a media table.

Questions for this issue: whether `record_id`, `site` and `view` belong in the photo table or
in a table that joins to it, and whether `time` is stored in UTC with the offset beside it.

Relates to #38


## Producer: a photo indexer in development

A photo indexer being built elsewhere reads a folder of photos into rows shaped for this schema and says it waits on crate#67. It asks that a time with no offset is never presented as UTC, and that site and view come from a caller rule, never guessed from names.

## Errors Encountered

| Error | Resolution |
|-------|------------|
