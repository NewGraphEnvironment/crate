# Findings — Register nge/fish_data — reconcile 2023 column names to canonical (#6)

## Issue context

## Problem

NGE fish sampling records changed shape between the 2023 and 2024 field seasons. This is the same class of problem crate already handles for `bcfp/user_habitat_classification`, applied to a source we produce ourselves.

| Season | Length column | Weight column |
|---|---|---|
| 2023 | `length_mm` | `weight_g` |
| 2024, 2025 | `length` | `weight` |

2024 and 2025 share an identical 28-column schema. 2023 does not, so anything that reads across seasons either drops 2023 or hand-patches the names.

## Why it matters

Joining only 2024 + 2025 on `pit_tag_id` (771 records, 234 distinct tags) surfaces 6 tags recorded more than once — four cross-year recaptures with a year of growth, and two movements between sites:

| PIT tag | Years | Site | Length mm | Weight g |
|---|---|---|---|---|
| `3DD.003E192A2C` | 2024 -> 2025 | `125231_ds_ef2` -> `125231_ds_ef1` | 89 -> 143 | 8.3 -> 31.9 |
| `3DD.003E192AD3` | 2024 -> 2025 | `125179_us_ef1` | 94 -> 135 | 9.3 -> 24.2 |
| `3DD.003E192A33` | 2024 -> 2025 | `125231_us_ef1` | 85 -> 121 | 7.2 -> 21.4 |
| `3DD.003E192ACB` | 2024 -> 2025 | `125179_us_ef1` | 128 -> 153 | 27.2 -> 43.4 |

2023 adds roughly 588 more records (417 Skeena, 171 Peace). Any 2023 -> 2025 recapture is currently invisible purely because of the column names. Extending the series from two years to three is a schema problem, not a data problem.

## Proposed solution

Register a source following the existing `bcfp` pattern:

- entry in `inst/extdata/crate_registry.csv`
- `inst/extdata/schemas/nge/fish_data.yaml` defining canonical columns
- `R/crt_handler_nge_fish_data.R` mapping the 2023 vintage to canonical
- fixtures under `inst/extdata/examples/nge/` for both shapes

Target call:

```r
crt_ingest("nge", "fish_data", path)   # any season, canonical columns out
```

## Note on scope

This is the first NGE-produced source in crate; `bcfp` is external. Worth deciding whether `source` distinguishes producer (`nge`) or domain (`fish`), since that choice sets the convention for the eDNA, benthic and monitoring sources that would follow.

## Test plan

- [ ] `crt_ingest()` returns identical column names and types for 2023, 2024 and 2025 inputs
- [ ] Fixtures for both shapes committed and covered by tests
- [ ] Three seasons bind and the recapture query runs across all of them

Relates to #38



## Measured shapes of the real files (2026-10-31)

Fetched from the public reporting repos (`gh api ... contents`), probed in R.

| file | pinned | rows | cols |
|---|---|---|---|
| `fish_passage_peace_2023_reporting/data/inputs_raw/fish_data.csv` | 92d50f7 | 171 | `reference_number, local_name, common_name, length_mm, weight_g, comments` |
| `fish_passage_skeena_2023_reporting/data/inputs_raw/fish_data.csv` | de68443 | 417 | as above + `haul_pass` (395 pass 1, 22 pass 2) |
| `fish_passage_skeena_2024_reporting/data/fish_data_tags_joined.csv` | f990ad2 | 674 | 28-col field sheet; byte-identical to peace_2024's copy and to `peace_2023_reporting/data/2024_fish_data_tags_joined.csv`; `project_name` splits it 335 skeena / 339 peace |
| `fish_passage_peace_2025_reporting/data/fish_data_tags_joined_2025.csv` | e1ab377 | 97 | same 28 cols |

28 cols: `local_name, date, project_name, crew, ef_id, gps_id, sampling_method, pass_number, ef_seconds, voltage, frequency, enclosure, wp_top, wp_bottom, site_start_time, site_end_time, segment_start_time, segment_end_time, species, length, weight, alive, pit_tag_id, row_id, camera_id, photo_time_start, photo_time_end, comments`.

- The 2023 files are the "ready to paste into FISS step 3" stage (`common_name`, `length_mm`, `weight_g`), not the raw field sheet; the 2024+ files are the raw sheet with tags joined by `row_id`. The 2023 raw xlsx lives on OneDrive, not reachable from here.
- 2023 PIT tags: none in a column. `3DD[.][0-9A-Fa-f]{10}` matches 20 peace + 208 skeena rows, never more than one per comment. One near-miss: `"3DD.003E192B9I photo bute"`.
- 211 distinct 2023 tags, 17 repeats within 2023. 2024: 188 distinct tags (189 tagged rows); 2025: 50. Overlap 2023∩2024 = 0, 2023∩2025 = 0. The issue's "2023→2025 recaptures invisible because of column names" does not hold.
- Provincial FISS step 3 template (`data/backup/step_3_individual_fish_data.csv`): `species, length_mm, weight_g, haul_number_pass_number`. rfp `inst/extdata/forms/form_fish_sample.gpkg` (38746cb): `species, length_mm, weight_g, haul_number_pass_number, tag_number, …`.
- `crt_schema_conform()` checks required presence and coerces declared cols; it neither adds absent optional cols nor drops extras. So the handler must emit the full set for seasons to bind.
- `crt_schema_apply()` types: integer, double, string, logical, datetime. No date type.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| R one-liner `'\\.'` inside single-quoted `Rscript -e` → "unrecognized escape" | Write the probe to a file; use `[.]` in the regex |
| PIT regex `{12}` matched nothing | Tags are `3DD.` + 10 hex digits |
