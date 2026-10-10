# Findings — STAC field schemas for the catalogues' custom prefixes (lidarbc:, las:) (#23)

## Issue context

**If we do it:** every custom field an NGE STAC catalogue writes has a published JSON Schema that items name in `stac_extensions`. A reader can look up what `lidarbc:filename_date` means, and validation checks each field's type. **If we never do:** custom fields are explained only in each catalogue's README, and validation accepts any value.

Decided in NewGraphEnvironment/stac_pointcloud_bc#12 (2026-10-10):
- A field with a standard STAC home uses it.
- Otherwise its prefix names what the field describes, not who built the catalogue.
- Each custom prefix is documented here, because crate is where NGE's canonical schemas live.

## What

- **One versioned JSON Schema per custom prefix**, in the shape of the [stac-extensions template](https://github.com/stac-extensions/template): a field table, `json-schema/schema.json`, and an example item.
- **First, the two from stac_pointcloud_bc:**
  - `lidarbc`: facts about LidarBC's objectstore paths and file names.
    - `lidarbc:product`: string, the product directory (`pointcloud`, `dsm`).
    - `lidarbc:datetime_source`: `filename` or `path`, saying which one the item's dates came from.
    - `lidarbc:filename_date`: string, the file name's date token as written.
    - `lidarbc:delivery`: string, `^[0-9]{3}/[0-9]{3}[a-p]/[0-9]{4}$`. Decided in NewGraphEnvironment/stac_pointcloud_bc#5, and shared with stac-elevation-bc (NewGraphEnvironment/stac_dem_bc#55).
  - `las`: facts about the LAS format, valid on items and assets.
    - `las:version`: string, `"1.2"` or `"1.4"`.
    - `las:point_format`: integer, 0–10.

    On an item they describe the source-of-record asset (`laz`). An asset that is a different file (a COPC copy) carries its own. No published extension covers either field: `pointcloud` v1.0.0 has no LAS version or point format. If one appears upstream, the catalogues move to it.
- **Then the prefixes the sibling migrations settle on**: NewGraphEnvironment/stac_airphoto_bc#47, NewGraphEnvironment/stac_floodplains_bc#74, NewGraphEnvironment/stac_uav_bc#38.
- **A stable URL that a version never leaves.** For example, `https://newgraphenvironment.github.io/crate/stac/<prefix>/v1.0.0/schema.json` (pkgdown assets), or a tagged raw URL. pystac fetches the schema when it validates, so every catalogue build depends on that URL answering. A released version is never edited; a change is a new version. Each schema's `$id` is that URL, so a future `las` extension published elsewhere cannot be mistaken for this one.

## Boundary

crate holds the schemas. Each catalogue's build writes the fields and lists the schema URL in `stac_extensions`.

## Blocks

NewGraphEnvironment/stac_pointcloud_bc#2. Its full rebuild re-registers every item, so the schema URLs land in the same re-registration rather than needing another.


## Exploration (2026-10-10)

- pkgdown 2.2.0 `copy_assets()` ends with `copy_asset_dir(pkg, "pkgdown/assets")`, which `dir_ls(recurse = TRUE)` — subdirectories are copied to the site root, so `pkgdown/assets/stac/x/v1.0.0/schema.json` lands at `<site>/stac/x/v1.0.0/schema.json`.
- The deploy uses `clean: true`, so every released version must stay committed; removing one from the repo unpublishes it.
- The top-level-page gate in `pkgdown.yaml` checks only `docs/*.html|md`, so README.md files under `docs/stac/` do not trip it.
- stac-extensions template schema (fetched from `stac-extensions/template` main): draft-07, `$id` carries a trailing `#` but the `stac_extensions` const does not; fields in `definitions/fields` with `additionalProperties: false` + `patternProperties "^(?!template:)"`.
- jsonvalidate 1.5.0 and V8 8.2.0 installed locally.

## Examples are a real published item (2026-10-10)

`examples/item.json` is item `082-082l-2019-pointcloud-bc_082l100_3_4_4_xyes_8_utm11_2019` from the live API (`images.a11s.one`, catalogue v0.2.0) with the `nge:` keys renamed per stac_pointcloud_bc#12, `lidarbc:delivery` added, the pgstac-only links replaced by one collection link, and `datetime: null` restored (STAC requires the key). Both prefixes' `item.json` are the same item.

## Mutation table (each constraint removed in a scratch copy; FAIL count of test-stac_schemas.R)

| removed | FAIL |
|---|---|
| lidarbc `fields.additionalProperties` | 1 |
| las `point_format.maximum` | 1 |
| las `point_format.type` | 2 |
| las top-level `assets` | 1 |
| las `version` enum + "1.5" | 1 |
| lidarbc `stac_extensions.contains` | 2 |
| lidarbc `delivery.pattern` | 2 |
| lidarbc `summaries.datetime_source.items` | 1 |
| lidarbc `filename_date.minLength` | 1 |

Clean tree: `[ FAIL 0 | PASS 79 ]`.

## Consumer interop: pystac 1.15.2 (stac_pointcloud_bc's uv env)

`JsonSchemaSTACValidator` with `schema_cache` preloaded from the local files under their URLs: the example item validates against core 1.1.0 + pointcloud + projection + file + lidarbc + las; the example collection validates; a `copc` asset with `las:point_format: 11` is rejected. Probe script lives in the session scratchpad only.
