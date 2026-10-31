# Task: Register nge/fish_data — reconcile 2023 column names to canonical (#6)

## Problem

NGE fish sampling records changed shape between the 2023 and 2024 field seasons. This is the same class of problem crate already handles for `bcfp/user_habitat_classification`, applied to a source we produce ourselves.

| Season | Length column | Weight column |
|---|---|---|
| 2023 | `length_mm` | `weight_g` |
| 2024, 2025 | `length` | `weight` |

2024 and 2025 share an identical 28-column schema. 2023 does not, so anything that reads across seasons either drops 2023 or hand-patches the names.


## Context

NGE fish sampling records (one row per fish) come in more than one shape across seasons. The issue asked for 2023's `length_mm`/`weight_g` to be renamed onto the 2024–25 `length`/`weight`, so that a PIT-tag recapture query could run across three seasons. Measuring the real files showed the gap is wider than column names:

| season / file (public reporting repos, pinned) | rows | cols | shape |
|---|---|---|---|
| peace_2023 `data/inputs_raw/fish_data.csv` @92d50f7 | 171 | 6 | `reference_number, local_name, common_name, length_mm, weight_g, comments` |
| skeena_2023 `data/inputs_raw/fish_data.csv` @de68443 | 417 | 7 | as above, plus `haul_pass` |
| skeena_2024 `data/fish_data_tags_joined.csv` @f990ad2 (byte-identical to peace_2024's copy) | 674 | 28 | full field sheet: `species, length, weight, pass_number, pit_tag_id, date, project_name, …` |
| peace_2025 `data/fish_data_tags_joined_2025.csv` @e1ab377 | 97 | 28 | same 28 columns |

- 2023 has **no PIT tag column**. Its tags are written into free-text `comments`: 228 of 588 rows match `3DD.` followed by 10 hex digits, and one tag is malformed (`3DD.003E192B9I`).
- With those tags extracted, **2023 shares no tag with 2024 or 2025** (211 distinct 2023 tags, 0 overlap). It does have 17 repeat tags within 2023. So the issue's sentence "any 2023→2025 recapture is invisible purely because of the column names" is wrong on both counts. The issue body and umbrella #38 get corrected.
- The provincial FISS step-3 template and rfp's `form_fish_sample.gpkg` both use `species, length_mm, weight_g, haul_number_pass_number`. That makes the 2024–25 sheet the odd one out, not 2023.

The outcome is that `crt_ingest("nge", "fish_data", path)` returns one identical column set, with identical types, for all three file shapes, so the seasons bind and the recapture query runs.

## Decided at the gate (user, 2026-10-31)

1. **Canonical names follow FISS and rfp's form:** `species`, `length_mm`, `weight_g`, `haul_number_pass_number`. Both the 2024–25 sheet and 2023 get mapped onto these.
2. **2023 PIT tags are extracted** from `comments` into `pit_tag_id` with a strict `3DD\.[0-9A-F]{10}` match. `comments` is kept verbatim. The malformed tag is left NA and recorded for the #38 QC rules.
3. **The key is `nge/fish_data`.** `nge` is the producer family, which is already established, so the issue's question about naming the source is settled.

Taken by default and stated here so they can be overruled:

- The tag column is `pit_tag_id`, as the issue and the 2024+ files name it, not rfp's `tag_number`.
- `date` is an ISO `YYYY-MM-DD` string. The 2024+ value `2024-…T00:00:00Z` is an Excel artifact, a day rather than an instant. Time-of-day columns are `HH:MM:SS` strings.
- The handler emits **every** canonical column for every variant, filling the ones a variant lacks with NA, because `crt_schema_conform()` neither adds absent optional columns nor drops extra ones.
- Required columns are only `local_name` and `species`. Everything else is optional, because 2023 lacks most of it.
- 2023's `reference_number` is kept as an optional column. 2024+ files lack it and get NA.
- The handler cannot infer a season. 2023 rows carry no `date` or `project_name`, so the caller tags the season when binding. The docs say so.

## Phase 1: Schema, registry, fixtures, tests first
- [x] `inst/extdata/schemas/nge/fish_data.yaml`: the canonical columns (28 field-sheet columns under their FISS/rfp names, plus `reference_number`), with `type`, `required`, `units` (`mm`, `g`, `s`, `V`, `Hz`) and notes. Three `upstream_variants` (`2023-peace-6col`, `2023-skeena-7col`, `2024-field-sheet`), each giving its `cols`, its `normalize_fn` and the pinned SHA it was last seen at. Plus `upstream_source` and `decisions:`
- [x] Add the registry row in `inst/extdata/crate_registry.csv` (`kind = file`, `handler_fn = crt_handler_nge_fish_data`, `canonical_cols = local_name,species`)
- [x] Hand-author synthetic fixtures in `inst/extdata/examples/nge/`: `fish_data_2023_peace.csv`, `fish_data_2023_skeena.csv` and `fish_data_2024.csv`, a few rows each. They cover a tag in the comments, a malformed tag, a blank comment, a missing weight, one tag recaptured from a 2023 fixture into the 2024 fixture, and a visual observation with no length
- [x] `data-raw/example_fixtures_nge_fish_data.R`: documents the fixtures and sanity-checks them, following the pattern of the bcfp fixture script
- [x] Write failing tests:
  - [x] `tests/testthat/test-crt_handler_nge_fish_data.R`: dispatch per variant; an unknown variant aborts; tag extraction cases (one tag, none, malformed, NA comment, a comment that reads as logical); `comments` stays verbatim
  - [x] Additions to `test-crt_ingest.R`: identical `names()` and column classes across the three fixtures; `dplyr::bind_rows()` of all three succeeds; the recapture query finds the planted cross-season tag

## Phase 2: Handler
- [x] `R/crt_handler_nge_fish_data.R`: a `switch` dispatcher on `variant_id`, mirroring `R/crt_handler_bcfp_user_habitat_classification.R`. Internal helpers rename each variant onto canonical names (`common_name→species`, `haul_pass`/`pass_number→haul_number_pass_number`, `length→length_mm`, `weight→weight_g`), extract the 2023 tags, normalise `date` and the time columns to strings, and fill and order the full canonical set. The canonical names are read from the schema (`crt_schema_get()`), not restated in the code
- [x] Wire nothing new into `crt_ingest()`. Variant matching by `setequal()` already distinguishes the three column sets
- [x] `devtools::document()`, `lintr::lint_package()`, `devtools::test()` green; `pkgdown::check_pkgdown()`

## Phase 3: Real-data check, decision entry, docs
- [x] `data-raw/fish_data_check-real.R`, not run in CI. It fetches the four real files at their pinned SHAs into `tempfile()`s, ingests each through `crt_ingest()` and binds them. It asserts the 171/417/674/97 row counts and identical columns, and reports the recapture table: the issue's 4 cross-year 2024→2025 tags reproduce, there is 0 overlap between 2023 and later seasons, and 2023 has 17 repeat tags within the season
- [x] `decisions/nge/20261031_fish_data_canonical.md`: FISS names over the sheet's names, tag extraction, the full column set with NA fill, season left to the caller, and the measured 2023 facts
- [x] Add the new entry to the `crt_files()` output in `README.md` and to the Status paragraph of `CLAUDE.md`. Add a `crt_ingest()` `@examples` line for an nge fixture
- [ ] Edit the body of issue #6 so its premise matches what was measured (shape, not names; 0 recaptures between 2023 and later seasons; tags in comments), and edit the matching sentence in #38's "Open questions"

## Validation
- [ ] Tests pass (`devtools::test()`), and `devtools::check()` clean
- [ ] `/code-check branch` clean (three-round floor)
- [x] Plan review (Plan agent, run concurrently), findings in `planning/active/review-plan.md`
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion, then `/gh-pr-push`

Verification: the fixture tests prove the contract, with the same names and types for every variant and a bind that works. The `data-raw` real-data script proves it on the 1,359 real rows, against the counts measured here: 588 + 674 + 97. Revert the tag extraction and the recapture test must go red (mutation check).
