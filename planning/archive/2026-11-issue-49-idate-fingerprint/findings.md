# Findings — crt_table_fingerprint() refuses data.table's IDate, a Date subclass (#49)

## Issue context

**If we do it:** a table read with `data.table::fread()` fingerprints as it comes, and its date column gets the same canonical form as a `Date`. **If we never do:** every reader of a receipt-bearing table read through data.table converts each `IDate` column by hand first, and one that forgets fails at the receipt.

## Problem

`data.table::fread()` reads an ISO date column as `IDate`, whose class is `c("IDate", "Date")`. `crt_table_fingerprint()` (and so `crt_receipt_write()`) refuses it, although it fingerprints a `Date`:

```r
x <- data.frame(d = data.table::as.IDate("2026-11-06"))
crate::crt_table_fingerprint(x)
#> Error: Column d has class <IDate/Date>, which has no canonical form.
#> ℹ Fingerprint character, factor, integer, double, logical, Date or POSIXct columns; ...
crate::crt_table_fingerprint(data.frame(d = as.Date("2026-11-06")))
#> [1] "1f1a7f8ee69670f33e2cbf737fb5ef1d8a7b1d8e468e36d522ce101c881100fb"
```

crate 0.12.0, data.table 1.18.2.1. Found by knowledge#158, whose check converts `IDate` to `Date` before writing each receipt.

## Proposed

- [ ] Treat any column inheriting from `Date` as a `Date` (`inherits(x, "Date")` in place of a class match), so `IDate` gets `YYYY-MM-DD`; the same question for `POSIXct` subclasses
- [ ] A test that an `IDate` column and the same `Date` column give the same fingerprint

## Code-check (branch, 3 rounds incl. enumeration)

- Round 1: integer-stored POSIXct (`seq()` output) refused by a double-only storage test; fixed (df71ff7), with all-NA logical storage, both accepted by the old exact match.
- Round 2 (inside round 1's fix): a Date/POSIXct on logical storage with non-NA values, or a Date on complex storage, was spelled by the old code (TRUE as day/second 1) and is now refused. **Accepted refusal**: no R constructor makes such a column, only `structure()`/`class<-` on a raw vector, and spelling TRUE as 1970-01-02 is not a canonical form worth keeping.
- Enumeration (terminal): 4 classes (Date, POSIXct, IDate, a POSIXct subclass) x 10 storages (logical all-NA, logical, integer, double, double out of range, complex, character, raw, empty double, empty integer), old (9074750) vs new `table_canonical()`. Base classes: 17/20 byte-identical; the 3 differences are exactly round 2's accepted refusals. Subclasses: every difference is refused -> accepted, and all 20 subclass/base pairs spell identically under the new code.
