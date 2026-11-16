# Code-check round 3 (#36)

## Checklist read

- **code-check-python.md**: in full. No rule applies; the diff has no Python.
- **code-check.md**: all 14 `## Mechanisms` H3s read as prose (table rows and evidence blocks skipped): A guard that fails toward pass; A fixture that cannot reach the failure mode; A proxy is not the property; Verification that reads its own output; A guard's scope, escape hatches, and remedies; A fix lands in one of two callers that share a harness; Restore the bug and prove the guard fires; A shared working tree, and what generators leave in it; A wrapper's exit is not the work; Zero-length, empty, and unset are three different things; The probe is broken before the world is; Written data outlives the fix; Serialization loses meaning silently; One fact derived twice. Standalone rules: index only. 0 other headings read in full.
- **code-check-r.md**, read in full: Read-back shape must match write-back shape; `system2(stdout = TRUE)` warns on a non-zero exit instead of raising; `dbConnect(SQLite(), path)` CREATES the file; `read.delim()` quotes by default; Copy a live SQLite database with its `-wal`. Checked against the diff from the index line (not re-read in full): `$` on a list partial-matches; `sort()` and `order()` collate by `LC_COLLATE`; `paste()` with a zero-length argument; `match()` treats NA as a matchable VALUE; A `data-raw/` script must load the source tree; `lintr` also resolves against the installed package; A `pkg::` call in a test needs DESCRIPTION; `ifelse()` with an all-NA test; Base name shadowing in formal args; `tryCatch()` nests its handlers. About 150 other headings not read: they cover tools this diff does not use.
- **code-check-spatial.md**, read in full: A GeoPackage is a SQLite database, and that leaks in three ways; The same leak reaches R and OGR SQL, and a GeoPackage's bytes are not its content; Restoring a GeoPackage from a copy; Ask the file about its field names, not R. About 110 others not read (terra, sf, GDAL CLIs, STAC: not in this diff).
- **code-check-shell.md**: index only. The diff's only shell surface is `system2()` building `gh` and python argv: all three call sites `shQuote()` their data arguments, and `gh api` errors are caught by status (`rfp_fetch`) or a date-pattern check (`rfp_month`). About 125 headings not read.

## What I ran (all on copies; the repository checkout and the cache were only read)

- Re-ran `write` in a detached worktree against a copy of the cache (without `files/`). The fixtures and `data-raw/forms_variants-measured.csv` came out byte-identical to HEAD, and it reported "361 geodiff versions checked … 0 disagree".
- Re-ran `forms_derive-schemas.R` in the same worktree. All five YAMLs came out byte-identical to HEAD.
- Ran `test-crt_form_schemas.R` (202 pass) and `test-crt_schema_meaning.R` (37 pass) with `NOT_CRAN=true`: 0 failed, 0 error, 0 skipped.
- Checked the cache for files that a pre-fix run may have left at a cache path: `sha1(file) != name` for 274 of 575 `files/*.gpkg`, and all 274 are in `rebuilt.txt`. So no partial download is still in the cache, and every rebuilt file's row has a non-NA `diff_ok`.
- Read every cached `meta/*.rds` again from a copy of `files/` using the current `gpkg_decl()`, `crt_schema_fingerprint()` and `gpkg_nrow()`. All 575 tables agreed (0 decl or fingerprint differences, 0 count differences).
- Measured the cache to check claims in the research note and decision: 361 geodiff checks; 84 column sets, 12 of them took records; min overlap 0.77; the only set under 0.5 is 0.01 and never grew; seasons per form; 185 grew, 174 from mobile; 0 non-INTEGER keys; 0 "other" user agents; `created` has tzone UTC, so `%Y-%m` does not depend on the machine's zone. All match.
- Privacy: grepped the added lines (planning/ included) for every stem in `stems.txt`. The only hits are the generic form names (`form_pscis`, `form_pscis_2023` and the like). There are no `rfp#N`/`trap#N` references and no local paths outside planning's own review-file trailer lines.

## Findings

- **[severity: fragile]** data-raw/forms_read-history.R:339-344 (with :194-213, :229-231, :437-440). The `meta/*.rds` cache is keyed only by the file's checksum, and it counts as stale only when an entry has no `rows` field. The comment at :339 says the check covers `max_pk`/`int_pk`, but the code tests `rows`. Each entry's content depends on more than the checksum: `gpkg_decl()` in the shared `forms_gpkg-decl.R`, `row_hashes()`, and `crt_schema_fingerprint()`. If any of these changes after a `read`, the cached decl, fingerprint and row hashes stay on the old rule, while `forms_derive-schemas.R` computes the build fingerprint with the new one. The shared file exists so that "a fingerprint means the same thing in both", and nothing enforces that across the cache.
  - The quiet failure: suppose a `gpkg_decl` change moves the build's fingerprint (for example, which columns count as capture columns). `write` then sees the build-shaped files under their old cached fingerprint. That shape is not `listed` (`listed` is the YAML's new build fingerprint), and it grew, so it is named as a new `capture-YYYY-MM` variant. Its fixture is written from the cached old decl, so it fingerprints consistently, and the test suite stays green. Only a change to the fingerprint algorithm itself is caught, because the tests recompute fingerprints from the fixtures.
  - The branch has already met this once. The growth rule moved from counts/`max_pk` to row hashes, and the stale test was patched to look for the new field. A field-presence test works when a field is added. It does not work when a rule changes.
  - Today every one of the 575 cached entries agrees with the current code, so nothing is wrong yet.
  - Remedy: store a reader version in each entry and re-read when it differs. The version could be a digest of `forms_gpkg-decl.R` plus `deparse(file_meta)`, `deparse(row_hashes)` and crate's version. Alternatively, put that digest in the meta path.
  - **Rule:** code-check.md "Written data outlives the fix" ; code-check.md "A proxy is not the property"

- **[severity: fragile]** NEWS.md:3 and CLAUDE.md:25 claim more than the code does.
  - NEWS defines growth as a record "under a new key, with content no earlier record had". The code (forms_read-history.R:259, `!b$h %in% a$h`) compares only with the immediately previous version in the chain. A record deleted in one version and pushed again with the same content under a new key two versions later counts as new. The research note ("none of the previous version's records had") and the decision ("none of its records had") state the rule correctly. NEWS is public release text and widens it.
  - CLAUDE.md says the five form schemas are "each listing the 2023–2025 versions crews captured into". `form_monitoring_fish_passage` and `form_monitoring_general` list none: their only variant is the build, and they first took records in 2026, or never. A reader would take "each" to mean every form has some.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies" (compression adds a quantifier or widens a claim)

## The mechanism behind rounds 1–2, and where it reaches

**Mechanism A. The presence of a cache entry is read as proof that it is complete and current.** Findings (1), the stale empty `failures.txt`, and (6), a failed download left at the cache path, are both this mechanism. It reaches:

| place | state |
|---|---|
| `failures.txt` | fixed: in-progress marker, plus a meta/raw existence check over every non-removed walk row |
| `files/*.gpkg` | fixed: `.part` then rename, checksum or (geodiff + `integrity_check`) before the rename. The cache was verified clean (above) |
| `meta/*.rds` | **open**: keyed by checksum, not by the reader's code. Finding 1 above |
| `raw/*.json`, `changesets/*.rds` | acceptable. They are immutable server records, parsed before being written (raw) or written whole by `saveRDS`, and a truncated file raises on the next read instead of passing |
| `agents/*.txt` | acceptable: rewritten from raw on every read, and `write` refuses a grew row whose client is NA |
| `walk.rds` | acceptable: rewritten on every read, and written while the marker is up |
| `rebuilt.txt` | append-only, and only feeds a message, so nothing is gated on it |
| fixtures / measured CSV / YAMLs | acceptable: regenerated from the committed tree, verified byte-identical by re-running both scripts |

Two adjacent shapes are not findings today:

- The CSV-name guard (:560-561) runs inside the fixture loop, so a bad name stops the run after some fixtures are already rewritten. Ids are pinned, so those rewrites are identical, and an orphan fixture fails the fixture/listing test.
- `file_meta()` is not wrapped per file, so a GeoPackage with an untyped column, or with no `gpkg_contents`, would abort every `read` at the same file. There are 0 such files among the 575 (0 empty declared types in about 67k columns).

**Mechanism B. An output is computed from the run's environment or data, and assumed stable across runs.** Findings (2), recomputed ids, and (3), locale month names, are this mechanism. It reaches:

- ids: pinned, with a stop on a dropped listing.
- month names: `month.name`.
- `format(created, "%Y-%m")`: deterministic, because `created` carries tzone UTC from `rfp_mergin_history()`. Checked: 1 of the 185 grew versions would change month under the Vancouver zone, so the UTC attribute is what keeps the ids stable.
- every `order()`: `method = "radix"`.
- new-id letters: by fingerprint string order, so deterministic.
- `client_of()`: an unmatched user agent falls to "other" and is counted as desktop (`grew_desktop = sum(client != "mobile")`). There are 0 "other" agents today, and the five UA families in the cache all classify as intended.
- the `n_versions`/`first_seen` text in descriptions: measured afresh each run, by design.

**Mechanism C**, finding (4), unquoted `system2` arguments: every `system2()` call in both scripts now quotes its data arguments, and `system2()` quotes the command itself.

Findings (5) and (7) were claim drift. Their sweep is the second finding above.

/Users/airvine/Projects/repo/crate-36/planning/active/review-round3.md
