# Air temperature per stream segment: a lookup and a cell series under one ID

**Date:** 2026-11-27
**Schemas:** `schemas/nge/air_temperature/fwa/v1/segment_cell.yaml`, `schemas/nge/air_temperature/fwa/v1/cell_daily.yaml`

## Decision

wet publishes daily air temperature for every BC Freshwater Atlas stream segment
as one tree, `air_temperature/fwa/v1`, holding two datasets under one manifest:
`segment_cell`, which gives every segment the ERA5-Land cell whose series it
reads, and `cell_daily`, which holds each used cell's daily series once. Both
are registered under their dataset IDs, as the discharge datasets are
(`20261012_dataset_id_keys.md`), and the published parts sit under the same Hive
keys (`scenario=historical/forcing=ERA5-Land/source=cd_daily`).

A `date` type is added to the schema types, for `cell_daily`'s day.

## Trigger

NewGraphEnvironment/wet#216: a stream temperature model run at a reach with no
station needs the air temperature series there. About 4.9 million segments read
about 13,600 cells, so the series is stored once per cell and a lookup joins it
to segments.

## What this bends, and why

The dataset-ID rule reads `<variable>/<network>/<version>/<unit>_<timebase>`,
with `<unit>_<timebase>` the feature a row describes and the time step of its
values. Three things here do not fit it as written:

- **A dataset keyed by grid cell under the `fwa` network.** `cell_daily` rows
  are cells, not FWA features. It sits under `fwa` because it is published only
  for the cells FWA segments read, is meaningful only through `segment_cell`,
  and is rebuilt with it; a reader holding a segment id reaches both under one
  manifest. A second tree (`air_temperature/era5land/v1`) would need two
  manifests, two receipts and two publishes kept in step by hand.
- **A dataset with no time step.** `segment_cell` is a lookup. Its name keeps
  the `<unit>_<timebase>` shape, the second word naming what a segment maps to.
- **NGE publishing a copy of another tool's product.** cd publishes the air
  temperature cube; this is a copy of the used cells' values, unchanged, keyed
  for the Freshwater Atlas so it can be read with the discharge datasets'
  tooling. The manifest names each cube file it copied by checksum and cd
  commit.

## Why a date type

The day is a local calendar day (UTC-8, cd's day). As `datetime` it would be
stamped 00:00 UTC, which is 16:00 of the previous day on that local day, and a
reader converting to local time would shift every row by a day. As a string it
would be parsed on every read of about 378 million rows (about 13,620 cells over the 27,759 days of 1950-2025). Parquet has a date
type; `crt_schema_apply()` now keeps a `Date` and reads `YYYY-MM-DD` (surrounding
whitespace trimmed, an empty string as missing), and refuses a `POSIXct` or a number, which have no single calendar day without a
zone or an origin. `crt_table_fingerprint()` already spelled a `Date`.

## Alternatives considered

- **Two trees**, the lookup under `fwa` and the series under `era5land`: only
  the missing time step bent, at the cost of a second manifest and publish.
- **The lookup only**, the series read from cd's cube at each cell's centre: no
  second copy, but every reader then needs cd and raster tooling and reads one
  file per variable and year.
- **`date` as two integers** (`year`, `doy`): a type crate already has, but a
  join to any dated table then rebuilds the date.

## Consequences

- wet's air build conforms each part with
  `crt_schema_conform(df, "nge", "air_temperature/fwa/v1/segment_cell")` and
  `.../cell_daily`.
- A future-climate series lands under the same ID as another `scenario`.
- The cell's elevation is not in `segment_cell` until cd publishes it
  (NewGraphEnvironment/cd#161); adding the column does not change the version.

## References

- NewGraphEnvironment/crate#81
- NewGraphEnvironment/wet#216 and wet's `research/discharge_publish.md`
