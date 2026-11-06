# Package index

## Ingest

Read a registered source file to its canonical shape.

- [`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
  : Ingest a registered upstream file and return canonical-shape data
- [`crt_files()`](https://newgraphenvironment.github.io/crate/reference/crt_files.md)
  : List registered (source, file_name) entries crate knows how to
  ingest

## Schemas

Declared canonical shapes, and conforming a frame to one.

- [`crt_schema_cols()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_cols.md)
  : What each column of a registered schema means
- [`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md)
  : Conform a data frame to a registered canonical schema
- [`crt_schema_fingerprint()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_fingerprint.md)
  : Fingerprint a capture's column set
- [`crt_schema_grade()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_grade.md)
  : Which records can answer which question
- [`crt_schema_variant()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_variant.md)
  : Name the known version each record was captured with

## Provenance receipts

Write, read and compare one receipt per output: how it was made and what
came out, judged identical, equivalent within a declared tolerance, or
different.

- [`crt_receipt_compare()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_compare.md)
  : Compare two provenance receipts
- [`crt_receipt_keys()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_keys.md)
  : Read a package's receipt declaration
- [`crt_receipt_migrate()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_migrate.md)
  : Read an older provenance record as a receipt
- [`crt_receipt_read()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_read.md)
  : Read a provenance receipt
- [`crt_receipt_validate()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_validate.md)
  : Validate a provenance receipt
- [`crt_receipt_write()`](https://newgraphenvironment.github.io/crate/reference/crt_receipt_write.md)
  : Write a provenance receipt
- [`crt_table_fingerprint()`](https://newgraphenvironment.github.io/crate/reference/crt_table_fingerprint.md)
  : Fingerprint a table's values

## Package

- [`crate`](https://newgraphenvironment.github.io/crate/reference/crate-package.md)
  [`crate-package`](https://newgraphenvironment.github.io/crate/reference/crate-package.md)
  : crate: Canonical Schemas and Data Governance for Changing Data
