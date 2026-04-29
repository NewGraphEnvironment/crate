# Findings — crate#4 Convention C refactor (2026-04-29)

## Why this work

Two triggers stacked:
1. **Naming inconsistency** in v0.0.1 — public `crt_*` but internals mixed (`internal_*`, `registry_load`, `bcfp_uhc_*` with no prefix). Hurts grep-ability + creates ambiguity about what's public.
2. **Schema-as-contract scope** — link-Claude added schema_apply on a local branch (`65-schema-driven-types`, commit `6764fd9`, never pushed) without design alignment. Work surfaced that schema YAMLs declare types but they weren't enforced. Adjacent concerns: validation, versioning, migration.

Issue #4 locks design decisions; this PR implements them.

## Decisions locked (from issue #4)

### Decision 1 — Convention C naming

Every function in crate's namespace starts with `crt_`. Family namespacing inside: `crt_<family>_<verb>`.

| Surface | Pattern | Examples |
|---|---|---|
| Public exported singletons | `crt_<verb>` | `crt_ingest`, `crt_files` |
| Per-(source, file) handlers (exported, registry-dispatched) | `crt_handler_<source>_<file_name>` | `crt_handler_bcfp_user_habitat_classification` |
| Internal helpers (file-local, prefixed) | `crt_<family>_<verb>` | `crt_handler_bcfp_uhc_identity`, `crt_handler_bcfp_uhc_pivot_long_to_wide` |
| Internal families (registry / schema) | `crt_<family>_<verb>` | `crt_registry_load`, `crt_schema_read`, `crt_schema_apply`, `crt_schema_validate` |

Reserved names for future implementation (NOT in this PR):
- `crt_schema_version(schema)` — when schema YAMLs grow `schema_version: N` declarations
- `crt_schema_migrate(df, schema, from, to)` — cross-version data migration
- `crt_normalize_<verb>` — generic normalize primitives if data-driven dispatch ever lands

Soul's `noun_verb-detail` convention applies inside each family: `crt_schema_apply` (noun: schema, verb: apply), not `crt_apply_schema`.

### Decision 2 — Schema-as-contract scope

This PR ships:
- `crt_schema_read(yaml_path)` — extract inline `yaml::read_yaml` from crt_ingest; single source of truth for schema loading
- `crt_schema_apply(df, schema)` — coerce handler output to canonical types
- `crt_schema_validate(df, schema)` — required-cols check (`cols[].required: true|false` already declared in schema YAML)

NOT in this PR (reserved family slots):
- value-range checks (`cols[].range`)
- enum-membership checks (`cols[].enum`)
- custom predicate checks (`cols[].predicate`)
- schema versioning + migration

When concrete need surfaces for the deferred items, they slot into the `crt_schema_*` family without API surface change.

### Decision 3 — Imperative handlers stay

Each (source, file_name) gets a small R function in `R/crt_handler_<source>_<file_name>.R`. Not data-driven dispatch primitives. Trigger to revisit: 3+ handlers sharing transform patterns that would benefit from generic primitives.

## Schema_apply re-implementation (vs port from abandoned branch)

The abandoned `65-schema-driven-types` branch has `schema_apply()` at line 23-47 of `R/schema_apply.R`. Implementation:

```r
schema_apply <- function(df, schema) {
  cols <- schema[["canonical"]][["cols"]]
  if (is.null(cols)) return(tibble::as_tibble(df))
  for (col_spec in cols) {
    col_name <- col_spec[["name"]]
    col_type <- col_spec[["type"]]
    if (is.null(col_name) || is.null(col_type)) next
    if (!col_name %in% names(df)) next
    x <- df[[col_name]]
    df[[col_name]] <- switch(
      col_type,
      "integer" = if (is.integer(x)) x else suppressWarnings(as.integer(x)),
      "double"  = if (is.double(x)) x else suppressWarnings(as.double(x)),
      "string"  = if (is.character(x)) x else as.character(x),
      "logical" = if (is.logical(x)) x else as.logical(x),
      cli::cli_abort(...)
    )
  }
  tibble::as_tibble(df)
}
```

Re-implementing as `crt_schema_apply` in this PR rather than porting-then-renaming. Cleaner story in the git log. Test patterns from `test-schema_apply.R` (6 tests) carry over directly.

## crt_schema_validate design (new)

Walks `canonical.cols[]`:
- For each col with `required: true`: verify name in `names(df)`; if missing, accumulate.
- Skip cols with `required: false` or absent `required` key.
- After walk: if any missing, `cli::cli_abort` with full list (one fail-loud, all info at once).
- Returns `invisible(NULL)` on success.

Future: walk SAME loop, additionally check `range`, `enum`, `predicate` if present in schema. Single function, multiple validation concerns, schema YAML drives behaviour. Family slot not needed because validate is one verb covering many checks.

Order of operations in `crt_ingest`:
1. Variant match (existing) — column-name set equality
2. Handler dispatch (existing) — runs normalize for matched variant
3. **`crt_schema_validate(result, schema)`** — fail loud if required cols missing in handler output
4. **`crt_schema_apply(result, schema)`** — coerce types
5. Return tibble

Validate BEFORE apply because a missing required col would silently become NA after `as.integer(NULL)`-style coercion. Surface the error at the right layer.

## Schema YAML structure (current — verified)

`inst/extdata/schemas/bcfp/user_habitat_classification.yaml`:
- `canonical.shape: wide`
- `canonical.cols[]` — list of `{name, type, required, notes}` entries (some with `required: true`, some with `required: false`)
- `upstream_variants[]` — list of `{id, description, cols, normalize_fn, first_seen_sha?, last_seen_sha?}`

The `cols[].required` declarations are ALREADY in the YAML — `crt_schema_validate` just reads what's declared. No schema YAML changes needed in this PR.

## Lintr cap

Current `.lintr`: `object_length_linter(50)`. New handler name `crt_handler_bcfp_user_habitat_classification` is 47 chars (under 50). But `crt_handler_bcfp_uhc_pivot_long_to_wide` is 40 chars (under). Test name `test-crt_handler_bcfp_user_habitat_classification.R` is fine (file names aren't subject to object_length_linter).

Actually verifying: `crt_handler_bcfp_user_habitat_classification` = 4+1+7+1+4+1+27 = wait let me count properly: `crt_handler_bcfp_user_habitat_classification` → 47 chars. So 50 cap actually fits. May not need to bump.

Will verify during Phase 1 lint pass. If 50 fits, leave at 50. If not, bump to 60.

## Local-only branch cleanup

`65-schema-driven-types` exists locally, never pushed, contains the original schema_apply work. After this PR ships v0.0.2, that branch can be deleted (`git branch -D 65-schema-driven-types`). No coordination needed (nothing depends on it).

## Plan file

Working plan file (per-user, not committed): `/Users/airvine/.claude/plans/bright-spinning-wall.md`
