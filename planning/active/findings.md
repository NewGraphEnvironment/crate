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
