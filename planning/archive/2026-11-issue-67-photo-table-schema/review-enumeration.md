# Code-check enumeration — #67 (2026-11-16, after round 4)

Mechanism, named by rounds 3 and 4: a sentence in the added prose (YAML notes and descriptions,
decision log, CLAUDE.md, test comments) restates a fact another artifact owns, and nothing checks
it against that artifact. Round 4 found a defect inside round 3's fix (the `filePath` rule
paraphrased incompletely), so the loop ends on this enumeration.

Remedy for the external-spec class: Camtrap DP constraints are now **quoted** from
`media-table-schema.json` (tdwg/camtrap-dp tag 1.0.2, fetched 2026-11-16) rather than
paraphrased, and the decision log points at the YAML instead of restating it. The
unsourced "nearly every camera writes WGS-84" was cut.

Candidate set: every added line naming an outside owner, extracted with
`git diff ecadfc6 -- <file> | grep '^+' | grep -E 'Camtrap|EXIF|GPSMapDatum|SHA-256|receipt|result\.|form_capture|track_vertices|crt_|ISO 8601|IANA|2\^31|SQL|IS NOT|POSIXct|UTC|EPSG|restarts|refused|read as|grade|key|README|#[0-9]'`
over the five files: 86 lines, grouped below by owner.

| Claim | Owner | How checked | Verdict |
|---|---|---|---|
| Camtrap DP `filePath` pattern, `fileMediatype` pattern, `timestamp` required + `%Y-%m-%dT%H:%M:%S%z`; `mediaID`, `deploymentID`, `filePublic` required; `fileName`, `exifData` optional; no checksum field | Camtrap DP 1.0.2 media schema | Parsed the fetched JSON; YAML description read back through `crt_schema_read()` and the regex compared verbatim | holds |
| SHA-256, 64 lowercase hex = receipt `result.parts.<path>.sha256`; `size` = `.bytes` | `R/crt_receipt_write.R` `receipt_parts()` / `receipt_file_sha256()` | Read: `digest(algo = "sha256", file = TRUE)`, `bytes = file.size()`, names = relative paths | holds |
| R integer stops at 2^31 - 1 | R | `.Machine$integer.max == 2^31 - 1` TRUE (R 4.5.2) | holds |
| Zone-less ISO read as UTC; non-UTC offset refused; `Z`/`+00:00` accepted | `R/crt_schema_apply.R` | Conformed each through `photo_files` | holds |
| POSIXct as text loses the `T`, and at midnight the time | R | `as.character()` at midnight gives `2024-07-14`; at noon `2024-07-14 12:00:00` | holds |
| form_capture key `(project, form, source_version, record_id)`; record_id restarts at 1; source_version NA without a versioned upstream; types string/string/string/integer | `form_capture.yaml` | Read the notes and types | holds |
| track_vertices `time` is a UTC instant | `track_vertices.yaml` | Read | holds |
| Grades: present and non-missing | `R/crt_schema_grade.R` | Read `crt_schema_grade_eval()` (`!is.na`, absent column fails) | holds |
| Conform passes extra columns; required = present | `R/crt_schema_conform.R`, `crt_schema_validate.R` | Read | holds |
| SQL `=` does not match NULL to NULL; `IS NOT DISTINCT FROM` does | SQL standard / Postgres | Rounds 2 and 3 confirmed independently | holds |
| EXIF writes `DateTimeOriginal` as `YYYY:MM:DD HH:MM:SS`; `GPSMapDatum` names the datum | EXIF 2.3 | Rounds 3 and 4 confirmed; no claim about what cameras usually write remains | holds |
| `image/jpeg`, `image/png` are IANA media types | IANA | Standard | holds |
| #38, #68 titles | GitHub | `gh issue view` | holds |
| CLAUDE.md: keyed by path and the SHA-256 | `photo_files.yaml` key | Read | holds |
| Registry `canonical_cols` = required columns | YAML | Integrity test + read | holds |

Nothing in the candidate set sits above its owner.
