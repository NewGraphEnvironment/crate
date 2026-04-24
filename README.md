# crate

Data governance repo for New Graph Environment.

## Purpose

Canonical schemas, data dictionary, QC rules, and cross-domain normalization for NGE's data assets. Consumer of `rtj` infrastructure primitives (S3, postgres), publisher of canonical artifacts used by reporting repos and analytical pipelines.

Scope spans 8 years of heterogeneous data (2019-present): fish passage, eDNA, benthic, restoration site monitoring, gps tracks, forms — across Peace, Skeena, Fraser regions.

## Ecosystem placement

| Repo | Role | Analogy |
|------|------|---------|
| compass | Ethics, values | The "why" |
| soul | LLM conventions | The "how" |
| compost | Communications | The "who" |
| rtj | Infrastructure / IaC | The "where" |
| gq | Cartographic style | The "look" |
| **crate** | **Data governance** | **The "what"** |

## Status

Early. Scope being defined in the umbrella issue. File structure not committed — letting sub-issues drive it organically.

## Related

- Origin: `fp_template_reporting → rtj` governance deflection thread (`rtj/comms/fish_passage_template_reporting/20260424_data_governance_owner.md`)
- Name + scaffold jam: `fp_template_reporting → soul` thread (`soul/comms/fish_passage_template_reporting/20260424_new_data_repo_name_scaffold.md`)
