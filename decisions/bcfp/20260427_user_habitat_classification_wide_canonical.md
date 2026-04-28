# Decision: user_habitat_classification canonical = wide

**Date:** 2026-04-27
**Domain / source:** bcfp
**File:** user_habitat_classification

## Decision

The canonical shape for `bcfp/user_habitat_classification` is **wide**: one row per (segment × species), with separate integer columns `spawning` and `rearing` (plus join keys, watershed group code, and metadata).

## Trigger

On 2026-04-26, smnorris reshaped `user_habitat_classification.csv` upstream from long to wide format (commit `40c4a0a` in `smnorris/bcfishpass`). The byte-checksum auto-merge in link's daily sync workflow propagated the new shape into link's bundled CSVs without alerting; downstream consumers (link's processing pipeline, fresh's overlay) broke silently or noisily depending on call site. The reshape forced an explicit canonical-shape decision rather than the previously implicit "whatever upstream ships, ship through."

## Rationale

Three independent signals converge on wide-canonical:

1. **fresh 0.22.0 (released 2026-04-27, closes fresh#177) explicitly enforces wide-shape input** by dropping the `format` parameter from `frs_habitat_overlay()`. The NEWS entry codifies the principle: "Shape-translation lives with the consumer; fresh stays a thin SQL adapter." Going forward, fresh accepts only wide-shape habitat tables.

2. **link's SQL schema for `working.user_habitat_classification`** (declared in `link/R/lnk_pipeline_prepare.R` lines 170-177) is wide: `spawning integer, rearing integer`. link's `lnk_pipeline_classify.R` calls `frs_habitat_overlay(species_col = "species_code", habitat_types = c("spawning", "rearing"))` — wide consumption is already in production code.

3. **Current upstream state matches wide** — the `40c4a0a` reshape is now-stable upstream; future variant changes are likely incremental (column additions, type tweaks) rather than back-to-long. Choosing wide as canonical aligns with where upstream is converging anyway.

## Alternatives considered

**Long-canonical** (one row per (segment × species × habitat_type), with `habitat_type` text + `habitat_ind` text columns) was the pre-2026-04-26 upstream shape and was the original sketch in crate#2's first issue body. Rejected because:

- Both fresh 0.22.0 and link's SQL schema would need to bend to long — significant downstream refactor for no functional gain
- "Bend the consumers to fit a chosen canonical" is more work than "match canonical to consumer expectations"
- Long-canonical would force an extra wide→long translation in every consumer (vs. one long→wide pivot in crate's historical-variant adapter, which only fires when ingesting pre-2026-04-26 archived data)
- Symmetric-information-preserving argument (long is "more normalized") doesn't outweigh the practical cost

## Consequences

**crate's adapter** for `bcfp/user_habitat_classification` (in `R/internal_bcfp_user_habitat_classification.R`):
- **wide input** (today's upstream, variant `2026-04-26-wide`): identity passthrough after schema validation
- **long input** (historical, variant `pre-2026-04-26-long`): `pivot_long_to_wide` — pivot the long shape to wide canonical, preserving the `-4` "excluded" semantic value if present
- Both paths return wide-canonical tibble matching the schema YAML

**Downstream consumers** (link, fresh, reporting):
- Read canonical wide directly via `crate::crt_ingest("bcfp", "user_habitat_classification", path)`
- No shape branching needed in their code
- fresh#177 dropping the `format` parameter is consistent with this — no asymmetry between fresh's contract and crate's adapter output

**Schema authority** is now explicit in `inst/extdata/schemas/bcfp/user_habitat_classification.yaml`. Future upstream changes update that YAML (add a new `upstream_variants` entry + matching adapter handler) without touching consumer code.

**`-4` excluded value preservation**: the wide-format upstream encodes "explicitly excluded" via integer `-4` (e.g., mining-altered streams). Adapter preserves this rather than coercing to 0 — the value carries downstream meaning.

## References

- Schema YAML: `inst/extdata/schemas/bcfp/user_habitat_classification.yaml`
- crate#2 (this work — scaffold + first-instance dispatcher)
- link#64 (Phase 1 sync workflow shape fingerprint — operational guard against silent shape drift in future)
- link#65 (link integration: `lnk_load_overrides()` consumes `crate::crt_ingest()`)
- fresh#177 (closed by fresh 0.22.0 — drops `format` parameter, enforces wide)
- Comms thread (architectural design): `link/comms/crate/20260427_fresh_bcfishpass_csv_consumers.md` + `20260427_bcfp_ingest_impl_plan.md`
- Upstream reshape: `smnorris/bcfishpass` commit `40c4a0a` (2026-04-26)
- Pre-reshape variant: link's git history `9cc30fc`
