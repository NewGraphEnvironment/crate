# crate (development version)

# crate 0.0.2 (2026-04-29)

Schema-as-contract scope settled and Convention C naming locked in (see [crate#4](https://github.com/NewGraphEnvironment/crate/issues/4)).

- Every function in the crate namespace now prefixed `crt_*`, family-namespaced (`crt_schema_*`, `crt_registry_*`, `crt_handler_*`).
- New `crt_schema_*` family: `crt_schema_read()` (load YAML by relative path), `crt_schema_apply()` (canonical type enforcement), `crt_schema_validate()` (required-cols enforcement).
- `crt_ingest()` now validates required cols and enforces canonical types after handler dispatch — schema YAML is the single source of truth.

# crate 0.0.1 (2026-04-28)

Initial release. Source-explicit dispatcher (`crt_ingest`) plus first-instance handler for `bcfp/user_habitat_classification` (handles both pre-2026-04-26 long and current 2026-04-26 wide upstream variants → canonical wide).
