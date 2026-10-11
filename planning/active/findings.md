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

## Errors Encountered

| Error | Resolution |
|-------|------------|
