# A published dataset is keyed by its dataset ID

**Date:** 2026-10-12
**Schemas:** `schemas/nge/discharge/fwa/v1/segment_monthly.yaml`, `schemas/nge/discharge/fwa/v1/watershed_monthly.yaml`

## Decision

A dataset NGE publishes as files is registered under its **dataset ID**, a path
of the form `<variable>/<network>/<version>/<unit>_<timebase>`, used verbatim as
the `file_name`. The first two are `discharge/fwa/v1/segment_monthly` and
`discharge/fwa/v1/watershed_monthly`, the per-segment and per-watershed
discharge wet publishes. The schema YAML sits at
`schemas/<source>/<file_name>.yaml`, so for these it is nested
(`schemas/nge/discharge/fwa/v1/segment_monthly.yaml`). A registry-integrity test
now holds every row to that path rule.

The same ID is the S3 prefix (`s3://fresh-bc/discharge/fwa/v1/segment_monthly/`)
and, with the variable as the schema and the rest joined by `_`, the Postgres
table (`discharge.fwa_v1_segment_monthly`). One identifier, one rule, no lookup.

## Trigger

wet#7 publishes discharge, and the design settled on 2026-10-12 expects more
datasets of the same shape: CMIP6 projections, water temperature and oxygen
saturation from PCIC's hydromosaic, other groups' estimates (Poisson
Consulting), possibly a national network (CHN). Each needs its column contract
somewhere, and a flat name such as `discharge_fwa_segment` would have needed a
mapping to the bucket and the database written down per dataset.

## Rationale

- crate places no constraint on `file_name` or `schema_yaml`
  (`crt_registry_entry()` matches the string; `crt_schema_read()` resolves any
  bundled path), so nothing in crate changes.
- Every existing row already satisfied `schema_yaml ==
  schemas/<source>/<file_name>.yaml`. Making it a tested rule means anyone
  holding a dataset ID finds its schema without reading the registry.
- The version in the ID is the *schema* version. Data are overwritten within
  it; a renamed or redefined column is a new version and a new YAML beside the
  old one, which stays for readers of the old files.
- The Hive keys in the published path (`scenario`, `forcing`, `source`) are
  described, not declared: they are not columns in the files, and
  `crt_schema_conform()` is applied to a file's frame before it is written.

## Alternatives considered

- **Flat names** (`discharge_fwa_segment`): readable, but a second naming scheme
  beside the bucket's, kept in step by hand.
- **A `wet` source family**: crate's `source` names who the data belong to;
  these are NGE's published products, which `nge` already means. The producing
  tool is recorded in the published manifest and in the `source` Hive key.

## Consequences

- wet's publish script conforms each part with
  `crt_schema_conform(df, "nge", "discharge/fwa/v1/segment_monthly")`.
- A new published dataset is a new YAML at its ID's path and a registry row.
- `crt_files(source = "nge")` now mixes table names (`track_sessions`) and
  dataset IDs. Both obey the path rule.

## References

- NewGraphEnvironment/crate#31
- NewGraphEnvironment/wet#7 and wet's `research/discharge_publish.md`
