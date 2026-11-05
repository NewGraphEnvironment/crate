# Code-check review, round 3 (#43)

## Checklist read

- code-check-python.md: in full.
- code-check-r.md: 36 headings read, 81 not. Read: Read-back shape must match write-back shape; A `data-raw/` script must load the source tree; Tests that silently do not run; Cross-function consistency for label/string normalization; `$` on a list partial-matches; as.POSIXct on a Date / character; `nzchar(NA)` is TRUE; `paste()` with a zero-length argument; `strsplit()` drops a trailing empty field; `identical()` on two reader results; `sort()` and `order()` collate by `LC_COLLATE`; A library call that dispatches on a global option; `identical(-0, 0)`; `file(open = "wb", encoding = )`; A scalar helper called from `glue()` or `mutate()` recycles; Never name a durable artifact by a hash the library reserves the right to change; `vapply(..., USE.NAMES = FALSE)`; `deparse()` re-encodes non-ASCII; `package_version()` errors on a pre-release; `tryCatch(warning = )` DISCARDS; `match()` treats NA as a matchable VALUE; `as.integer("NaN")`; `expect_false(identical(x, y))`; `unlist()` prefixes a `split()` group's name; `tolerance` in testthat is RELATIVE; `[[` on a named ATOMIC vector; `data.frame()` recycles a scalar; `tempfile()` lives in the session tempdir; R's `yaml` returns a mixed int/float sequence as a list; Verify a float-formatting fix in its consumer; A `pkg::` call in a test; `c()` dispatches on its first argument; `c(name = x)` keeps `x`'s own name; `read.delim()` quotes by default; ajv honours keywords beside a `$ref`; `ifelse()` with an all-NA test.
- code-check-shell.md: 7 headings read, 63 not. Read: Quoting; Git plumbing calls whose default answers a different question; `grep -c` prints the count AND exits 1; A failed `git fetch` leaves the comparison reading stale refs; A fetch can fail and still deliver the commit; `for x in $(cmd | grep … || true)` hides a failing `cmd`; `a && b || c`.
- code-check-spatial.md: 3 headings read, 91 not. Read: Canonicalize geometry before hashing it; An offset regex must be anchored to a time; A reader that accepts a UTC offset may not be applying it.
- code-check.md: the prose of all 14 H3s under `## Mechanisms` (table rows skipped), plus "Bare `y`, `n`, `on`, `off`, `yes`, `no` are booleans in YAML 1.1". 22 others not read.

How this round checked: probes under `devtools::load_all()` on macOS (R 4.5.2, arm64), and the same code sourced into `rocker/r-ver:4.5.2` (Linux, glibc). That Linux check ran all 2,637 number vectors and all 13 fingerprint vectors: 0 mismatches. The probe scripts are in the session scratchpad `cc3/` (`p1.R` to `p6.R`, `linux_vec.R`, `linux_fp.R`).

## Findings

- **[severity: bug]** R/crt_receipt_jcs.R:47-84 (also :125, :127) — **The mechanism is a denylist standing in for an allowlist.** `jcs_value()` refuses four classes by name (integer64, Date, POSIXt, difftime) and two attributes (names, dim). Every other classed value or value with attributes goes on, as long as `is.list()`, `is.character()`, `is.numeric()` or `is.logical()` is TRUE. It then reaches `[[`, `[`, `as.character()`, `abs()`, `==` and `sprintf()`, all of which dispatch on the class. So what gets written depends on which methods the class's package happens to define. Measured on macOS:
  - **Invalid JSON gets hashed.** `as.hexmode(493L)` is written `1ed` and `data.table::as.ITime(60L)` is written `00:01:00`, both bare. `as.character()` dispatches to the print method, and `jcs_atomic()` writes the result as a number token. `crt_receipt_recipe_id()` returns a sha256 over `{"mode":1ed}`. `crt_receipt_write()` then fails inside `jsonlite::prettify()` with "lexical error: malformed number".
  - **The wrong number is written.** `as.octmode("755")`, whose value is 493, is written `755`.
  - **Meaning is dropped, so two settings hash alike.** `ts(1:2, start = 1990)` and `ts(1:2, start = 2000)` both give `[1,2]`. A double with a `units` attribute gives `5` for both km and m. An S4 class that contains numeric loses its slots (`new("Num", 5, u = "km")` gives `5`). An `sfg` POINT gives `[1,2]`.
  - **A classed list takes the list branch without any class check.** POSIXlt and `package_version` recurse forever, because their `[[` method returns the same class. They abort with "evaluation nested too deeply", which names nothing. A data frame is written column-wise, so `data.frame(a = 1L)` hashes the same as `list(a = 1L)`. A two-row frame turns every column into an array. jsonlite writes the same frame row-wise (`[{"a":1,"b":"x"}]`), so the file header's claim that values map "as jsonlite's auto_unbox does" is false here.
  - **Some classes are refused only by accident**, with a message about something else: the units package ("both operands of the expression should be units objects"), `lubridate::period()`, `haven_labelled`.

  All of these reach `recipe_id` through `recipe$config$settings`, which is written verbatim. The fix is an allowlist ahead of the list branch: accept `oldClass()` of NULL, `"factor"` or `"AsIs"` (and decide on character subclasses such as glue and fs_path), refuse everything else, and `unclass()` before any generic is called.
  - **Rule:** code-check.md "Serialization loses meaning silently" ; code-check.md "A guard that fails toward pass"

- **[severity: bug]** R/crt_table_fingerprint.R:166-167 — The same mechanism reaches `table_cells()`. The integer branch accepts any classed integer except integer64, and `as.character(v[!na])` dispatches. Measured: an octmode column gives `"755"` for 493, hexmode gives `"ff"`, ITime gives `"00:01:00"`, and an integer-storage `units` column gives `"5"` with its unit dropped. The documented canonical form says "Integers are their decimal digits", and Python given the same integers writes `"493"`. The double branch refuses any class (`is.null(oldClass(v))`), so the two numeric branches disagree. `haven_labelled` integers abort by accident inside vctrs.
  - **Rule:** code-check.md "Serialization loses meaning silently"

- **[severity: bug]** R/crt_table_fingerprint.R:139-141, :74-76 — A matrix column is fingerprinted as extra rows, and two different tables then share a fingerprint. For a two-row frame with `d$m <- matrix(1:4, 2)`, `length(v)` is 4. `v[!na]` flattens the matrix, and `do.call(paste, ...)` recycles the other columns against it. The canonical JSON holds 4 rows, `[["a","1"],["a","3"],["b","2"],["b","4"]]`, while the receipt records `rows: 2`. The pairing of matrix columns within a row is lost: tables with rows (1,3)/(2,4) and (3,1)/(2,4) give the same fingerprint (`crt_table_fingerprint(d1) == crt_table_fingerprint(d2)` is TRUE). This is silent, and `sf::st_coordinates()` or `cbind()` inside `mutate()` produces such columns. A one-column matrix such as `scale()`'s output works only by accident. Refuse `!is.null(dim(v))` (and data-frame columns) at the top of `table_cells()`.
  - **Rule:** code-check.md "Serialization loses meaning silently"

- **[severity: bug]** R/crt_table_fingerprint.R:147, :161 — Years 1-999 are not zero-padded on Linux, so the same table gets a different fingerprint on the developer's Mac and on CI (ubuntu-24.04). `format(x, "%Y-%m-%d")` goes through the platform's strftime. Measured with R 4.5.2 for Date 0999-03-04 and POSIXct 0050-01-01: macOS gives `0999-03-04` and `0050-01-01T00:00:00Z`; rocker/r-ver (glibc) gives `999-03-04` and `50-01-01T00:00:00Z`. Row order changes with it. The canonical form documents `YYYY-MM-DD`, and Python's isoformat writes `0999-03-04`. Round 2's `table_year_check()` admits years 1-999, but none of the 13 fingerprint vectors and no test holds such a year. That is why they all pass on Linux. Build the string from `as.POSIXlt(..., tz = "UTC")` fields with `sprintf("%04d-%02d-%02d", ...)`.
  - **Rule:** code-check-r.md "Never name a durable artifact by a hash the library reserves the right to change" ; code-check.md "A fixture that cannot reach the failure mode"

- **[severity: bug]** R/crt_receipt_compare.R:147 — Comparing summaries aborts on a receipt list returned by `crt_receipt_write()`. The within-tolerance test `abs(va - vb) <= tol` compares raw values, not canonical ones. The write list holds `NA_real_` for a missing summary value (`is.numeric(NA_real_)` is TRUE), while the same receipt read from disk holds `NULL`. When the two sides differ and a tolerance is declared, `if (NA)` aborts with "missing value where TRUE/FALSE needed". Measured: read vs read gives `different`; write vs write and write vs read both abort. Integer overflow in `va - vb` (two read-back integers more than 2^31 apart) reaches the same `if (NA)`. Round 2 moved the tolerance-equality comparison onto the canonical form (`receipt_same`), but this sibling comparison of the values was left on raw R objects. The guard is `!is.na(va) && !is.na(vb)`, with the subtraction done in double.
  - **Rule:** code-check.md "A fix lands in one of two callers that share a harness"

- **[severity: bug]** R/crt_receipt_write.R:107, :384 — `crt_receipt_write()` writes receipts that fail its own schema, and only `crt_receipt_validate()` notices, after the file is on disk. Measured, each written and then rejected by validate:
  - `output = list(name = "")`: `chk_string()` accepts an empty string, but the schema has minLength 1.
  - `context = list(host = "")`, `host = 5` and `host = NA_character_`: the host is never checked (`context$host %||% Sys.info()[["nodename"]]`).

  A Python reader validating against the schema refuses these receipts. Round 2 fixed the host, time and seed checks in migrate but not this writer.
  - **Rule:** code-check.md "A guard that fails toward pass" ; code-check.md "A fix lands in one of two callers that share a harness"

- **[severity: fragile]** R/crt_receipt_write.R:250 — `recipe.config.files.*` is the sha256 of the config file's bytes as checked out, so `recipe_id` depends on the machine's git line-ending setting. Git for Windows defaults to `core.autocrlf=true`, which checks a CSV out with CRLF. The same commit and the same settings then give another `recipe_id` and a `different` verdict. Python reproduces the bytes it is given, so the two languages still agree with each other; the variation comes from the checkout. Normalise line endings before hashing text config files, or require `.gitattributes` `-text`/`eol=lf` for them and say so in the docs.
  - **Rule:** none

- **[severity: fragile]** R/crt_receipt_migrate.R:94-106, :156 — `context.legacy` is keyed by the record path joined with `.`, so a nested field and a literal dotted key collide, and the later one overwrites the earlier. Measured with `{"extra": {"k": 1}, "extra.k": 2}`: legacy keeps only `"extra.k": 2`. The warning lists `"extra.k"` twice but keeps one value. The roxygen says "nothing is dropped silently". For a field the mapping sends to legacy deliberately there is no warning at all.
  - **Rule:** code-check.md "Serialization loses meaning silently"

- **[severity: fragile]** R/crt_table_fingerprint.R:92-109 — `crt_table_fingerprint(x, c(km = 1e-2, km = 1e-1))` silently uses the last value (`out[tn] <- k`). The writer's path refuses repeated names (`receipt_named_list`), but the exported function does not, so the two disagree about one input.
  - **Rule:** none

## Enumeration

### Mechanism A: the refusal is a denylist, and anything else flows through generics that dispatch on the class

The shared assumption: a value that passes `is.list` / `is.character` / `is.numeric` / `is.logical` carries all its meaning in its bare storage. It reaches `crt_receipt_jcs()` (and through it `recipe_id`, the receipt file, every comparison) and `table_cells()` (and through it `result.fingerprint`). The candidate set is every R value shape and attribute named in the brief, plus the classes found while probing. **37 members.** For each: what jcs does / what table_cells does.

| # | Member | crt_receipt_jcs | table_cells |
|---|---|---|---|
| 1 | NULL | `null`: handled | n/a |
| 2 | NA (scalar, any type) | `null`: handled | `null` cell: handled |
| 3 | NULL vs NA inside a list | both `null`; read back as NULL; JCS equal: handled | n/a |
| 4 | plain character / integer / double / logical | handled; doubles verified on Linux = macOS, 2,637/2,637 | handled; 13/13 vectors on Linux |
| 5 | -0 | `0`: handled | `0` / sign stripped: handled |
| 6 | NaN / Inf | refused: handled | refused: handled |
| 7 | names attribute (atomic) | refused: handled | ignored (a named column has its values only); fine |
| 8 | dim (matrix / array / 1-d table) | refused: handled | **GAP**: rows recycled (finding 3) |
| 9 | factor (levels) | labels: handled | labels: handled |
| 10 | AsIs | length-1 array: handled | chr/int handled; dbl refused (loud, inconsistent) |
| 11 | list (named / unnamed / empty / named-empty) | object / array / `[]` / `{}`: handled | refused (list column): handled |
| 12 | partially named list `list(a = 1, 2)` | `{"":2,"a":1}`, valid JSON; deterministic; noted, not reported | n/a |
| 13 | data frame as a value | **GAP**: column-wise; 1 row collapses to scalars (finding 1) | packed df column refused: handled |
| 14 | tibble as a value | same as 13: **GAP** | same: handled |
| 15 | Date | refused: handled | **GAP**: years 1-999 platform-dependent (finding 4) |
| 16 | POSIXct (tzone) | refused: handled | UTC, whole seconds: handled except years 1-999 (finding 4) |
| 17 | POSIXlt | refused by stack overflow: **GAP** (finding 1) | converted with as.POSIXct: handled (a `tz=""` lt is local time by R's meaning) |
| 18 | difftime | refused: handled | refused (double class): handled |
| 19 | hms | refused (difftime): handled | refused: handled |
| 20 | integer64 / bit64 | refused: handled | refused: handled |
| 21 | units (package) | refused by accident in jcs_numbers: **GAP** (message) | double refused; integer storage **GAP** (finding 2) |
| 22 | units-like attribute on a double | **GAP**: unit dropped, 5 km = 5 m | refused (class): handled |
| 23 | S4 object (no data part) | refused: handled | refused: handled |
| 24 | S4 that contains numeric | **GAP**: slots dropped | refused (class): handled |
| 25 | environment | refused (with the "named vector" message, which is wrong but loud) | n/a |
| 26 | function / formula / symbol / call / expression | refused: handled | n/a |
| 27 | raw | refused: handled | refused: handled |
| 28 | complex | refused: handled | refused: handled |
| 29 | octmode | **GAP**: 493 written as 755 | **GAP**: "755" |
| 30 | hexmode | **GAP**: bare `1ed`, invalid JSON hashed | **GAP**: "ff" |
| 31 | data.table ITime | **GAP**: bare `00:01:00`, invalid JSON | **GAP**: "00:01:00" |
| 32 | ts (tsp) | **GAP**: start dropped | double with class: refused, handled |
| 33 | numeric_version / package_version | refused by stack overflow: **GAP** | list: refused, handled |
| 34 | sfg geometry | **GAP**: POINT is `[1,2]`; line/polygon refused (dim) | sfc list column refused: handled |
| 35 | lubridate Period / Duration | Period refused by accident; Duration is seconds | refused (class) |
| 36 | haven_labelled | refused by accident (vctrs) | int: refused by accident; dbl: refused |
| 37 | character subclasses (glue, fs_path, noquote) / character with attributes | text: handled | text: handled |

Count: in jcs, 22 handled and 15 gaps (8, 12 and 25 counted as handled: deterministic, or refused loudly). In table_cells, 31 handled or not applicable and 6 gaps (8, 15/16, 21, 29, 30, 31).

### Mechanism B: two representations of one receipt meet, and not every comparison goes through the canonical form

The representations are the write list (doubles, NA, caller key order, `I()`), the read list (integers for whole numbers, NULL for null, keys in sorted order), the migrate list, and the vectors' JSON (Python reads every number as a double). Candidate set: every place two of them meet. **14 members.**

1. Write list vs written file (`receipt_write_file`: JCS then prettify). Read back, the JCS is byte-equal (measured, including -2^31, 2^31, 1e21, 0.1+0.2 and `I("CO")`). Handled.
2. `crt_receipt_validate()` on the list vs on the path: schema over the JCS, and recipe_id recomputed through the JCS. Handled.
3. `receipt_diff()` leaves: `show_full()` is JCS. Handled.
4. Summary tolerance equality: `receipt_same()`. Handled.
5. Table tolerance equality: `receipt_same()`. Handled.
6. **Summary value within tolerance (`abs(va - vb) <= tol`) compares raw values: GAP**, finding 5.
7. A re-read table's fingerprint vs the stored one: strings. Handled.
8. A part's `table` name (`identical(ta, tb)`): strings. Handled.
9. recipe_id presence (`is.null`): the write list always holds one, and a migrated receipt holds NULL in both forms. Handled.
10. Migrate: `identical(held, value)` on raw values. Not canonical (1L vs 1 counts as a conflict), but the loser goes to legacy, so nothing is lost. Handled-harmless.
11. Migrate list vs its written file: JCS equal and both valid, measured for the link manifest and for floodplain/all_ff02. Handled.
12. Vector JSON (`parse_int=float`) vs R's `read_json` (integers): the JCS is identical; the crosscheck recomputes. Handled.
13. YAML keys tolerances vs writer tolerances: both pass through `receipt_tolerance()`. Handled.
14. `crt_receipt_read()` version check: a string. Handled.

Size 14: 13 handled, 1 gap.

A related writer-vs-schema meeting, the writer's hand checks against the JSON Schema: the output.name, scope, schema, host, session, toolchain, run, inputs, summary, parts, fingerprint, tolerance, seed and time constraints. 14 checked; **2 gaps** (output.name empty, host), finding 6.

### Mechanism C: a value enters an identity and can depend on the machine, locale, working directory or R version

Candidate set: every input to `recipe_id`, `result.fingerprint`, the config keys and the parts keys. **15 members.**

1. `code` commit, version, dirty: the caller's strings. Handled.
2. Config file key: the name, or a relative path as given (backslashes normalised); absolute and outside paths refused. Handled (the as-given relative path is accepted by design).
3. **Config file value, the sha256 of the checked-out bytes: GAP** (line endings), finding 7.
4. Settings strings: unmarked text must be valid UTF-8 and latin1 is converted, so the locale has no effect. Handled. Not verified: R on Windows reading latin1 as CP1252 for 0x80-0x9F.
5. Settings doubles: JCS numbers equal on Linux and macOS (2,637 vectors). Handled.
6. **Settings with classed values: GAP**, Mechanism A, finding 1. A POSIXlt would also carry the machine's zone and gmtoff, but it is refused, by recursion.
7. inputs: validated strings. Handled.
8. seed: integer and double give the same JSON. Handled.
9. Fingerprint column order: radix sort, C byte order. Handled.
10. Fingerprint character cells: UTF-8, not normalised (by design). Handled.
11. Fingerprint doubles, exact and with a tolerance: 13/13 vectors identical on Linux. Handled.
12. **Fingerprint Date/POSIXct cells: GAP**, platform strftime for years 1-999, finding 4.
13. Fingerprint row order: radix sort over UTF-8 rows. Handled.
14. **Fingerprint integer cells for classed integers: GAP**, R's print form, finding 2.
15. Parts keys (relative path as given; not an identity, but the compare key) and toolchain, host, time and lockfile (context only, defaulted from the working directory or the session, never identity). Handled by design.

Size 15: 11 handled, 4 gaps.

### Workflow guard (.github/workflows/pkgdown.yaml)

Checked: the fetch on its own `||` line under `set -e`; `ls-tree` assigned on its own line before the `grep || true`; two presence checks, one for STAC and one for the receipt schema; the published-set regex covers `receipt/v*/schema.json`. `pkgdown/assets/receipt/v1.0.0/schema.json` is byte-identical to `inst/extdata/receipt/schema/v1.0.0/schema.json`, and a test pins that. No issue.
