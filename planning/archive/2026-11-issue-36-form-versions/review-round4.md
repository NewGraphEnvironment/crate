# Code-check round 4 (#36)

## Checklist read

- code-check-python.md: in full.
- code-check.md: the prose of all 14 H3s under `## Mechanisms` (table rows skipped). Standalone rules: none read in full; "Bare `y`, `n`… booleans in YAML 1.1" and "Documentation Staleness" judged from the index only. Not read: every other standalone, Security and Spreadsheet heading (none names a tool or shape this diff uses).
- code-check-r.md: read "A database driver's value is not a base R type", "`dbConnect(SQLite(), path)` CREATES the file", "Copy a live SQLite database with its `-wal`", "Never name a durable artifact by a hash the library reserves the right to change", "`system2(stdout = TRUE)` warns on a non-zero exit", "A `data-raw/` script must load the source tree", "`sort()` and `order()` collate by `LC_COLLATE`", "as.POSIXct on a Date pins UTC midnight", "CSV whitespace". Not read: about 120 other headings.
- code-check-spatial.md: read "A GeoPackage is a SQLite database, and that leaks in three ways", "The same leak reaches R and OGR SQL, and a GeoPackage's bytes are not its content". Not read: about 100 others.
- code-check-shell.md: none read. The diff has no shell scripts; `system2` arguments are covered under R. Not read: all of them, about 95.

## Findings

- **[severity: fragile]** data-raw/forms_read-history.R:121, 125-140, 300-309 (and the `agents/` key at 372-373): the `changesets/` and `raw/` caches are keyed by `safe(project)` and the version number, and a present entry is reused without a check. But a project name does not identify one server project. If a project is deleted and created again under the same name (test projects are the likely case, and the research note says to re-run each season), or if two names map to the same key under `safe()` (`a b` and `a_b`), `read` reuses the old project's change lists for v1..vN. Meanwhile `h` is fetched fresh, so `walk` attaches the old project's paths and checksums to the new project's dates. The old files are already cached, so nothing is fetched and nothing fails. The diff check passes too, because it compares old with old. The result is wrong `first_seen` and growth, with no error. The check this needs is cheap: every `raw/*.json` already carries the server's `created`. Compare each cached record's `created` (store it with the changeset `.rds` too) against the fresh `h$created`, and refetch or refuse on a mismatch. Alternatively, key the cache by the project's id rather than its name. A related gap: the cached `.rds` holds `rfp_mergin_changeset()`'s output with no record of which package version produced it, so a package change to its `change` vocabulary would mix old and new entries. Measured today: all 357 raw records' `created` match the walk's, and the 12 projects have no `safe()` collisions. So no current output is affected.
  - **Rule:** code-check.md "Written data outlives the fix" ; code-check.md "A proxy is not the property"

- **[severity: fragile]** data-raw/forms_read-history.R:218-222 with 173-189 and 265-273: `reader_version()` stamps the code that read a file but not the runtime. Row hashes are `as.character()` of what RSQLite returns from `SELECT *`. That text depends on the R version (how a double prints) and on the RSQLite version (what type a column arrives as), and neither is in the stamp. Meta is re-read only when the reader digest changes, so after the season-by-season re-runs the research note asks for, a chain will compare a predecessor's hashes, cached under last season's R and RSQLite, with a successor's computed under this season's. Where the text form drifts, the `!b$h %in% a$h` arm reads every copied record under a new key as new content. That is exactly the case the rule excludes ("a duplicated row or a renumbering re-export does not" count; the 2025 archive copy). The false growth then admits a variant, its id is pinned in a public schema, and `write` refuses only a listed variant that is no longer admitted, never a new one. The fix is to fold `R.version.string`, `packageVersion("RSQLite")` and `packageVersion("DBI")` into `reader_version()`. That costs a local re-read and no network. Measured today: all 575 meta files carry `ae226325abb7430a`, which equals `reader_version()` recomputed at HEAD, so the current cache was read in one runtime.
  - **Rule:** code-check.md "Written data outlives the fix" ; code-check.md "A guard that fails toward pass"

## The mechanism, and every place it reaches

Rounds 1-3 and both findings above share one assumption: **a cache entry is keyed by the identity of the server object it came from, and that key is trusted to identify the stored value.** But each value is a function of more than that key: the code that produced it, the runtime it ran in, and which server object a name meant at that moment. Round 3 added one missing input (producer code) to one cache (`meta/`). Round 3's (A), presence taken as proof, and (B), environment-dependent output, are the two halves of this: (A) is a key with too few inputs, and (B) is the inputs that are left out. The table lists every cache.

| store | key | value also depends on | state |
|---|---|---|---|
| `files/<sha1>.gpkg` | checksum | a complete download; the server's rebuild | closed: `.part` + checksum/integrity. Measured all 301 whole-pushed files equal their sha1; the 274 that differ are exactly the 274 in `rebuilt.txt` |
| `meta/<sha1>.rds` | checksum + reader digest | R and RSQLite versions (row text) | open: finding 2 |
| `changesets/<safe(p)>__v.rds` | project name, version | project identity; package version | open: finding 1 |
| `raw/<safe(p)>__v.json`, `agents/` | project name, version | project identity | open: finding 1 (`created` is there to check against) |
| `walk.rds`, `failures.txt` | in-progress marker | — | closed (round 1) |
| `decl_of` (write, l. 452-455) | every file in `meta/`, not gated by `meta_current` | orphan or stale metas | reached but harmless: 0 orphans, 575/575 current, and no fingerprint has two decl orders. A stale decl could change only a fixture's column order or type case, and `type_of()` in the derive refuses lower case. Not a finding |
| fixtures + `forms_variants-measured.csv` | ids pinned from the YAML | — | closed: the derive refuses a fixture whose fingerprint differs from the CSV's |

Other places environment-dependent output could reach, all closed: month text is UTC (the reader sets `tzone = "UTC"`, and `vt$created` keeps it; no accepted variant's first month differs between UTC and Vancouver), sorts use `method = "radix"`, `month.name` is used rather than `%B`, the derive sets YAML `precision = 15`, and a UTF-8 check guards both scripts. `reader_version()` itself depends on R's `deparse()`/serialize output, but that fails toward a re-read, which is safe.

## Checked and found clean

- Round-3 fix: `meta_current` is passed `reader` correctly through `vapply`, the reader digest is captured once at the start of `read`, and the default serializing `digest()` hashes the whole vector (the `serialize = FALSE` first-element trap does not apply).
- The two test files pass in a detached worktree: 202 and 37 passed, 0 failed, errored or skipped.
- Research and decision numbers checked against the cache: 84 sets, 12 accepted (pscis 3, fiss_site 4, monitoring 4, monitoring_fish_passage 1, monitoring_general 0); minimum accepted overlap 0.77; the single set under 0.5 (0.01) never grew; 361 diff checks, 274 of them on rebuilt files, 0 disagree; 185 versions grew, 174 of them mobile; seasons match `seasons.csv`; history versions are contiguous v1..vN per project, so none was cut off by paging.
- Privacy: of the 86 stems in the cache, only the five form names appear in the added lines. There are no private-repo issue references, no local paths, and no test-project names.
- Fixtures: every line has exactly two fields, and no declared type contains a comma.

## Verdict

Two fragile findings, both instances of the mechanism above. Neither affects the committed outputs today, as measured against the cache.
