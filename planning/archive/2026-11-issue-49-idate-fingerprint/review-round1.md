# Code review, round 1: issue #49 (IDate / Date and POSIXct subclasses in table_cells)

## Checklist read
- code-check-python.md: in full.
- code-check-r.md (by heading): read "Read-back shape must match write-back shape"; "A database driver's value is not a base R type — and it fails twice"; "`identical(-0, 0)` is TRUE in R, and the two still digest differently"; "`c()` dispatches on its first argument, so `c(NULL, <Date>)` is a plain number"; "as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone"; "Never name a durable artifact by a hash the library reserves the right to change"; "Cross-function consistency for label/string normalization"; "A library call that dispatches on a global option is not a pure function". 8 read, the other 109 headings not read.
- code-check-shell.md (by heading): no heading names a tool, shape or pattern this diff uses. 0 read, all headings not read.
- code-check-spatial.md (by heading): no heading applies. 0 read, all headings not read.
- code-check.md (by heading): the prose of all 14 H3s under `## Mechanisms` (table rows skipped). No headings read under "Rules that stand alone", Security, or Spreadsheets and PDFs.

## Findings

- **[severity: bug]** R/crt_table_fingerprint.R:151 (`is_time <- table_ends_with(cls, c("POSIXct", "POSIXt")) && is.double(v)`): a plain POSIXct stored as integer used to be fingerprinted. It is now refused with "has no canonical form", and the hint printed beside that refusal tells the caller to use a POSIXct column. Base R creates integer-stored POSIXct in ordinary use. On R 4.5.2, `seq(as.POSIXct("2026-01-01", tz = "UTC"), by = "hour", length.out = 2)` and `as.POSIXct(1762400000L, tz = "UTC")` both return `typeof()` "integer". I ran the code from before the change (9074750) and the code from after it on the same `data.frame(t = <that seq>)`:
  - before: `{"columns":["t"],"rows":[["2026-01-01T00:00:00Z"],["2026-01-01T01:00:00Z"]]}`
  - after: `Column t has class <POSIXct/POSIXt>, which has no canonical form.`

  The old whitelist was `identical(cls, c("POSIXct","POSIXt"))` with no storage test. The Date branch on the next line accepts both storage types (`is.double(v) || is.integer(v)`), but the POSIXct branch accepts only double. That breaks the brief's requirement that plain classes keep their spellings. A table that was fingerprinted before this change, such as one already in a receipt, can no longer be fingerprinted. `crt_receipt_compare()` re-read keying (R/crt_receipt_compare.R:294) calls `table_cells()` on every non-tolerance column, and through `receipt_reread_fingerprint` it now fails on such tables. `crt_schema_apply`'s datetime coercion passes a POSIXct input through with its storage unchanged, so an integer column reaches the fingerprint as integer. Fix: also accept integer storage, `(is.double(v) || is.integer(v))`. The rebuild on line 164 already converts with `as.double(unclass(v))`, so the spelling stays the same. The tests did not catch this because every POSIXct test value is built with `as.POSIXct(<character>)` or `as.POSIXct(<double>)`, which always store double.
  - **Rule:** code-check.md "A proxy is not the property" ; code-check.md "A fixture that cannot reach the failure mode"

No other issues found:
- Rebuilding Date and POSIXct subclasses as the base class keeps the spellings of existing plain double Date and POSIXct columns, and of integer Date columns.
- An extra attribute is still refused before the rebuild runs, so the rebuild never drops one.
- `table_ends_with()` handles a NULL class and a class vector shorter than the base.
- `table_decimals()` still refuses a tolerance on a Date or POSIXct subclass, through `inherits()`.
- The JSON serializer (R/crt_receipt_jcs.R) refuses every Date and POSIXt, so it cannot disagree with this change.
- Both changed test files pass: 51 and 189 expectations, with 0 failures and 0 errors.
