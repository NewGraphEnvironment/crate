## Outcome

`crt_table_fingerprint()` (and so `crt_receipt_write()` and `crt_receipt_compare()`'s re-read keying) now fingerprints a subclass of `Date` or `POSIXct`, data.table's `IDate` above all, as its base class. `table_cells()` admits a class vector ending in `"Date"` or `c("POSIXct", "POSIXt")` on numeric storage (or all-NA logical), still refuses extra attributes, dims and lists, and rebuilds the column as the plain base class before spelling, so no subclass method decides the text. Learned at code-check: the old exact class match had no storage test, and base R's `seq()` stores POSIXct as integer seconds, so a storage test written for the new rule silently narrowed the old one; the fix was checked by enumeration, not by a reviewer's silence.

## Measurement

- The issue's reprex: `data.table::as.IDate("2026-11-06")` and `as.Date("2026-11-06")` both fingerprint to `1f1a7f8ee69670f33e2cbf737fb5ef1d8a7b1d8e468e36d522ce101c881100fb`.
- Old (9074750) vs new `table_canonical()` over 4 classes (Date, POSIXct, IDate, a POSIXct subclass) x 10 storages (40 cells): base classes byte-identical in 17/20; the 3 differences (logical non-NA Date and POSIXct, complex Date, old spelling TRUE as 1970-01-02) are accepted refusals, as no R constructor produces them. All 20 subclass/base pairs spell identically.
- Both new positive tests fail against the old code. Full suite 235 tests pass; R CMD check 0 errors, 0 warnings.

## Owed

- Tell knowledge#158 its `IDate` → `Date` conversion can go once crate releases this

Closed by: PR for #49
