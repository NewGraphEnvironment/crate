# Code review, round 2: issue #49 (Date and POSIXct subclasses in table_cells)

## Checklist read
- code-check-python.md: in full.
- code-check-r.md: read by heading. Read 7 sections: "A database driver's value is not a base R type — and it fails twice"; "as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone"; "`sort()` and `order()` collate by `LC_COLLATE`, so a canonical form is locale-dependent"; "`identical(-0, 0)` is TRUE in R, and the two still digest differently"; "Never name a durable artifact by a hash the library reserves the right to change"; "`c()` dispatches on its first argument, so `c(NULL, <Date>)` is a plain number"; "`ifelse()` with an all-NA test returns a logical vector, whatever `yes` and `no` are". Did not read the rest (about 120 headings).
- code-check.md: read the prose of all 14 H3s under `## Mechanisms`, skipping the table rows. Did not read any other section (about 30 headings).
- code-check-shell.md, code-check-spatial.md: no heading covers anything this diff uses. Read 0 sections.

## Method
- Sourced `git show 9074750:R/crt_table_fingerprint.R` into an env whose parent is `asNamespace("crate")`. Compared old and new `table_canonical()` byte for byte on single-column frames.
- The grid crossed {"Date", c("POSIXct","POSIXt")} with these storages: double (also fractional, NaN, 1e15), integer, all-NA logical, logical with TRUE/FALSE values, character, complex, raw, zero-length logical, with names, and with a tzone attribute on double and integer storage. It also covered `seq()` of a POSIXct and of a Date (both integer storage).
- Results:
  - Identical bytes for every double, integer and all-NA logical case, with or without names or tzone, including fractional seconds (both abort the same way), NaN (null) and `seq()` output.
  - Character, raw and complex POSIXct: the old code also aborted, so these are intended or unchanged refusals.
- Ran test-crt_table_fingerprint.R (14), test-crt_receipt_compare.R (19) and test-crt_receipt_vectors.R (6): 0 failed, 0 errors, 0 skipped. No file under inst/extdata/receipt/vectors/ is in the diff.

## Findings

- **[severity: fragile]** R/crt_table_fingerprint.R:152 — The `on_number` storage test still refuses three storage/class combinations that the code at 9074750 fingerprinted to bytes:
  - Date or POSIXct on **logical storage with non-NA values**. `structure(c(TRUE, NA, FALSE), class = "Date")` was `["1970-01-02"], null, ["1970-01-01"]`. The POSIXct version was `1970-01-01T00:00:01Z` / `00:00:00Z`.
  - Date on **complex storage**. `structure(1+0i, class = "Date")` was `"1970-01-02"`.

  The round-1 fix admits logical storage only when it is all NA (`is.logical(v) && all(is.na(v))`). The old exact-class match had no storage test, and `as.POSIXlt()` coerced TRUE/FALSE and complex to day or second counts. So the HARD REQUIREMENT ("every column the code before the change fingerprinted must fingerprint to the same bytes now") does not hold for these inputs: they now abort with "has class <Date>, which has no canonical form."

  Reachability is very low. I know of no R constructor (as.Date, seq, `[<-.Date`, c, ifelse, data.table, readr, vctrs) that yields a logical-with-values or complex Date or POSIXct. Only `structure()`, `class<-` or `oldClass<-` on a raw vector does. So no realistic column moves. If the requirement is meant literally, the fix is `on_number <- is.double(v) || is.integer(v) || is.logical(v)` (with `as.double()` keeping TRUE as 1, as before). That restores the old bytes for logical storage. Complex Date would still need its own decision. If such columns are out of scope, record it as an accepted refusal next to the character-storage one.
  - **Rule:** code-check.md "A guard that fails toward pass" (its "Which direction it fails" clause: where a new guard replaces an old one, prove what each catches by restoring the old one; here the replacement refuses a subset the old one accepted)

No other issues found:
- The rebuild `structure(as.double(unclass(v)), class = ...)` drops names and tzone. Neither is read by the spelling, since `as.POSIXlt(tz = "UTC")` ignores tzone, and the bytes match the old code.
- `table_ends_with()` is correct for lengths 0, 1 and 2, and `is_date` and `is_time` cannot both be true.
- `table_decimals()` still refuses a tolerance on an IDate (integer) column with the same message as before.
- The `crt_receipt_compare()` keying at R/crt_receipt_compare.R:294 goes through the same `table_cells()`, so an IDate and a Date key column spell the same.
