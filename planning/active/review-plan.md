# Plan review (Plan agent, 2026-10-31) — findings and disposition

| # | Category | Finding | Disposition |
|---|---|---|---|
| 1 | Ordering | YAML `decisions:` key fails `test-crt_registry_integrity.R:137` until the decision file exists | Key added in Phase 3 with the entry |
| 2 | Gap | `as.character(POSIXct)` formats per value on R >= 4.3, whole column before; DESCRIPTION allows R >= 4.1 | `format(x, "%Y-%m-%d", tz = "UTC")`; abort on a non-midnight value; character branch accepts ISO day or midnight-UTC stamp only |
| 3 | Gap | A time column read as character passes unnormalised | Real-data script asserts `^\d{2}:\d{2}:\d{2}$` on every time value |
| 4 | Gap | ID-like cols declared integer would NA silently | `ef_id`, `gps_id`, `camera_id`, `wp_*` already `string`; `row_id` stays integer (reader row number) |
| 5 | Gap | `file:` key, schema path, `values` rules | Already met; no `values` declared |
| 6 | Gap | README `crt_files()` block is hand-pasted | Re-run and paste in Phase 3 |
| 7 | Assumption | 2023 `common_name` vs 2024 `species` vocabularies unverified | Real-data script reports both value sets |
| 8 | Assumption | Regex case and 11-digit boundary | Case-insensitive match, `toupper()`, hex lookarounds; tested |
| 9 | Assumption | readr name repair (`...29`) fails `setequal` | Real-data script would abort on it; noted |
| 10 | Acceptance | Mutation check needs the planted tag in a 2023 fixture's comments; classes asserted on `crt_ingest()` output; fixture script says the recapture is synthetic | Done that way |
| 11 | Acceptance | `date` as string means growth intervals must parse it | In the decision's Consequences |
| 12 | Scope | Rewriting #6 loses the original statement; keep OneDrive path out of public text | Body edited with a dated correction section naming what changed (feature-workflow: edit, not append); no private paths |
