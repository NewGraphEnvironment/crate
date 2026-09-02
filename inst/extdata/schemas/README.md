# Schemas

Canonical-shape declarations for data crate ingests. Format: YAML files at `<source>/<file_name>.yaml`.

## Format

Each schema YAML describes:
- The **canonical shape** of one logical data type (cols + types + required flags)
- All **known upstream variants** that crate's adapter recognizes (with `normalize_fn` pointers)
- Forward-compat notes (anticipated future cols)
- Decision log references

See `bcfp/user_habitat_classification.yaml` as a template.

## Two kinds of entry

A schema is registered as one of two `kind`s in `crate_registry.csv`:

- **`file`** — crate reads the source file and normalizes it. `crt_ingest()` serves these, and the schema's `upstream_variants` are what it matches the incoming columns against.
- **`schema_only`** — crate declares the canonical shape but does not read anything. The caller supplies a data frame to `crt_schema_conform()`. Use this when the bytes belong to some other package: a spatial format, a database, an API. `crt_ingest()` aborts on these, naming `crt_schema_conform()`.

A `schema_only` entry can still carry `upstream_variants`. They document the capture shape the reader is working against — useful precisely because that shape is usually owned upstream and cannot be changed.

## Adding a new schema

1. Identify the source family (e.g. `bcfp`, `nge`, `edna`). Use existing naming if present. The family is who the data belongs to, not which tool captured it — a tool is a variant.
2. Write the YAML at `<source>/<file_name>.yaml`
3. For a `file` entry, add a handler at `R/crt_handler_<source>_<file_name>.R` (per Convention C naming, locked in [crate#4](https://github.com/NewGraphEnvironment/crate/issues/4)). A `schema_only` entry has none.
4. Add a registry row in `inst/extdata/crate_registry.csv`. Its `canonical_cols` lists the schema's **required** columns — it is informational, what `crt_files()` shows, and `test-crt_registry_integrity.R` only checks it never names a column the schema lacks. Optional (`required: false`) columns are declared in the YAML alone, so a reader wanting the full set reads the schema, not the registry.
5. Write a decision log entry at `decisions/<source>/<YYYYMMDD>_<topic>.md` (root-level `decisions/`, not under `inst/`)
6. Update tests in `tests/testthat/` — `test-crt_ingest.R` for a `file` entry, `test-crt_schema_conform.R` for a `schema_only` one

The schema is the source of truth — crate's runtime validation reads it, and `test-crt_registry_integrity.R` walks every registered schema on every push, so a row without a YAML, a YAML without a row, or a type nothing implements fails the suite rather than the first caller.

## Gotcha: quote column names YAML would read as booleans

YAML 1.1 resolves bare `y`, `Y`, `n`, `N`, `yes`, `no`, `on`, `off`, `true` and `false` to booleans. `- name: y` therefore parses as logical `TRUE`, the column silently stops being a column, and `crt_schema_apply()` never matches it — no error, just an untyped column. Write `- name: "y"`. The same applies inside a variant's `cols:` list.

This is guarded in `test-crt_registry_integrity.R`, which is how it was found.

## Why under `inst/extdata/`

Schemas need to be readable at runtime by `crt_ingest()` via `system.file()`. R's package install ships `inst/extdata/` content into the installed package; root-level paths don't survive install. Browse the schemas in this directory; runtime code reaches them via `system.file("extdata/schemas/<source>/<file>.yaml", package = "crate")`.
