# crate

## Purpose

Data governance repo for New Graph Environment — canonical schemas, data dictionary, QC rules, cross-domain normalization for 8 years of heterogeneous NGE data (fish passage, eDNA, benthic, restoration monitoring, gps tracks, forms across Peace / Skeena / Fraser regions).

## Ecosystem placement

- **Consumer of** `rtj` (S3 storage, postgres instances)
- **Publisher for** reporting repos (via snapshot-parquet pattern — see db_newgraph#stamps umbrella)
- **Cross-references** `db_newgraph` (schema contract), `link` / `fresh` (custom model producers), `compass` (values), `soul` (conventions)

## Status

Early. File structure not yet committed — umbrella issue frames the problem space before opinionated layout is adopted.

## Bootstrap note

This CLAUDE.md is a minimal placeholder. Run `/claude-md-init` to inject the standard soul conventions block (newgraph, karpathy, planning, code-check, sred, comms, etc.).

<!-- BEGIN SOUL CONVENTIONS — DO NOT EDIT BELOW THIS LINE -->
<!-- (run /claude-md-init to populate) -->
