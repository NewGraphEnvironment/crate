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

## Publishing guard: gh-pages, not the live URL (2026-10-10)

Comparing against the live URL fails toward pass: a Pages outage or a disabled site returns 404, which the guard must read as "new version". The gh-pages branch is what `clean: true` deploys over, so comparing against it also catches a version deleted from the repo, which a URL check cannot.

Run in a scratch clone with the step's `run:` extracted from the YAML (`STAC_PUBLISHED_REF` points it at a fake published ref):

| published state | exit |
|---|---|
| gh-pages with no `stac/` (today) | 0 |
| identical | 0 |
| las v1.0.0 edited | 1 |
| a published version absent from the build | 1 |
| built copy differs from source | 1 |
| ref does not exist | 1 |
| no schemas in source | 1 |
| real `origin gh-pages` (deploy of 952cb73) | 0 |

## Errors Encountered

| Error | Resolution |
|---|---|
| Guard passed with a nonexistent ref: `git ls-tree` failing inside `$(… \| grep … \|\| true)` in a `for` header reads as "nothing published" | `git rev-parse --verify "$ref^{commit}"` and the `ls-tree` on their own assignment lines, so `set -e` stops the step |

## Enumeration: every route by which content reaches gh-pages (code-check round 2)

Rounds 1 and 2 found the same defect twice (a non-main ref freezing schemas: dispatch, then release). The candidate set is every writer to gh-pages times every trigger:

| writer | trigger | ref | deploys? |
|---|---|---|---|
| pkgdown.yaml deploy step | push main | refs/heads/main | yes (intended) |
| pkgdown.yaml deploy step | push master | refs/heads/master | no |
| pkgdown.yaml deploy step | pull_request | refs/pull/N/merge | no |
| pkgdown.yaml deploy step | release | refs/tags/vX | no (removed round 2) |
| pkgdown.yaml deploy step | workflow_dispatch | any | only if main |
| update-citation-cff.yaml | — | writes main only (no gh-pages reference) | n/a |

The deploy condition is `github.event_name != 'pull_request' && github.ref == 'refs/heads/main'`; nothing above it can publish from another ref.

Accepted: Python `re` `$` matches before a trailing newline, so `"092/092g/2019\n"` passes `lidarbc:delivery` in pystac and fails in ajv. No writer can produce it.

## Enumeration: freeze set vs checked set (code-check round 3, terminal)

Mechanism (round 3): the guard freezes whatever reaches gh-pages and treats it as checked, while the tests select what to check by a separate rule. Every axis on which the two selections can differ, and what now ties them:

| axis | freeze takes | check now covers | tie |
|---|---|---|---|
| file name | every `*/v*/schema.json` | same set | test asserts every `schema.json` equals the strict set (R1) |
| git ref | what deploys | the checkout the tests ran on | deploy is main-only (R1, R2), and the test step runs in the same job before the build, so a deployed tree has passed in that run |
| source vs built bytes | `docs/stac/...` | `pkgdown/assets/stac/...` | guard `cmp`s each source against its built copy |
| prefix | every prefix directory | prefixes derived from the tree | no literal list; each prefix must have examples (R3) |
| version | every version built | every version compiled by ajv (keyword types, `$ref` resolution) + structure; the newest validated by examples | examples must name the newest version (R3) |

Residual, accepted and documented in `pkgdown/assets/stac/README.md`: two new versions of one prefix added in a single push — the older of the two gets compile + structure only. Add one version at a time.

Mutation proofs (scratch copy): unnamed invalid v1.1.0 → FAIL 2; valid v1.1.0 with examples on v1.0.0 → FAIL 1; new prefix without examples → FAIL 1. Clean: 120 pass.
