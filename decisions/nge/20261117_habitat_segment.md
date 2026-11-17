# link's habitat export is registered under its dataset ID

**Date:** 2026-11-17
**Schemas:** `schemas/nge/habitat/fwa/v1/segment.yaml`

## Decision

The column contract of link's habitat export is registered here as
`nge/habitat/fwa/v1/segment`, a `schema_only` entry under the dataset-ID rule
(`20261012_dataset_id_keys.md`). The YAML is link's, moved byte for byte: link
wrote it in crate's shape when it first published (NewGraphEnvironment/link#308)
and kept it in link until the columns settled. link now reads the contract from
crate and cites this file at the release tag in its published manifest.

The dataset is published at `s3://fresh-bc/habitat/fwa/v1/segment/`, Hive
partitioned by `config` and `species`, which are described, not declared. Its
Postgres table is `habitat.fwa_v1_segment`.

## Trigger

NewGraphEnvironment/link#333, and NewGraphEnvironment/link#423, which adds an
`access` column (the species' access code) to v1 after its first publish.

## Rationale

- `access` is added to v1, not to a v2, and declared `required: false`: a part
  published before it lacks the column, and the loader reads it there as NA.
  No column was renamed or redefined, so the schema version stays, as the
  dataset-ID decision allows ("a renamed or redefined column is a new version").
- `schema_only`: crate never reads the export; link writes it and conforms its
  rows to the declared names, order and types.

## Consequences

- A change to the export's columns is a crate release before link can raise
  its `crate` floor.
- The export's other datasets (per-group `barriers` and `barrier_overrides`,
  the dependency map) keep their contracts in link for now.
