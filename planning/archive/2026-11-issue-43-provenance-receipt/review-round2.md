# Code-check review, round 2 (#43)

Branch `43-a-shared-provenance-receipt-a-language-n`, diff against merge-base 179217a, with the round-1 fixes (83d9c4c) reviewed one axis over.

## Checklist read
- code-check-python.md: in full.
- code-check-r.md: read 22 headings, did not read 95. Read: Read-back shape must match write-back shape; A `data-raw/` script must load the source tree; Under `R CMD check`, tests run from a temp dir against the INSTALLED package; `$` on a list partial-matches; A database driver's value is not a base R type; `nzchar(NA)` is TRUE; `paste()` with a zero-length argument; `sort()` and `order()` collate by `LC_COLLATE`; A library call that dispatches on a global option; `identical(-0, 0)`; `file(open = "wb", encoding = )`; Never name a durable artifact by a hash the library reserves the right to change; Cross-function consistency for label/string normalization; Verify a float-formatting fix in its consumer; ajv honours keywords beside a `$ref`; `ifelse()` with an all-NA test; R's `yaml` mixed int/float sequence; `identical()` on two reader results; `match()` treats NA as a matchable VALUE; `strsplit()` drops a trailing empty field; A `pkg::` call in a test; as.POSIXct on a Date / on a character.
- code-check-shell.md: read 4 headings, did not read 66. Read: A failed `git fetch` leaves the comparison stale; `for x in $(cmd | grep … || true)` hides a failing `cmd`; Git plumbing calls whose default answers a different question; A fetch can fail and still deliver the commit.
- code-check-spatial.md: read 0 headings, did not read 94 (nothing in the diff uses terra, sf, GDAL or bcdata).
- code-check.md: the prose of all 14 H3s under `## Mechanisms`, plus 2 more headings (Bare `y`, `n` … are booleans in YAML 1.1; A link to a repo-hosted artifact must be *tracked*). Did not read 21.

## Findings

- **[severity: bug]** R/crt_receipt_jcs.R:204-220 — `jcs_numbers()` only tries the correctly rounded p-digit spelling (`sprintf("%.{p-1}e")`) at each length. ECMAScript Number::toString, which RFC 8785 adopts, takes the smallest k for which *any* k-digit decimal reads back as the double, and the nearest one when several do. At a power of two the rounding interval is lopsided: the lower half-gap is half the upper one. So the nearest 16-digit decimal can fall outside the interval while the next one up is inside it. R then writes 17 digits where every other implementation writes 16. Against Python `rfc8785`, 46 of the 2,098 finite powers of two differ (none of 200,000 random doubles do), and Node agrees with Python. Examples: 2^-24 is R `5.9604644775390625e-8` vs `5.960464477539063e-8`; 2^-44 is `5.6843418860808015e-14` vs `5.684341886080802e-14`; 2^89 is `6.1897001964269014e+26` vs `6.189700196426902e+26`. This changes both identities:
  - `settings = list(eps = 2^-24)` gives recipe_id `f5795408…` in R and `e06b516b…` in Python.
  - `crt_table_fingerprint(data.frame(v = 2^-24))` gives `086d276d…` in R and `faa88462…` from the Python canonical form.

  2^-24 is float32's unit roundoff, so this is a value real settings and columns can hold. Fix: once the bisection finds `lo`, also try the (lo-1)-digit decimal one unit above, and the one below, the correctly rounded one. Add every power of two to numbers.json. The population is enumerable, and the current 539 cases contain none that differ, so neither the R test nor the Python cross-check can fail on this.
  - **Rule:** code-check.md "A fixture that cannot reach the failure mode" ; code-check.md "Verification that reads its own output"

- **[severity: bug]** R/crt_receipt_jcs.R:53 (with 76) — This is the round-1 named-vector fix reproduced one axis over. `if (is.factor(x)) x <- as.character(x)` runs before the new `!is.null(names(x))` refusal, and `as.character()` drops a factor's names. So `factor(c(CO = "x", CH = "y"))` and `factor(c(CH = "x", CO = "y"))` both serialize as `["x","y"]` and hash alike, with no error (measured). The same goes for `dim`: `matrix(1:4, 2)` and `matrix(1:4, 1)` both become `[1,2,3,4]`, while Python would give nested arrays. Fix: run the names check before the factor conversion, and refuse an atomic with a `dim` attribute.
  - **Rule:** code-check.md "Serialization loses meaning silently"

- **[severity: fragile]** R/crt_receipt_compare.R:255 and :264 — `receipt_summary_tolerance()` and `receipt_tables_within()` decide that two tolerances are the same with `identical()`. That check is sensitive to type and to member order. `receipt_diff()` decides the same question through `crt_receipt_jcs()`, which is not. The receipt that `crt_receipt_write()` returns holds a tolerance of 1 as double `1`, in the caller's member order. Read back from disk, the same receipt holds integer `1L` with members sorted. Measured: `crt_receipt_compare(<write() result>, <path to b>)` returns `different` (`refuse result.summary[tot]`), while the same pair given as two paths returns `equivalent` (`within 1`). With two or more tolerance columns, caller order alone makes `receipt_tables_within()` report "the builds declare different tolerances". Fix: compare `crt_receipt_jcs(ta) == crt_receipt_jcs(tb)` in both places.
  - **Rule:** code-check-r.md "Cross-function consistency for label/string normalization"

- **[severity: fragile]** R/crt_receipt_compare.R:94 and :267-272 (through R/crt_table_fingerprint.R:98-108) — The round-1 fix for re-read tables listed two known-bad shapes (integer, all-NA logical) instead of handling everything else. A supplied table whose tolerance column came back as character, or is missing, still aborts the whole comparison. `table_decimals()` raises "A tolerance applies to double columns only" or "`tolerance` names "km", which is not a column". A table missing a *non*-tolerance column is handled correctly: it is reported as `refuse … re-read: the table supplied for b is not the one its receipt fingerprinted` (all three measured on the worked case). The same condition, "this is not the table the receipt fingerprinted", either aborts or is reported, depending on which column is affected. Fix: catch a fingerprinting failure of a supplied table in both places and report it as that refusal.
  - **Rule:** code-check.md "A guard that fails toward pass"

- **[severity: fragile]** R/crt_receipt_write.R:230 — An unnamed config file is keyed by "the path as given", and absolute paths are accepted (parts refuse them; config files do not). That key goes into `recipe_id`. The same `settings.csv` bytes in two checkouts give recipe_ids `e2c0724b…` and `865aa249…` (measured). So a `system.file()` or absolute path makes the recipe machine- and install-dependent, and every cross-machine rebuild compares `different`. `keys =` catches it only when a declaration is passed. Fix: refuse absolute and `..` paths for unnamed config files, as `receipt_parts()` does, or require names.
  - **Rule:** none

- **[severity: fragile]** R/crt_receipt_migrate.R:249-282 (and :113 for `time =`) — `receipt_migrate_tidy()` says it places "what the schema would refuse into legacy rather than write an invalid receipt". It only checks `recipe.code`, `recipe.inputs` and `context.toolchain`. The mapped `context.time`, `recipe.seed`, `context.host`, `output.name` and `output.scope` go in unchecked, and so does the `time =` argument. A link manifest with `built: "2026-11-01 17:04:12"`, `seed: "42"` or `host: ""` migrates and is written by the new `path =` without complaint, and `crt_receipt_validate()` then fails it on all three (measured). Fix: check these against the schema's shapes in tidy, and move a value that fails into `context.legacy`; refuse a malformed `time =`.
  - **Rule:** code-check.md "A guard that fails toward pass"

- **[severity: fragile]** R/crt_table_fingerprint.R:146 and :159 — The spec says dates are written `YYYY-MM-DD`, but a year outside 0000-9999 is not refused. R writes `-221-09-04` and `10183-09-21`, and a POSIXct gives `14645-06-30T15:06:40Z` (measured, macOS R 4.5.2). Python's `datetime` cannot hold those years, and other languages pad differently, so no second implementation reproduces these fingerprints. Epoch milliseconds read as seconds lands in year ~57,000 and is fingerprinted with no error. Fix: refuse years outside 0000-9999, as fractional seconds are refused.
  - **Rule:** none

## Checked and clean
- Round-1 fixes:
  - integer64 is refused in `jcs_value()`, `table_cells()` and `receipt_reread_numeric()`.
  - UTF-8: fingerprints, a latin1-marked string and the worked-case recipe_id came out byte-identical under `LC_ALL=C`, `en_US.UTF-8` and `en_US.ISO8859-1`.
  - An NA toolchain version is refused in both the writer and migrate.
  - `crt_receipt_migrate(path =)` on both legacy examples reads back and validates.
  - A tolerance column re-read as integer or all-NA logical now fingerprints.
- jsonlite reads JCS integers at and above 2^63 back as the same double.
- No `$ref` in either schema has sibling keywords.
- The two receipt schema copies are pinned byte-identical by a test.
- The widened gh-pages freeze guard keeps the fetch and `ls-tree` failure paths under `set -e`.
