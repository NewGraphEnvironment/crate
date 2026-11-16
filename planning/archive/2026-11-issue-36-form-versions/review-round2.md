# Code-check round 2 (#36)

Reviewed `git diff <merge-base>...HEAD` at 0348038, with the round-1 fixes read closely. The changed
files were read in full at HEAD. The local history cache was read read-only to measure claims (no
project names are quoted here). Both changed test files pass in a detached worktree
(`NOT_CRAN=true`, `test_file`): test-crt_form_schemas.R 202 passed, test-crt_schema_meaning.R 37
passed, 0 failed, 0 errors.

## Checklist read

- code-check-python.md: in full (no Python in the diff; nothing applies).
- code-check.md: every index line read, and the prose of all 14 H3s under `## Mechanisms`
  (table rows and evidence blocks skipped), plus "Test the cold/create path of idempotent code,
  not just the warm no-op". The other standalone and security headings were not read (about 25).
- code-check-r.md: read "`system2(stdout = TRUE)` warns on a non-zero exit…", "`dbConnect(SQLite(),
  path)` CREATES the file…", "Copy a live SQLite database with its `-wal`", "A `data-raw/` script must
  load the source tree…", "`$` on a list partial-matches…", "Read-back shape must match write-back
  shape", "Never name a durable artifact by a hash…" and "CSV whitespace…" (8). The rest were checked
  against the index only (about 120 not read).
- code-check-spatial.md: read "A GeoPackage is a SQLite database, and that leaks in three ways",
  "Restoring a GeoPackage from a copy…" and "Ask the file about its field names, not R" (3). About 95
  not read.
- code-check-shell.md: index only. The diff's shell surface is `system2()` argument quoting, which
  code-check.md "A wrapper's exit is not the work" covers. 0 headings read in full, about 95 not read.

## Findings

- **[severity: fragile]** data-raw/forms_read-history.R:316-333 — A fetch that fails for any reason
  other than a checksum mismatch leaves a file at the cache path. Retrying it cannot succeed, and the
  next resumable `read` trusts the file instead of fetching it again.
  - `rfp::rfp_mergin_file_get()` (rfp 0.94.0) calls `rfp_mergin_download_file()` straight into
    `path_out`, and the helper script opens `--dest` with `open(dest, "wb")` before it sends any
    request. rfp deletes the file only on a checksum mismatch. On a non-zero exit (an HTTP error or a
    dropped connection) it stops and leaves the file, which is 0 bytes for these sub-1 MB files.
  - The `else if` branch then calls `rfp_mergin_file_get(..., overwrite = FALSE)` again through
    `retry()`. Both attempts fail with "File already exists", so the in-run retry never runs a
    download, and a failure is recorded.
  - On the next `read`, `if (!file.exists(gpkg))` is FALSE, so the fetch is skipped and
    `file_meta()` reads the leftover file. For a 0-byte file I measured `gpkg_tables()` erroring
    with `no such table: gpkg_contents`. That error aborts `read` before the failures list is
    written, on every run, and nothing names the file to delete.
  - It fails loud rather than wrong, so this is not silent data loss. But it is the "resumable"
    claim failing on the transient error the retry exists for.
  - Fix: fetch into `<gpkg>.part` and `file.rename()` only after the checksum passes, as
    `fetch_rebuilt()` already does. Or `unlink(gpkg)` whenever a fetch errors, before the retry and
    before recording the failure. Also, do not treat a 0-byte file as already fetched.
  - **Rule:** code-check.md "A guard that fails toward pass" ; code-check.md "Written data outlives the fix"

- **[severity: fragile]** research/form_versions.md ("What was measured", the overlap bullet) — "One
  set was rejected on overlap (0.01): a fiss_site table in a file named for pscis, never captured
  into." The overlap rule did not reject that set.
  - The overlap test runs only on sets that grew (`for (i in which(r$grew & !r$accepted))`). This
    set never grew: shapes.csv shows `grew = FALSE`, `n_versions = 1`, so the growth rule excluded it.
  - Across all 84 sets, 12 grew and 12 were accepted. The overlap guard has never rejected a set on
    real data.
  - The sentence, and the decision record's "so a file named for one form that holds another is not
    listed under it", read as evidence that the guard works. Nothing in the run, and no test, has
    seen it fire.
  - Reword it to say what was measured: the set would fall below the threshold, but it never took
    records.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies" ; code-check.md "A guard that fails toward pass"

## Checked and clean (round-1 fixes and other suspects)

- **Interrupted-`read` marker.** `failures.txt` is overwritten first thing in `read_history()`, so an
  abort anywhere after it (unwrapped errors included) leaves `write` refusing. The `no_meta` /
  `no_raw` gate covers every non-removed walk row. A missing `agents/` file reaches `write` only as
  NA, and the `grew & is.na(client)` stop catches that.
- **Id pinning and letters.**
  - A published id is matched by fingerprint and kept. A listed variant that is no longer admitted
    stops `write`.
  - A new id's letters continue past the listed ones, and a bare `capture-YYYY-MM` counts as `a`.
  - Two new ids in one month get `-a` and `-b`.
  - The derive orders rows the same way, so `variants` order matches `upstream_variants` order (the
    test confirms it).
- **`month.name`.** Fixed. `created` is POSIXct with `tzone = "UTC"` in walk.rds, so `%Y-%m` months
  do not depend on the machine's zone.
- **`system2()` quoting.** The arguments are `shQuote()`d, `system2` quotes the command, and the exit
  status is read from `attr(o, "status")`.
- **Geodiff record-count check.** Every one of the 399 cached geodiff entries has a `summary` with
  `table`, `insert` and `delete`, so the check is not vacuous. It ran on 361 versions with 0
  disagreeing. No `$` partial-match hazard in the JSON keys read (`changes`/`changesets`: `changes`
  is always present).
- **Client classifier.** On the cached user agents it yields 231 desktop and 126 mobile, with no
  `other` and no `ios` substring false hits.
- **Research counts.** I re-measured 21 projects / 1,106 versions, 12 projects, 141 paths, 635 walk
  rows, 575 distinct files, 274 rebuilt, 84 sets (39/30/12/2/1), 12 grew, 185 growth versions with 174
  mobile, the minimum accepted overlap of 0.77, every key a single INTEGER, and the per-season table.
  All match, apart from the finding above.
- **Privacy.** I checked the added lines against all 86 cached project and deployment stems: there
  are no hits outside generic form filenames (`form_pscis_2023` and the like) and the org's
  workspace name in planning/. There are no `rfp#`/`trap#` references, local paths or hosts.
- **Not defects.** 204 `.gpkg.part-wal` / `-shm` pairs and 334 `.gpkg-wal` / `-shm` pairs are left
  in the cache by read-only opens of WAL-mode files (334 of the 575 files are `02 02`). Every `-wal`
  is 0 bytes, so no committed data sits outside a main file. This is cache clutter only.
  `write`'s cold path (no form listing any variant past the build, so `published` is NULL) would
  error, but the current YAMLs cannot reach it.

/Users/airvine/Projects/repo/crate-36/planning/active/review-round2.md
