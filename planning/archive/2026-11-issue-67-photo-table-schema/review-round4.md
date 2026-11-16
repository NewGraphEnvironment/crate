# Code-check round 4 (#67)

Diff: `git diff ecadfc6...HEAD` at 078ebc5 (branch4.diff).

## Checklist read

- code-check-python.md: in full.
- code-check.md: prose of every H3 under `## Mechanisms` (A guard that fails toward pass; A fixture that cannot reach the failure mode; A proxy is not the property; Verification that reads its own output; A guard's scope, escape hatches, and remedies; A fix lands in one of two callers; Restore the bug and prove the guard fires; A shared working tree; A wrapper's exit is not the work; Zero-length, empty, and unset; The probe is broken before the world is; the remaining Mechanisms H3s skimmed by heading). Standalone: "Bare `y`, `n`, `on`, `off`, `yes`, `no` are booleans in YAML 1.1". Other standalone/Security/Spreadsheet headings not read (not used by this diff).
- code-check-r.md: read "as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone", "R's `yaml` returns a mixed int/float sequence as a list, not a numeric vector"; indexes of "as.POSIXct on character infers ONE format", "Tests that silently do not run", "testthat counts an uncaught error under `error`", "`nzchar(NA)` is TRUE" checked against the diff. Remaining ~115 headings not read (no matching tool or shape).
- code-check-spatial.md: read "An offset regex must be anchored to a time, or a date looks like a zone", "A reader that accepts a UTC offset may not be applying it". Remaining headings not read.
- code-check-shell.md: no heading read (the diff has no shell).

## Findings

- **[severity: fragile]** inst/extdata/schemas/nge/photo_files.yaml:17-18; decisions/nge/20261116_photo_tables.md:77-78. The round-3 fix (5) lists the filePath rule incompletely. Camtrap DP 1.0.2's `filePath` pattern is `^(?=^[^./~])(^((?!\.{2}).)*$).*$`, fetched from `tdwg/camtrap-dp@1.0.2/media-table-schema.json`. It refuses a leading `/`, a leading `.`, a leading `~`, and `..` anywhere. The YAML's parenthesis names three of the four and leaves out `~`. The decision-log bullet gives only "when `path` is relative to the package root", with no refusal list. Under that wording, `./photos/x.jpg` is relative to the package root, yet the standard refuses it. A producer that follows the decision log, or reads `~` as allowed, writes a filePath the standard rejects, and nothing in crate checks it. Fix: name all four in the YAML ("starting `/`, `.` or `~`, or holding `..`"), and give the decision log the same condition or point it to the YAML.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies"

- **[severity: fragile]** inst/extdata/schemas/nge/photo_files.yaml:20-22; decisions/nge/20261116_photo_tables.md:79-80. "the media table's deployment and capture identifiers come from elsewhere" misstates Camtrap DP 1.0.2. Its media table has no capture identifier. Its fields are mediaID, deploymentID, captureMethod, timestamp, filePath, filePublic, fileName, fileMediatype, exifData, favorite and mediaComments. Three required fields cannot come from these rows: `mediaID`, `deploymentID` and `filePublic`. `captureMethod` is optional (`required: false`). As written, the sentence names a field that does not exist and leaves out two required ones (`mediaID`, `filePublic`). Anyone using it as the to-do list for building a media table produces one that fails validation. Fix: "its required `mediaID`, `deploymentID` and `filePublic` come from elsewhere".
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies"

- **[severity: fragile]** decisions/nge/20261116_photo_tables.md:69-71. The sentence before says `crt_schema_conform()` "checks required columns are present, not filled". The next one describes the `identified` grade as "`checksum`, `path`, `size` all present", and the `record` grade as "... `record_id` present". In that sentence, "present" means the column exists. `crt_schema_grade_eval()` (R/crt_schema_grade.R) and the schemas README require each column to be present *and non-missing* in the row (`!is.na(df[[col]])`), and the branch's own last test pins that. Read as written, the grades repeat the conform check and could never separate a row with a missing checksum. That is the same restated-fact mechanism as rounds 1-3. Fix: "present and non-missing" (or "filled") in both parentheses.
  - **Rule:** none

- **[severity: fragile]** inst/extdata/schemas/nge/photo_files.yaml:67-69. The note describes `time_local` as "The camera's wall clock ... as the file wrote it, as text in the form `YYYY-MM-DDTHH:MM:SS`". EXIF writes `DateTimeOriginal` as `YYYY:MM:DD HH:MM:SS`. The decision log (line 22, "EXIF's own `YYYY:MM:DD HH:MM:SS` rewritten") says so correctly, but the YAML, which is the contract a producer reads, does not. A producer who takes "as the file wrote it" literally passes `2024:07:14 10:32:05`. That conforms silently, because the column is `string` and nothing checks its form. Appending `time_offset` to it then gives a Camtrap DP `timestamp` that fails the standard's `%Y-%m-%dT%H:%M:%S%z`. Fix: "rewritten from EXIF's `YYYY:MM:DD HH:MM:SS` to `YYYY-MM-DDTHH:MM:SS`, with no zone".
  - **Rule:** none

## Round-3 fixes checked

- (4) GPS datum: "taken as EPSG:4326; EXIF names the datum in its `GPSMapDatum` tag, which is not read or carried here". Correct: GPSMapDatum is EXIF's GPS-IFD datum tag. The clause "nearly every camera writes WGS-84" is unsourced and ambiguous. Many phones omit the tag entirely, so it is false if read as the tag's value, and plausible if read as the coordinates' datum. It changes no behaviour, because the column is taken as 4326 either way, so it is not a finding. Consider "nearly every camera's fix is WGS-84".
- (5) filePath: see finding 1 (`~` missing; decision log carries no refusal list).

## Claims enumerated and checked

| Claim (where) | Owner | Verdict |
|---|---|---|
| sha256 is 64 lowercase hex (photo_files, photo_links) | SHA-256 / `digest::digest(algo="sha256")` | holds |
| same digest as receipt `result.parts.<path>.sha256`; `size` is `.bytes` | R/crt_receipt_write.R:411, receipt schema v1.0.0 `parts` | holds |
| R integer stops at 2^31 - 1, about 2.1 GB | R | holds (2,147,483,647 B) |
| `time`: non-UTC offset text refused, zone-less text read as UTC, POSIXct/UTC ISO accepted | R/crt_schema_apply.R `crt_datetime_parse_iso` | holds (`+00:00` and `Z` accepted) |
| POSIXct to text loses `T`, and at midnight the time | R 4.5.2 `as.character()`, which `string` applies | measured: `"2024-07-14"` for midnight, and `crt_schema_conform()` gives the same |
| time_local "as the file wrote it, YYYY-MM-DDTHH:MM:SS" | EXIF DateTimeOriginal | finding 4 |
| time_offset `+HH:MM`/`-HH:MM`, never `Z` | EXIF OffsetTimeOriginal | holds |
| GPSMapDatum names the datum | EXIF | holds; see (4) above |
| range [-180,180] / [-90,90] are declarations | schemas README | holds |
| IANA media type, e.g. image/jpeg, image/png | IANA | holds |
| Camtrap DP: filePath rule | media-table-schema.json 1.0.2 | finding 1 |
| Camtrap DP: timestamp required; offset appended matches its format | same | holds (`required: true`, `%Y-%m-%dT%H:%M:%S%z`, `±hh:mm` allowed) |
| Camtrap DP: fileName, fileMediatype (image/video/audio pattern) | same | holds |
| Camtrap DP: no checksum, no copy-to-original link, exifData exists | same | holds |
| Camtrap DP: "deployment and capture identifiers" | same | finding 2 |
| record_id restarts at 1 on a layer rebuild | form_capture.yaml source_version notes | holds |
| form_capture.project / form / source_version / record_id exist; source_version NA when there is no versioned upstream | form_capture.yaml | holds |
| record_id unique within (project, form, source_version) | form_capture.yaml | holds |
| SQL `=` does not match NULL, `IS NOT DISTINCT FROM` does | SQL | holds |
| track_vertices `time` is a UTC instant | track_vertices.yaml | holds |
| grade = present and non-missing | R/crt_schema_grade.R, schemas README | finding 3 (decision log wording) |
| registry `canonical_cols` = required columns | schemas README step 4 | holds (`path,checksum,size`; `checksum,project`) |
| CLAUDE.md "keyed by path and the SHA-256 of its bytes" | photo_files key `(checksum, path)` | holds |
| `relative_to`, `'null'`, `units`, `range` are allowed keys | schemas README table | holds |
| #38 is the data consolidation umbrella; #68 is the nge rename | gh issue titles | holds |
| no private repo names in added text | grep for private repo names and hosts | holds ("camera trap" is the domain term) |
| test comments ("told apart by its bytes", "copy names its original", "no offset is never an instant", "several records") | tests | match what the tests do |

Tests run in a detached worktree (since removed): test-crt_photo.R 0 failed, 0 error, 41 passed; test-crt_registry_integrity.R 0 failed, 0 error, 769 passed.
