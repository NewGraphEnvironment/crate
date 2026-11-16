# Code-check round 1 — branch 67 (ecadfc6...HEAD)

## Checklist read

- code-check-python.md: in full.
- code-check.md: every H3 under `## Mechanisms`, prose read: "A guard that fails toward pass", "A fixture that cannot reach the failure mode", "A proxy is not the property", "Verification that reads its own output", "A guard's scope, escape hatches, and remedies", "A fix lands in one of two callers that share a harness", "Restore the bug and prove the guard fires", "A shared working tree, and what generators leave in it", "A wrapper's exit is not the work", "Zero-length, empty, and unset are three different things", "The probe is broken before the world is", "Written data outlives the fix", "Serialization loses meaning silently", "One fact derived twice". Also "Bare `y`, `n`, `on`, `off`, `yes`, `no` are booleans in YAML 1.1" and "An assertion that matches an interpolated value cannot see the claim around it". Not read: the remaining standalone, Security and Spreadsheets/PDF headings (none touch a YAML schema, a CSV row or a testthat file).
- code-check-r.md, read by heading: "as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone", "as.POSIXct on character infers ONE format for the whole vector", "A `skip_if_not()` skips only its own `test_that()` block", "`expect_false(identical(x, y))` cannot fail when the two are different types". The rest (~130) not read: no matching tool or shape in the diff.
- code-check-spatial.md, read by heading: "An offset regex must be anchored to a time, or a date looks like a zone", "A reader that accepts a UTC offset may not be applying it". The rest (~95) not read.
- code-check-shell.md: index only; the diff has no shell code. 0 headings read in full.

## Findings

- **[severity: fragile]** inst/extdata/schemas/nge/photo_links.yaml:318-319 (with :290-297), and decisions/nge/20261116_photo_tables.md:86-88. The `record` grade requires `source_version` to be non-missing. But the column it links to, `form_capture.source_version`, is documented as "NA where there is no versioned upstream" (form_capture.yaml, `source_version` notes). So a link that names a form record in full, a record from a file-based import with no versioned upstream, fails the grade. Probed in a detached worktree: `checksum`, `project = "p"`, `form = "form_pscis"`, `source_version = NA`, `record_id = 3L` conforms, and `crt_schema_grade()` returns `record = FALSE`. The decision log calls this grade "how a reader asks which rows it can trust", so every photo of an unversioned record gets counted as unlinked. The test covering it ("a link meets the record grade only when it names a form record in full") encodes the same assumption: it treats `source_version = NA` as "not a full record", which is the wrong answer for those records. Either drop `source_version` from `requires`, or state on the column and in the decision that an unversioned record's link never meets `record` (and that the key then holds a NULL, which a SQL join on it will not match).
  - **Rule:** code-check.md "A proxy is not the property"

- **[severity: fragile]** decisions/nge/20261116_photo_tables.md:67-68. The rationale says "`crt_schema_apply()` refuses ISO text with a non-UTC offset in a `datetime` column, so a caller cannot hand `time` an unresolved local value by accident." The code does not do that. `crt_datetime_parse_iso()` refuses only a value that *carries* a non-UTC offset. A zone-less wall clock, which is exactly what an unresolved local value is (the `time_local` string itself), is accepted and read as UTC. Probed in a detached worktree: `time = "2024-07-14T10:32:05"` conforms to `2024-07-14 10:32:05 UTC`, seven hours off for a `-07:00` camera, with nothing reported. That is the failure the bullet just above it names ("one guessed into UTC would join to the wrong vertex by whole hours with nothing reported"). The `time` notes in photo_files.yaml:171-176 say "ISO 8601 in UTC" without saying that zone-less text is taken as UTC too, so they don't warn a caller off the accident either. Reword the rationale so it says only what is refused, and say in the `time` notes that text with no zone is read as UTC.
  - **Rule:** code-check.md "A proxy is not the property" ; code-check-spatial.md "A reader that accepts a UTC offset may not be applying it"

Nothing else found:
- The receipt claims hold: `result.parts.<path>` gets `sha256` from `digest(file = TRUE)` (lowercase hex) and `bytes` from `file.size()`.
- The registry rows' `canonical_cols` are the required columns.
- The YAML has no bare boolean names and quotes its `'null'` keys.
- No private repo is named or linked.
- The `expect_error(..., col)` patterns can only match the "Missing: <col>" line.
- The `decisions:` key resolves.
