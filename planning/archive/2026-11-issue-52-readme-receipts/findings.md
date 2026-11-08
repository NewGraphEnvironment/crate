# Findings — README presents crate as a file reader; the provenance receipts are buried (#52)

## Issue context

**If we do it:** someone landing on the repo or the pkgdown home page learns that crate does two jobs, canonical schemas for changing inputs and provenance receipts for outputs, and sees a receipt written and compared. **If we never do:** the README keeps presenting crate as a file reader, and the receipt contract (half the package since 0.12.0) is found only by those who already know it is there.

## Problem

`README.md` describes the package as it was before the receipts landed ([#43](https://github.com/NewGraphEnvironment/crate/issues/43)):

- The tagline is "Stable file readers for shape-shifting data sources.", while the package title has been "Canonical Schemas and Data Governance for Changing Data" since [#45](https://github.com/NewGraphEnvironment/crate/issues/45).
- The opening paragraphs name only `crt_ingest()` and `crt_schema_conform()`.
- Receipts first appear at line 142 of 151, as a bullet under "What crate handles today", an inventory of schemas. The paragraph after it ("Each addition = a YAML in `inst/extdata/schemas/` + a registry row") reads as if receipts were a schema.
- The one example is the bcfishpass ingest; nothing shows a receipt written or two builds compared.

Separately, `vignettes/receipt.Rmd`'s canonical-form list ("Dates are `YYYY-MM-DD`; datetimes are UTC …") does not say that a subclass such as data.table's `IDate` is spelled as its base class, which `?crt_table_fingerprint` says since 0.14.0 ([#49](https://github.com/NewGraphEnvironment/crate/issues/49)).

## Proposed

- [ ] Tagline and opening paragraph name both jobs: canonical schemas for changing inputs, provenance receipts for outputs
- [ ] A `## Provenance receipts` section near the top: what a receipt answers, a short write-and-compare example, links to `vignette("receipt")`, the published receipt schema and the test vectors
- [ ] Receipts and the STAC field schemas move out of the schema inventory, so its "each addition" paragraph describes schemas only
- [ ] The receipt vignette's canonical-form list says a `Date` or `POSIXct` subclass (data.table's `IDate`) is spelled as its base class
