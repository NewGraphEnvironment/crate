# crate (development version)

# crate 0.1.0 (2026-08-24)

crate can now declare a canonical shape for data it does not read, and can type a column as an instant.

- `crt_schema_conform()` takes a data frame you already have and holds it to a registered canonical schema. `crt_ingest()` calls it rather than reimplementing validation and typing, so a file and a caller-supplied frame get identical treatment.
- New canonical type `datetime`. It never moves an instant: a `POSIXct` has its timezone attribute stamped to UTC rather than converted, because several readers return correct UTC instants carrying no timezone label and "correcting" the rendering injects a real whole-hour error into every join.
- The registry gains a `kind` column. `schema_only` entries declare a shape crate does not read; `crt_ingest()` aborts on them naming `crt_schema_conform()`.
- First `schema_only` entries: `nge/track_sessions`, `nge/track_vertices` and `nge/track_annotations`, the canonical shape of a GPS track. See the [decision entry](https://github.com/NewGraphEnvironment/crate/blob/main/decisions/nge/20260824_track_canonical_two_tables.md) for why a track is two tables and why annotations are a third.
- `test-crt_registry_integrity.R` walks the registry and the schemas directory rather than a hand-written list, so a row without a YAML, a YAML without a row, or a declared type nothing implements fails the suite.

# crate 0.0.2 (2026-04-29)

Schema-as-contract scope settled and Convention C naming locked in (see [crate#4](https://github.com/NewGraphEnvironment/crate/issues/4)).

- Every function in the crate namespace now prefixed `crt_*`, family-namespaced (`crt_schema_*`, `crt_registry_*`, `crt_handler_*`).
- New `crt_schema_*` family: `crt_schema_read()` (load YAML by relative path), `crt_schema_apply()` (canonical type enforcement), `crt_schema_validate()` (required-cols enforcement).
- `crt_ingest()` now validates required cols and enforces canonical types after handler dispatch — schema YAML is the single source of truth.

# crate 0.0.1 (2026-04-28)

Initial release. Source-explicit dispatcher (`crt_ingest`) plus first-instance handler for `bcfp/user_habitat_classification` (handles both pre-2026-04-26 long and current 2026-04-26 wide upstream variants → canonical wide).
