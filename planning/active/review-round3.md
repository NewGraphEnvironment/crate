# Code-check round 3: branch 67 (ecadfc6...HEAD, at 5dfe315)

## Checklist read

- code-check-python.md: read in full.
- code-check.md: read the prose of every H3 under `## Mechanisms`, skipping table rows: "A guard that fails toward pass", "A fixture that cannot reach the failure mode", "A proxy is not the property", "Verification that reads its own output", "A guard's scope, escape hatches, and remedies", "A fix lands in one of two callers that share a harness", "Restore the bug and prove the guard fires", "A shared working tree, and what generators leave in it", "A wrapper's exit is not the work", "Zero-length, empty, and unset are three different things", "The probe is broken before the world is", "Written data outlives the fix", "Serialization loses meaning silently" and "One fact derived twice". Also read "Bare `y`, `n`, `on`, `off`, `yes`, `no` are booleans in YAML 1.1" and "An assertion that matches an interpolated value cannot see the claim around it". I skipped the other standalone headings and the Security and Spreadsheets/PDF headings (about 20), because nothing in the diff uses them.
- code-check-r.md, read by heading: "as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone", "as.POSIXct on character infers ONE format for the whole vector", "R's `yaml` returns a mixed int/float sequence as a list, not a numeric vector", "`match()` treats NA as a matchable VALUE, so two unknowns join to each other" and "`expect_false(identical(x, y))` cannot fail when the two are different types". I did not read about 125 others, because the diff uses none of their tools or shapes.
- code-check-spatial.md, read by heading: "An offset regex must be anchored to a time, or a date looks like a zone" and "A reader that accepts a UTC offset may not be applying it". I did not read about 95 others.
- code-check-shell.md: index only. The diff has no shell code, so I read 0 headings.

## The mechanism

All three earlier findings have one shape. A sentence restates a fact that another artifact owns, and that sentence is not executed against the artifact. The owners in those three were the code (`crt_datetime_parse_iso()`), another schema (`form_capture.source_version`), and the schema's own key. A fourth kind of owner reaches this diff as well: external specifications (EXIF and Camtrap DP). The two findings below come from that fourth kind. This is code-check.md, "A guard's scope, escape hatches, and remedies": a restatement that names a population through a universal quantifier or a member list, about an external system.

## Findings

- **[severity: fragile]** decisions/nge/20261116_photo_tables.md:27, and inst/extdata/schemas/nge/photo_files.yaml:86 and :95. Decision 4 says "A photo's GPS is always WGS84, so no CRS column." The `gps_lon` and `gps_lat` notes declare EPSG:4326 unconditionally. EXIF does not guarantee this. The `GPSMapDatum` tag names the receiver's datum, and the spec allows values other than "WGS-84", for example "TOKYO". The "always" is a claim about a third party's format, and it is the reason given for dropping a column. A producer that follows the notes writes the coordinates of a non-WGS84 fix as 4326, and nothing reports it. Nearly every phone and camera trap writes WGS-84, so the practical exposure is small. But the sentence is false as written. The fix is wording: "assumed WGS84; `GPSMapDatum` is not read or carried". Alternatively, the producer could refuse or flag a fix whose datum is not WGS-84.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies"

- **[severity: fragile]** inst/extdata/schemas/nge/photo_files.yaml:16-17, and decisions/nge/20261116_photo_tables.md:77. Both say a Camtrap DP media table takes "`filePath` from `path`". The Camtrap DP media schema (fetched 2026-11-16 from camtrap-dp.tdwg.org/data/#media) defines `filePath` as "URL or relative path to the media file, respectively for externally hosted files or files that are part of the package". Its pattern, `^(?=^[^./~])(^((?!\.{2}).)*$).*$`, rejects a value that starts with `/`, `.` or `~`, or that contains `..`. The `path` notes in this same schema say `path` is "as the caller gave it… Not normalised". So an absolute path, a `./` path or a `../` path is valid here, but it produces an invalid Camtrap DP `filePath` when the stated mapping is applied directly. The description already marks other parts of the mapping as partial: the missing offset and the identifiers. This condition is left out. Add "when `path` is relative to the package root (Camtrap DP refuses an absolute path, a leading `.` and `..`)".
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies"

## Restatements checked against their source of truth (no finding)

photo_files.yaml:
- The description says the key is `(checksum, path)` and a store joins on `checksum`. This agrees with decisions 1 and 5 and with CLAUDE.md.
- The description says Camtrap DP has a required `timestamp` in ISO 8601 with a zone (`Z` or `±hh:mm`). The fetched schema agrees: `time_local` followed by `time_offset` (`+HH:MM`) fits it, and a row with no offset has none. It also says `fileMediatype` comes from `media_type`. The schema's pattern is `^(image|video|audio)/.*$`, and `image/jpeg` and `image/png` fit. The media table's required `mediaID` and `deploymentID`, and its required `filePublic`, are covered by "part of" and "identifiers come from elsewhere". Camtrap DP has no checksum field and no field linking a copy to its original; the schema confirms both.
- `checksum` says it is the same digest as a receipt's `result.parts.<path>.sha256`. In `receipt_parts()` (R/crt_receipt_write.R:410-415), the entries are named by their relative path and hold `sha256 = digest(file = TRUE)` (lowercase hex). That holds.
- `size` says it is a receipt's `bytes`. That holds: `bytes = file.size(f)`, a double. The note that an R integer stops at 2^31 - 1 (about 2.1 GB) is correct.
- `time`: R/crt_schema_apply.R:156-170 refuses text carrying a non-UTC offset. Text with no zone is parsed as UTC. A POSIXct is stamped, not converted. The note matches each of these.
- `time_local`: in R 4.5.2, `as.character()` of a POSIXct gives `"2024-07-14"` at midnight and `"2024-07-14 10:32:05"` otherwise, with no `T`. A `string` column goes through `as.character()` (crt_schema_apply.R:70). That holds.
- `relative_to`, `range`, `units` and `'null'` are all documented keys (schemas/README.md:28-37), and `range` is a declaration only.

photo_links.yaml:
- `project`, `form` and `record_id` say they match the form_capture columns of the same names. True.
- `source_version` says a rebuild restarts `record_id` at 1. That is true per form_capture.yaml's `source_version` and `record_id` notes. Its `'null'` note says "no versioned upstream, as in form_capture", which is what form_capture's note says. It also says SQL `=` does not match NULL to NULL and `IS NOT DISTINCT FROM` does. True.
- `record_id` says it is "unique within `(project, form, source_version)`". This is consistent with form_capture's `source_version` note.
- The grade `record: [checksum, project, form, record_id]` is evaluated by `crt_schema_grade_eval()` as present and non-NA.

Decision log:
- Decisions 1, 2, 3 and 5 agree with the YAML.
- The rationale's bullets on the receipt digest, `track_vertices.time` and `crt_schema_apply()` refusal agree with the code and with track_vertices.yaml.
- The alternatives on `x`, `y` and the extra column ("extra columns pass") agree with `crt_schema_validate()`, which checks presence only.
- Consequences: "checks required columns are present, not filled" holds, as does "`record` does not require `source_version`". #38 is the consolidation umbrella and #68 the rename; the titles were checked through gh.
- "EXIF's own `YYYY:MM:DD HH:MM:SS`" is right for DateTimeOriginal.

CLAUDE.md:
- The Status line says `photo_files` is "one row per file, keyed by path and the SHA-256 of its bytes". That holds.
- Both entries are in `crate_registry.csv` as `schema_only`, and their `canonical_cols` are the required columns. The integrity test only asks for a subset, which holds.

Test comments:
- "registry-integrity guards already walk every schema": true, since the integrity file loops over `crt_registry_load()`.
- "an unversioned upstream still names a record" agrees with the grade.
- "A site-only link… conforms without a record" is true: only `checksum` and `project` are required. The block evaluates the grade only, so this comment is not executed there.

task_plan.md:
- `form_capture.yaml:36–67` spans `record_id` through the `source_version` identity note. It still resolves.

Private references:
- No added line names or links a private repo or a host. The three "camera trap" hits are the domain term.

## Observations, not findings

- decisions/nge/20261116_photo_tables.md:71 lists the `record` grade as "(`project`, `form`, `record_id` present)" and leaves out `checksum`, which the grade also requires. The code is stricter than the sentence, so nobody is misled into trusting a row they should not.
- The body of issue #67 still says a store's key goes "in place of `path` once the photo is stored", and its table still has `record_id`, `site` and `view` in the photo table. Decisions 5 and 2 reverse both points. This is outside the diff; `/gh-pr-merge` step 3b reconciles the body.
