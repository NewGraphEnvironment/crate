# Schemas

Canonical-shape declarations for data crate ingests. Format: YAML files at `<source>/<file_name>.yaml`.

## Format

Each schema YAML describes:
- The **canonical shape** of one logical data type (cols + types + required flags)
- All **known upstream variants** that crate's adapter recognizes (with `normalize_fn` pointers)
- Forward-compat notes (anticipated future cols)
- Decision log references

See `bcfp/user_habitat_classification.yaml` as a template.

## Adding a new schema

1. Identify the source family (e.g. `bcfp`, `edna`, `pscis`). Use existing naming if present.
2. Write the YAML at `<source>/<file_name>.yaml`
3. Add a corresponding internal handler at `R/internal_<source>_<file_name>.R` in crate's `R/`
4. Add a registry row in `inst/extdata/crate_registry.csv`
5. Write a decision log entry at `decisions/<source>/<YYYYMMDD>_<topic>.md` (root-level `decisions/`, not under `inst/`)
6. Update tests in `tests/testthat/`

The schema is the source of truth — crate's runtime validation (`crt_ingest()`) reads it and dispatches to the matching internal handler.

## Why under `inst/extdata/`

Schemas need to be readable at runtime by `crt_ingest()` via `system.file()`. R's package install ships `inst/extdata/` content into the installed package; root-level paths don't survive install. Browse the schemas in this directory; runtime code reaches them via `system.file("extdata/schemas/<source>/<file>.yaml", package = "crate")`.
