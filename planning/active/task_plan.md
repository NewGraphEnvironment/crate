# Task: crt_table_fingerprint() refuses data.table's IDate, a Date subclass (#49)

`data.table::fread()` reads an ISO date column as `IDate`, whose class is `c("IDate", "Date")`. `crt_table_fingerprint()` (and so `crt_receipt_write()`) refuses it, although it fingerprints a `Date`. crate 0.12.0, data.table 1.18.2.1. Found by knowledge#158, whose check converts `IDate` to `Date` before writing each receipt.

Branch `49-crt-table-fingerprint-refuses-data-table` off origin/main (9074750). No issue comments.

## Context from exploration

- `table_cells()` (`R/crt_table_fingerprint.R:145-147`) whitelists classes by exact match
  (`identical(cls, "Date")`, `identical(cls, c("POSIXct", "POSIXt"))`), so an `IDate` column
  aborts in `crt_table_fingerprint()`, `crt_receipt_write()`, and `crt_receipt_compare()`'s
  re-read keying (`R/crt_receipt_compare.R:294` calls `table_cells()`).
- The exact match is deliberate (comment at :142-144): a class decides the spelling, so an
  unknown class is never printed through its own methods. The fix keeps that: a subclass is
  accepted only when its base class sits at the end of the class vector, and it is
  normalized to the plain base class before spelling, so no subclass method decides the text.
- The extra-attribute guard (:150) still runs on the original column.
- The tolerance guard (:105) already excludes `inherits(x, c("Date", "POSIXt"))`; unchanged.
- data.table is not in DESCRIPTION; tests build `IDate` with `structure()`.
- Only `crt_table_fingerprint()`'s roxygen names the date classes.

## Decided at the gate

Approved by the owner at the plan gate, 2026-11-06:

- POSIXct subclasses (the issue's open question): accepted the same way, class vector ending
  in `c("POSIXct", "POSIXt")`, normalized to plain POSIXct.
- Subclass test is "base class at the end", not bare `inherits()`: a class listing `Date`
  mid-vector is not a Date subclass in the S3 sense.
- No data.table dependency, not even Suggests.
- NEWS + version bump left to `/gh-pr-merge`, as for #47.

## Phase 1: Accept and normalize Date / POSIXct subclasses

- [x] `R/crt_table_fingerprint.R` `table_cells()`: `known` accepts a class vector ending in
      `"Date"` (integer or double storage) or ending in `c("POSIXct", "POSIXt")` (double);
      after the refusal checks, rebuild such a column as a plain `Date` / `POSIXct` from its
      numeric values, so the existing branches spell it
- [x] Comment the rule beside the whitelist comment, in the file's voice
- [x] Roxygen "The canonical form": dates and datetimes include their subclasses
      (data.table's `IDate`), spelled as the base class; regenerate `man/` with `devtools::document()`

## Phase 2: Tests

- [x] `tests/testthat/test-crt_table_fingerprint.R`: an `IDate` column (integer storage) and the
      same `Date` give the identical canonical JSON and fingerprint, NA included
- [x] A POSIXct subclass gives the same canonical JSON as the plain POSIXct
- [x] Still refused: a class with `Date` not last (e.g. `c("Date", "foo")`), and an `IDate`
      carrying an extra attribute
- [x] `crt_receipt_compare()` re-read path: a table with an `IDate` key column pairs rows with
      its `Date` twin

## Owed at the end (reported, done after merge)

- [ ] Tell knowledge#158 its `IDate` → `Date` conversion can go once crate releases this

## Validation

- [x] Tests pass (`devtools::test()`), `R CMD check` clean
- [x] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [x] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

Verification: the issue's reprex (`data.table::as.IDate("2026-11-06")` vs `as.Date`) run against
the loaded package gives the same hash (`1f1a7f8e…` for the Date); the receipt test vectors in
`inst/extdata/receipt/vectors/v1.0.0/` still pass unchanged, proving existing spellings did not move.
