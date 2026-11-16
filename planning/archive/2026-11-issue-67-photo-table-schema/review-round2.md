# Code-check round 2 — branch 67 (ecadfc6...HEAD, at 915bf13)

## Checklist read

- code-check-python.md: in full.
- code-check.md: the prose of every H3 under `## Mechanisms` (table rows skipped): "A guard that fails toward pass", "A fixture that cannot reach the failure mode", "A proxy is not the property", "Verification that reads its own output", "A guard's scope, escape hatches, and remedies", "A fix lands in one of two callers that share a harness", "Restore the bug and prove the guard fires", "A shared working tree, and what generators leave in it", "A wrapper's exit is not the work", "Zero-length, empty, and unset are three different things", "The probe is broken before the world is", "Written data outlives the fix", "Serialization loses meaning silently", "One fact derived twice". Also "Bare `y`, `n`, `on`, `off`, `yes`, `no` are booleans in YAML 1.1". The other standalone, Security and Spreadsheets/PDF headings (about 20) not read: nothing in the diff uses them.
- code-check-r.md, read by heading: "as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone", "as.POSIXct on character infers ONE format for the whole vector", "`match()` treats NA as a matchable VALUE, so two unknowns join to each other", "R's `yaml` returns a mixed int/float sequence as a list, not a numeric vector". About 130 others not read.
- code-check-spatial.md, read by heading: "A reader that accepts a UTC offset may not be applying it" (and the index line of "An offset regex must be anchored to a time, or a date looks like a zone"). About 95 others not read.
- code-check-shell.md: index only. The diff has no shell code, so 0 headings read.

## What was checked

- Both round-1 fixes hold. In a detached worktree at HEAD: test-crt_photo 10/10, registry integrity 16/16, schema meaning 13/13, with 0 errors and 0 skips (NOT_CRAN=true).
  - Fix 1: `photo_links` grade `record` parses as `[checksum, project, form, record_id]`. The test's row with `source_version = NA` expects TRUE, so a revert to requiring `source_version` would turn it red.
  - Fix 2: `time = "2024-07-14T10:32:05"` conforms to `2024-07-14 10:32:05 UTC`, and an offset of `-07:00` is refused, which is what the reworded notes and rationale say. `+00:00`, `-00:00` and `Z` are accepted as UTC.
- `time_local` claim: `as.character()` of a midnight POSIXct gives `"2024-07-14"`, which drops the time (R 4.5.2), and a non-midnight one gives no `T`. Both match the note.
- The `source_version` `'null'` note is right that SQL `=` does not match NULL to NULL. R's `match()` and dplyr joins do, which here is the behaviour the note asks for.
- Other references hold:
  - `relative_to`, `range` and `'null'` are documented keys (schemas/README.md). The `'null'` keys are quoted and parse as `null`.
  - The registry `canonical_cols` are the required columns.
  - `track_vertices.time` is a required UTC datetime.
  - `form_capture.source_version` says "NA where there is no versioned upstream".
  - The receipt digest path, the issue numbers (#38 umbrella, #68 rename) and the decision files cited all exist as cited.
- No private repo is named or linked anywhere in the added lines. `wet` is public.

## Findings

- **[severity: fragile]** CLAUDE.md:25 (Status paragraph, added text). The Status line says "`photo_files` (one row per file, keyed by the SHA-256 of its bytes)". The schema's key is `(checksum, path)`: one file's bytes at two paths are two rows with the same checksum. photo_files.yaml says so in its description and in the `path` and `checksum` notes, and so does decision 1 in the decision log. CLAUDE.md is what a contributor or agent reads first. If someone builds a store or a Postgres table from that sentence and puts a unique key on `checksum`, the second path's row is rejected or overwritten, which is the case the schema exists to keep. Say "keyed by path and the SHA-256 of its bytes" (or "identified by" rather than "keyed by").
  - **Rule:** none

## Observations, not findings

- The decision log's decision 3 describes `time_local` as "the wall clock as text, as the file wrote it" and gives no format. EXIF writes `YYYY:MM:DD HH:MM:SS`. The YAML note (the contract) pins `YYYY-MM-DDTHH:MM:SS`, so nothing is wrong, but the Camtrap DP mapping (`time_local` with `time_offset` appended) gives an ISO timestamp only if producers follow the YAML rather than the decision log's shorter wording.
- Since round 1, the `record` grade passes a link whose `source_version` is NA even where the record does have a versioned upstream and the producer simply left it blank. A key join then matches nothing; it does not pick a wrong record, so this is not a defect.
- Already true before this branch: the Status paragraph lists wet's `segment_monthly` and `segment_daily` but not the registered `discharge/fwa/v1/watershed_*` entry. This branch did not introduce it.
