# Code-check round 3: branch `13-canonical-schemas-for-field-forms-vintag` (base 1b8837f, HEAD c6d886f)

## Checklist read

- **code-check.md**: read the prose of all 14 `## Mechanisms` H3s, with tables and evidence blocks skipped: A guard that fails toward pass; A fixture that cannot reach the failure mode; A proxy is not the property; Verification that reads its own output; A guard's scope, escape hatches, and remedies; A fix lands in one of two callers that share a harness; Restore the bug and prove the guard fires; A shared working tree, and what generators leave in it; A wrapper's exit is not the work; Zero-length, empty, and unset are three different things; The probe is broken before the world is; Written data outlives the fix; Serialization loses meaning silently; One fact derived twice. **Not read: 23** (standalone, Security, Spreadsheets and PDFs). I applied "Bare `y`, `n`…" from its index line only.
- **code-check-r.md**: read: Cross-function consistency for label/string normalization; `strsplit()` drops a trailing empty field, so a trailing separator vanishes; `sort()` and `order()` collate by `LC_COLLATE`, so a canonical form is locale-dependent; A library call that dispatches on a global option is not a pure function; `file(open = "wb", encoding = )` does not re-encode on write (including its C-locale bullets on `enc2utf8()` and `yaml::read_yaml()`); `deparse()` re-encodes non-ASCII, so it answers about itself rather than the file. **Not read: 109.** Rounds 1 and 2 covered the remaining R headings that bear on this diff.
- **code-check-shell.md**: read: `gh` CLI. I applied "`gh api` prints an HTTP error's body on stdout and exits 1, ignoring `--jq`" from its index line. **Not read: 69.**
- **code-check-spatial.md**: read: Ask the file about its field names, not R; A GeoPackage is a SQLite database, and that leaks in three ways. **Not read: 91.**

## What was run (in a copy under the session scratchpad; the repo was not touched)

- Ran the branch's four test files (fingerprint, meaning, form_schemas, registry_integrity) with `NOT_CRAN=true`. Under en_US.UTF-8: 49 blocks, 0 failed, 0 error. Under `LC_ALL=C`: 0 failed, 0 error, 22 warnings. The warnings all come from `read_yaml()` truncating the **pre-existing** bcfp YAML. They are not from this branch's files.
- Re-ran `data-raw/forms_derive-schemas.R` against rfp@a901caa three ways:
  - default session: byte-identical to the commit.
  - `LC_ALL=C`: byte-identical, because every current input is ASCII.
  - `R_PROFILE_USER` setting `options(digits = 4)`: `form_fiss_site.yaml` changes. The bound `999999.0` becomes `1.0e+06`, `9999999.0` becomes `1.0e+07`, and `10000.0` becomes `1.0e+04`.
- Ran R `toupper("integer")` under `LC_ALL=tr_TR.UTF-8`. On Linux (Ubuntu 24.04 container, R 4.3.3) it returns bytes `c4 b0 4e 54 45 47 45 52`, which is `"İNTEGER"`. On macOS it returns `"INTEGER"`, because R uses its own case tables there.
- Surveyed all 16 rfp schema CSVs and `form_monitoring.qml` at the pinned SHA for every sentinel shape: `<NULL>`, blank parts, `Label=code` spacing, checkbox states, range bounds, the GUID, `value=""` and ±DBL_MAX. Read rfp's own options parsers in `R/rfp_form_build.R` at the same SHA.
- Checked the primary key of rfp's GeoPackages with `PRAGMA table_info`: it is `fid`, with `pk = 1`, and every declared type is upper-case.

## Findings

- **[severity: fragile]** data-raw/forms_derive-schemas.R:428 — `yaml::as.yaml()` defaults to `precision = getOption("digits")`, and the call does not set it. So the bounds the derive script publishes depend on the session's `digits` option.
  - Measured with `options(digits = 4)` in a user profile: fiss_site's `utm_easting` range is published as `[0, 1.0e+06]` instead of `[0, 999999]`, and `utm_northing` as `[0, 1.0e+07]` instead of `[0, 9999999]`. No error, and the integrity test ("a range is two numbers, low then high") still passes.
  - Even at the default of 7 digits, a bound with more significant digits is rounded. `2147483647` is written as `2.1474836e+09`. That is the shape of a half-set QGIS range (`0|2147483647`), which the int32 filter keeps because it compares both bounds.
  - Today's committed YAMLs are correct only because the largest bound, 9999999, has exactly 7 significant digits.
  - The header's claim at :24, "Re-running at the same RFP_SHA rewrites every file byte-identically", is true only for sessions that keep `digits` at 7.
  - Fix: pass `precision = 15` (or 17) to `as.yaml()`.
  - **Rule:** code-check-r.md "A library call that dispatches on a global option is not a pure function"

- **[severity: fragile]** R/crt_schema_fingerprint.R:83 — `toupper()` is locale-dependent. In a Linux R session whose `LC_CTYPE` is Turkish, `toupper("integer")` gives `"İNTEGER"` (measured, R 4.3.3 / glibc). So a capture whose declared types are lower-case gets a different fingerprint there than anywhere else.
  - The roxygen promises the opposite: "They are upper-cased first, so `real` and `REAL` agree".
  - This is the function whose whole purpose is that every producer computes the same value. Round 2 made the *names* locale-independent (marking, `enc2utf8`, radix sort). The *types* still go through a locale-dependent conversion.
  - Exposure is narrow: rfp's GeoPackages declare upper-case types (measured), and QGIS, GDAL and RSQLite write upper-case. Only a lower-case declaration harvested in a tr/az locale on Linux is affected.
  - Fix: upper-case ASCII only: `chartr("abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", types)`.
  - **Rule:** code-check.md "A fix lands in one of two callers that share a harness". The round-2 locale fix reached one of the two inputs to the hashed string. code-check-r.md "A library call that dispatches on a global option is not a pure function" also applies, with locale as the global.

- **[severity: fragile, latent]** data-raw/forms_derive-schemas.R:264, :376 and :428 — round 2's mechanism (unmarked UTF-8 under a non-UTF-8 locale) also reaches the derive script, which was not changed.
  - The rfp CSVs are read with no `encoding = "UTF-8"`, the fixtures are written with `write.csv()` in the native encoding, and `as.yaml()` translates unmarked strings.
  - Measured under `LC_ALL=C`: a help text `Temperature (°C)` is written into the YAML as `Temperature (<U+0…`, and a UTF-8 column name is written into the fixture as `d<c3><a9>bit`.
  - All five current forms are ASCII, so the C-locale re-run is byte-identical and nothing committed is wrong. But the script copies rfp's prose verbatim, and a sibling rfp form already carries non-ASCII (`cabin_visit.csv`: `Conductivity (µS/cm)`).
  - There is a second, pre-existing hazard. Even a correctly written non-ASCII form YAML is truncated by `crt_schema_read()` under C. Measured on the bcfp YAML: it warns "invalid input found on input connection" and returns a partial list. The new `crt_schema_get()` routes all three new accessors through that reader.
  - Fix for the script: refuse to run unless `l10n_info()[["UTF-8"]]`. The reader is outside this diff.
  - **Rule:** code-check-r.md "`file(open = "wb", encoding = )` does not re-encode on write"

No security issues. No public-text leaks were found in the files read.

Not a crate defect, for the caller: rfp's builder emits each options part unfiltered (`.rfp_form_option_pairs`: "Parts are NOT filtered"). So fiss_site's `feature_type` and `feature_type_2` dropdowns, as rfp builds them, offer a choice whose **stored value is the literal string `<NULL>`**, not a null. crate leaves it out of `values`, so a QC rule would flag those records. That is arguably right, but a crew that picked "no feature" stores text. This comes from reading rfp's code at the SHA; I did not measure it on a capture. It is worth an rfp issue.

## Mechanism

Every defect in rounds 1 and 2, and the two above, is a **derived value that is a function of more than its input**. The extra argument is either ambient session state or *today's spelling of the upstream*. The only verification the branch runs varies neither.

- **Session state:** locale (`enc2utf8()`, `toupper()`, `read.csv`/`write.csv`/`as.yaml` translation, `read_yaml` truncation) and options (`digits` in `as.yaml`).
- **Upstream spelling:** the NULL choice found by its default label, the int32 bounds standing for "unset", `fid` found by name rather than by `pk`, crate's own re-parse of rfp's `options` grammar. Each is a proxy that equals the property on rfp@a901caa.

The check that "verifies" the generator is: re-run it, then `git status` is clean. That check holds both hidden arguments fixed (the author's session, the pinned SHA), so it is structurally unable to disagree with them ("Verification that reads its own output"). The **two lists that happen to agree** are:

1. The author's session state and the canonical one (UTF-8, `digits = 7`, a non-Turkish locale).
2. crate's re-implementation of the rfp CSV `options` grammar and rfp's own parser (`.rfp_form_option_pairs`, `.rfp_form_check_states`, `.rfp_form_range_parts`). They agree on every cell that exists today, and diverge on spacing around `=`, on empty checkbox states and on interior empty parts ("One fact derived twice").

## Enumeration

### (a) Every sentinel, placeholder or "no value" representation

| # | where | representation | identified by | verdict |
|---|---|---|---|---|
| 1 | rfp CSV valuemap | `<NULL>` part (fiss_site `feature_type`, `feature_type_2`) | exact token after `trimws` | holds (accepted tradeoff). rfp builds it as a literal stored value; see the note above |
| 2 | rfp CSV valuemap | blank part: trailing `\|` (other rfp schema `pscis.crossing_subtype`), interior `a\|\|b` | `nzchar()` drop | holds. Trailing: rfp's `strsplit` also drops it, so the two agree. Interior: rfp keeps an entry with value `""`, crate drops it. None in any of the 16 rfp CSVs |
| 3 | rfp CSV valuemap | `Label=` (empty code) | kept as value `""` | holds, guarded: the integrity test refuses an empty or NA value |
| 4 | rfp CSV valuemap | `Label = code` with spaces | last `=`, **no trim** (rfp trims both halves) | holds today: 0 of 16 rfp CSVs space their `=`. Divergent grammar: crate would publish `" 4"` where rfp stores `"4"` |
| 5 | rfp CSV checkbox | both states blank `\|` (fiss_site `tributaries`, boolean) | `nzchar()` drop, so no `values` | holds (correct for a boolean) |
| 6 | rfp CSV checkbox | one state blank `Yes\|` | dropped; rfp treats an empty state as a stored value | holds today (none). Divergent: crate would publish `["Yes"]` and a QC rule would flag the stored `""` |
| 7 | rfp CSV range | blank `options` (fiss_site `reference_number`, `reach_number`) | `nzchar(r$options)` | holds. rfp documents blank as "no explicit bounds" |
| 8 | rfp CSV range | `-2147483648\|2147483647` (pscis `aggregated_crossings_id`, fiss_site `site_number`) | `identical(b, int32)` on both bounds, by value | holds. A half-set `0\|2147483647` is kept, and then rounded by finding 1 |
| 9 | rfp CSV range | one-part or non-numeric cell | `anyNA(as.numeric(...))` drop | holds. rfp's builder refuses such a cell anyway |
| 10 | QML ValueMap | NULL choice `{2839923C-…}` | its value (round-2 fix) | holds. None in the QML at the SHA |
| 11 | QML ValueMap | `value=""` entry | kept | holds, guarded by the integrity test's empty-value refusal. None in the QML |
| 12 | QML Range | int32 Min/Max typed `double` (`aggregated_crossings_id`) | `identical(b, int32)` | holds (measured: dropped) |
| 13 | QML Range | ±DBL_MAX, what QGIS writes for an unset double range | not recognised | holds today (absent). If it appears, it would publish `±1.7976931e+308`, a meaningless but finite range. This is the same proxy as #8 |
| 14 | QML Range | `<config><Option/></config>` | `opt()` gives NA, dropped | holds |
| 15 | QML CheckBox | empty Checked or Unchecked state | `nzchar()` drop | holds today (all `Yes`/`No`). Same divergence as #6 |
| 16 | GeoPackage | surrogate row id | column **name** `fid`, not `pk = 1` | holds: the rfp GeoPackages' pk is `fid` (measured). It is a proxy, and an OGR `FID=` layer option would defeat it |
| 17 | GeoPackage | geometry column | `gpkg_geometry_columns` (the property) | holds |
| 18 | GeoPackage | unknown declared type | `decl_map[[…]]` errors | holds (fails loud) |
| 19 | YAML written | `NA` becomes `.na.character` | NULL entries removed before writing; integrity test refuses NA values | holds: grep finds no `.na` in any form YAML |
| 20 | YAML written | `''` | none emitted | holds (grep) |
| 21 | YAML written | `null` key | written `'null'` | holds (round 1) |
| 22 | YAML written | logicals | `true`/`false` handler | holds |
| 23 | YAML written | numbers (range bounds) | `as.yaml` at `getOption("digits")` | **defect**: finding 1 |
| 24 | fixtures read | `read.csv` default `na.strings = "NA"` | a column named `NA` would read as NA, and the fingerprint aborts | holds (fails loud; no such column) |
| 25 | `crt_schema_fingerprint()` | NA or blank type | aborts | holds |
| 26 | `crt_schema_fingerprint_check()` / `_variant()` | NA `schema_version` | silent, and variant NA | holds (documented: "or is missing") |
| 27 | `crt_schema_cols()` | absent `values` or `range` | `character(0)` / `NA` | holds |

### (b) Every point where text becomes bytes or is compared as bytes

| # | where | operation | locale/encoding-independent? | verdict |
|---|---|---|---|---|
| 1 | fingerprint :79–81 | names: mark valid UTF-8, then `enc2utf8()` | yes (round-2 fix, tested under C) | holds |
| 2 | fingerprint :83 | `toupper(types)` | **no**: Turkish locale on Linux maps `i` to `İ` (measured) | **defect**: finding 2 |
| 3 | fingerprint :83 | types are not marked or translated before `paste0` | non-ASCII types would depend on locale | holds in practice (SQL declared types are ASCII; measured upper-case ASCII in rfp) |
| 4 | fingerprint :82 | `sort(method = "radix")` | yes: byte order in both en_US and C (measured with marked UTF-8) | holds |
| 5 | fingerprint :84 | `digest(serialize = FALSE)` | hashes the UTF-8 bytes | holds |
| 6 | variant :53, check :76 | `match()` / `%in%` on fingerprints | ASCII hex | holds |
| 7 | grade :54 | `col %in% names(df)` | R compares translated strings | holds |
| 8 | derive :182 | `toupper(info$type)` | Turkish locale would yield `İNTEGER`, and `decl_map` would then error | holds (fails loud; types already upper-case) |
| 9 | derive :264 | `read.csv(rfp CSV)` with no encoding | **no**: unmarked under C, translated with escapes downstream | **defect, latent**: finding 3 (inputs ASCII today) |
| 10 | derive :376 | `write.csv` of the fixture in native encoding | **no**: `d<c3><a9>bit` under C (measured) | **defect, latent**: finding 3 |
| 11 | derive :428 | `as.yaml()` text | **no** under C (escapes, measured); numbers depend on `digits` | finding 3 and finding 1 |
| 12 | derive :436 | `writeChar(enc2utf8(body))` on a `wb` connection | writes the bytes it is given | holds (correct once the body is) |
| 13 | derive :178–182 | names from RSQLite | marked UTF-8 | holds |
| 14 | derive :320 | `read_yaml(form_capture.yaml)` | ASCII file | holds |
| 15 | `crt_schema_read()` → `crt_schema_get()` | `yaml::read_yaml()` | **no**: truncates at the first non-ASCII character under C (measured on bcfp) | pre-existing, outside the diff. Holds for this branch's ASCII YAMLs; latent with finding 3 |
| 16 | tests | `read.csv(fixture)` with no encoding | names are re-marked by the fingerprint; the `setdiff(names, declared)` test would fail loudly under C with non-ASCII | holds |
| 17 | tests | `expect_setequal(list.files(...))` | ASCII file names | holds |
| 18 | derive :145–171 | `gh api` through `system2` | exit status checked; an error body is caught by the size and regex checks | holds |
