## Outcome

Locked in three design decisions and shipped them as v0.0.2 in a single coherent PR ([crate#5](https://github.com/NewGraphEnvironment/crate/pull/5), closes [crate#4](https://github.com/NewGraphEnvironment/crate/issues/4)):

1. **Convention C naming** — every function in crate's namespace prefixed `crt_*`, family-namespaced. Internal renames: `registry_load` → `crt_registry_load`; `internal_bcfp_user_habitat_classification` → `crt_handler_bcfp_user_habitat_classification`; file-local helpers `bcfp_uhc_*` → `crt_handler_bcfp_uhc_*`. Public API surface unchanged.
2. **Schema-as-contract scope** — `crt_schema_apply()` (re-implemented from the abandoned local `65-schema-driven-types` branch under Convention C name) handles type enforcement; `crt_schema_read()` extracts inline `yaml::read_yaml` from `crt_ingest`; `crt_schema_validate()` is new — required-cols enforcement called BEFORE type apply (validate shape, then coerce types). Future family slots (`crt_schema_version`, `crt_schema_migrate`, value-range / enum / predicate extensions) reserved by name in @details + README; not implemented.
3. **Imperative handlers** — kept; revisit only when 3+ handlers share transform patterns. YAGNI applied to the meta-layer (no data-driven dispatch primitives yet).

Tests grew from 29 (v0.0.1) to 86 (v0.0.2) across 5 new test files (test-crt_schema_read, test-crt_schema_apply, test-crt_schema_validate, test-crt_registry_load, test-crt_handler_bcfp_user_habitat_classification). R CMD check clean (0/0/0). Pkgdown site updated at https://www.newgraphenvironment.com/crate/. Tagged v0.0.2.

Key learning: process slip surfaced when link-Claude committed schema_apply directly in crate without a comms thread for design alignment. Re-implementation under Convention C naming was cleaner than port-then-rename. Going-forward norm: cross-repo source-code changes route through `crate/comms/<peer>/` thread for design alignment first; peer-Claude implements after. Documented in the link-side comms back-fill (`link/comms/crate/20260429_crate_v002_refactor_shipped.md`).

Closed by: PR #5 (commit `86b5755`), tagged v0.0.2.
