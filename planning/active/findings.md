# Findings — lidarbc v1.1.0: add lidarbc:datetime_unknown (#26)

## Issue context

**If we do it:** stac-elevation-bc's 2,245 albers items validate after NewGraphEnvironment/stac_dem_bc#2 renames their unprefixed `datetime_unknown` to `lidarbc:datetime_unknown`. **If we never do:** those items fail validation against `lidarbc` v1.0.0, so stac_dem_bc#2's rewrite cannot be published (its workflow validates every item it publishes).

## What is there

`lidarbc` v1.0.0 (#24, merged 2026-10-10T23:10:35Z) declares `lidarbc:product`, `lidarbc:datetime_source`, `lidarbc:filename_date` and `lidarbc:delivery`, and rejects any other `lidarbc:` key through `patternProperties` `^(?!lidarbc:)` with `additionalProperties: false`. `lidarbc:datetime_unknown` was added to #23's field list minutes before that merge and did not make the release. Measured with pystac on the published albers item `albers10k2m-_completed_dem-dem_055_154`, carrying the renamed field:

```
'lidarbc:datetime_unknown' does not match any of the regexes: '^(?!lidarbc:)'
Failed validating 'additionalProperties'
```

## What

`lidarbc` **v1.1.0**, adding one optional field:

- `lidarbc:datetime_unknown`: boolean, `true` when neither LidarBC's file name nor its path carries a date, so the item's `datetime` is a placeholder (`2000-01-01T00:00:00Z`). Absent otherwise.

v1.0.0 stays as published. stac_dem_bc#2 points its items at the v1.1.0 URL, so it needs that URL to answer before its PR merges.

## Writer (stac_dem_bc PR #58)

`item_lidarbc_apply` writes `lidarbc:datetime_unknown = True` only when the legacy unprefixed flag was truthy; never `false`. Albers items carry no `lidarbc:delivery`.

## Interop: pystac 1.15.2 (stac_pointcloud_bc's uv env), 2026-10-11

The published item `https://stac-dem-bc.s3.amazonaws.com/albers10k2m-_completed_dem-dem_055_154.json` was fetched, `datetime_unknown` renamed to `lidarbc:datetime_unknown`, and validated with both schemas preloaded into `JsonSchemaSTACValidator().schema_cache`; the two runs differ only in the lidarbc URL listed:

- naming v1.0.0: INVALID (pystac reports the outer `oneOf`; the inner cause is the `additionalProperties` rejection the issue quotes)
- naming v1.1.0: VALID

The examples `item.json`, `item_undated.json` and `collection.json` each pass full pystac validation (core STAC plus every extension they list).

## Errors Encountered

| Error | Resolution |
|-------|------------|
| README said stac-pointcloud-bc also writes `lidarbc:datetime_unknown` (review round 1) | Reworded: stac-elevation-bc alone writes it. Point-cloud keys always carry a year directory. |
| README said every LidarBC key is `<block>/<sheet>/<year>/<product>/<file>` (review round 2; pre-existing, contradicted by the albers example) | Now "mostly", naming the dateless `albers10k2m/_completed_dem/` tiles |
| README named `albers10k2m/_completed_dem/` as the dateless keys (review round 3, inside round 2's fix): 43 published items under `albers10k2m_new/_completed_dem/` (deleted upstream, `data/urls_deleted.txt`) also carry the flag, and PR #58 renames them too | README now says "such as the albers DEM tiles", an example rather than a closed list. Count corrected to 2,288 in #26 body, task_plan and PR draft. Mechanism (round 3): a class claim written from one representative list (`urls_list.txt` = what LidarBC serves, not what is published) |
