# Code review, round 1: crate#43 provenance receipt

Branch `43-a-shared-provenance-receipt-a-language-n`, diff `179217a...HEAD` (HEAD 885fbca).

## Checklist read

- code-check-python.md: in full.
- code-check.md: the prose of all 14 H3s under `## Mechanisms`, without the table rows. Not read: the 23 headings under "Rules that stand alone", "Security" and "Spreadsheets and PDFs".
- code-check-r.md, 16 headings read: "A database driver's value is not a base R type — and it fails twice"; "`nzchar(NA)` is TRUE — non-empty checks silently pass NA"; "`sort()` and `order()` collate by `LC_COLLATE`, so a canonical form is locale-dependent"; "`identical(-0, 0)` is TRUE in R, and the two still digest differently"; "Verify a float-formatting fix in its consumer, not through `as.numeric()`"; "ajv honours keywords beside a `$ref`; Python's jsonschema ignores them"; "A `data-raw/` script must load the source tree, not the installed package"; "Read-back shape must match write-back shape"; "`$` on a list partial-matches, so a longer sibling key answers for a missing one"; "Cross-function consistency for label/string normalization"; "Never name a durable artifact by a hash the library reserves the right to change"; "Under `R CMD check`, tests run from a temp dir against the INSTALLED package"; "A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared"; "`strsplit()` drops a trailing empty field, so a trailing separator vanishes"; "`paste()` with a zero-length argument returns length ONE, not zero"; "CSV whitespace: `trim_ws` and `strip.white` do not do what the name suggests". 101 not read.
- code-check-shell.md, 3 headings read: "Git plumbing calls whose default answers a different question"; "A failed `git fetch` leaves the comparison you make next reading stale refs"; "`for x in $(cmd | grep … || true)` hides a failing `cmd`". 67 not read.
- code-check-spatial.md, 1 heading read: "An offset regex must be anchored to a time, or a date looks like a zone". 93 not read.

## What was checked and held

The core byte contract holds across languages and locales. I measured it rather than reading for it:

- R `jcs_numbers()` against Python `rfc8785` on 29,983 random finite doubles from random bit patterns: 0 mismatches.
- R `crt_receipt_jcs()` on 3,000 random nested values: Python parsed each result (`parse_int=float`) and re-serialized it with `rfc8785`. The values used keys and strings drawn from controls, U+007F, U+2028, U+E000, U+FFFF and astral characters. 0 mismatches.
- R `table_canonical()` on 379 random tables against `data-raw/receipt_vectors_crosscheck.py`'s independent canonical form: 0 mismatches. The tables mixed every column type, NA, non-ASCII column names, ties such as 0.5, 1.5 and 2.5, values that round to -0, and random tolerances from 1 to 1e-15.
- I ran all three fuzzers under `LC_ALL=C`, `en_US.UTF-8` and `en_US.ISO8859-1`, with identical results. Every vector file cross-checks in Python with 0 mismatches.
- The receipt tests pass under UTF-8: 0 failed, 0 errors. Under `LC_ALL=C`, `test-crt_receipt_jcs.R` fails 3 assertions. Two of them come from non-ASCII literals in the test source that cannot be translated into the C locale, so they are not code defects. The third, the invalid-UTF-8 refusal, is finding 4.
- Other probes that held:
  - Round trips through `crt_receipt_write()`, `crt_receipt_read()`, `crt_receipt_validate()` and `crt_receipt_compare()` with 9.3e18, 2^60, 1e20, 1e21, 1e-7, -0 and U+2028 come back identical, and the receipts validate.
  - `.Machine$double.xmax` serializes correctly.
  - `10^-k` is exactly the double nearest `1e-k` for k = 0..15 on aarch64.
  - Every `$ref` in both schemas stands alone.
  - The workflow guard fails the step on a failed fetch or a bad ref.

## Findings

- **[severity: bug]** R/crt_receipt_jcs.R:60 and :111 (reached through R/crt_receipt_write.R:301, `receipt_summary`, and `recipe$config$settings`) — **A `bit64::integer64` value is serialized as its raw bits read as a double.**
  - `is.numeric()` is TRUE for an integer64, so `jcs_value()` accepts it. `jcs_atomic()` then sends its storage to `jcs_numbers()`, which reads the int64 bits as a double.
  - Measured: `crt_receipt_jcs(list(rows = bit64::as.integer64(42)))` gives `{"rows":2.0750757125332355e-322}`.
  - `crt_receipt_write(result = list(summary = list(rows = x)))` accepts the value and writes that number with no error. Settings take the same path into `recipe_id`.
  - This is the normal way a count arrives in R: RPostgres returns `count(*)` and every `bigint` as integer64 by default.
  - `crt_table_fingerprint()` already refuses integer64 (R/crt_table_fingerprint.R:164). The JSON serializer, which builds `recipe_id` and every summary, does not.
  - Fix: refuse `inherits(x, "integer64")` in `jcs_value()` with a message naming the path, or convert it exactly. Converting through double is exact below 2^53, so refuse above that.
  - **Rule:** code-check-r.md "A database driver's value is not a base R type — and it fails twice"

- **[severity: bug]** R/crt_receipt_migrate.R:33-34 — **The documented way to save a migrated receipt produces a file crate cannot read.**
  - The `@return` says "Write it with [jsonlite::write_json()]". With `write_json()`'s defaults (`auto_unbox = FALSE`), every scalar is boxed (`"receipt_version":["1.0.0"]`) and every R `NULL` is written as `{}`.
  - Measured: `crt_receipt_read()` on that file aborts with "is receipt version 1.0.0. This crate reads version "1.0.0"".
  - With `auto_unbox = TRUE` the file reads, but `crt_receipt_validate()` fails it: `NULL` is still written as `{}`, so `/recipe/recipe_id must be null`, and `/output/scope` and `/output/schema` must be string or null.
  - No exported function writes an already-built receipt (`receipt_write_file()` is internal), so the documented route is the only one a user has.
  - Fix: export a writer for a receipt list, or have the docs say `writeLines(crt_receipt_jcs(r))`. Test the documented route end to end.
  - **Rule:** code-check.md "Serialization loses meaning silently"

- **[severity: fragile]** R/crt_receipt_compare.R:93 and :269 (through R/crt_table_fingerprint.R:102-107) — **`crt_receipt_compare(tables = )` aborts instead of giving a verdict when a re-read tolerance column is not double.**
  - The vignette's route is to re-read the CSV with `read.csv()`. A column with a declared tolerance whose values are all whole (`write.csv()` writes 12.0 as `12`) comes back integer. One that is all NA comes back logical.
  - `table_decimals()` then aborts with "A tolerance applies to double columns only", and so does the whole comparison.
  - Measured: two builds with `km = c(12, 4)` and `c(12, 4.0000001)` under a tolerance of 1e-3. Receipts alone give `equivalent`. Adding the re-read tables, which is meant to certify more, aborts with an error.
  - The type check `is.double` stands in for "a number that can be rounded to k decimals".
  - Fix: let the spec write an integer column under a tolerance as the double with k decimals, so `sprintf("%.kf", as.double(v))` matches what the writer's double produced, and add the case to the vectors. Or have compare coerce integer to double for tolerance columns before re-fingerprinting.
  - **Rule:** code-check.md "A proxy is not the property"

- **[severity: fragile]** R/crt_receipt_jcs.R:119-127 (`jcs_utf8`, also used by `table_cells()` and `table_canonical()`) — **The invalid-UTF-8 refusal only works in a UTF-8 session.**
  - The guard checks `validUTF8()` after `enc2utf8()`. In a C locale, `enc2utf8()` turns an invalid unmarked byte into the ASCII escape `<e9>`, which is valid UTF-8, so the check passes.
  - Measured on the latin1 bytes of `café`:
    - `en_US.UTF-8`: aborts with "not valid UTF-8".
    - `LC_ALL=C`: serializes it as `"caf<e9>"` and hashes that into the fingerprint (`48b220ff…`).
    - `en_US.ISO8859-1`: `"café"` (`b1faa454…`).
  - One input therefore gives an error or two different fingerprints depending on the machine's locale. A C locale is what an Rscript under cron or in a container gets with no `LANG`.
  - The test of the refusal (test-crt_receipt_jcs.R:101) runs only in the session's locale. It fails under `LC_ALL=C`.
  - Fix: decide validity before converting. Treat every unmarked non-ASCII string as UTF-8 whatever the locale (mark it, then refuse it if it is invalid), and convert only strings explicitly marked latin1.
  - **Rule:** code-check.md "A guard that fails toward pass"

- **[severity: fragile]** R/crt_receipt_jcs.R:66-68 — **A named atomic vector loses its names, so two different settings get one `recipe_id`.**
  - A named atomic vector serializes as an array and the names are dropped without a word.
  - Measured: `list(s = list(t = c(CO = 0.05, CH = 0.07)))` gives `{"s":{"t":[0.05,0.07]}}`. `c(CH = 0.05, CO = 0.07)` hashes the same, so two different resolved settings get one `recipe_id`, and the receipt cannot even show which key had which value.
  - A named vector is the idiomatic R shape for per-species thresholds in `recipe$config$settings`. A Python writer would hold it as a dict, an object, and compute another id.
  - The header documents the jsonlite mapping, but nothing refuses the input that mapping loses.
  - Fix: abort on an atomic vector with non-empty names, telling the caller to use `as.list()` for an object or `unname()` for an array.
  - **Rule:** code-check.md "Serialization loses meaning silently"

- **[severity: fragile]** R/crt_receipt_write.R:364 — **The toolchain check accepts `NA_character_`, so `crt_receipt_write()` writes a receipt that fails crate's own schema.**
  - `is.character(v) && length(v) == 1L && nzchar(v)` passes `NA_character_`, because `nzchar(NA)` is TRUE.
  - Measured: `context = list(toolchain = list(Python = NA_character_))` writes `"Python":null`, and `crt_receipt_validate()` then reports `/context/toolchain/Python must be string`.
  - Fix: add `!is.na(v)`. The same predicate in `receipt_migrate_tidy()` (R/crt_receipt_migrate.R:264) is safe today only because JSON null arrives as `NULL`.
  - **Rule:** code-check-r.md "`nzchar(NA)` is TRUE — non-empty checks silently pass NA"
