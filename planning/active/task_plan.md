# Task: STAC field schemas for the catalogues' custom prefixes (lidarbc:, las:) (#23)

**If we do it:** every custom field an NGE STAC catalogue writes has a published JSON Schema that items name in `stac_extensions`. A reader can look up what `lidarbc:filename_date` means, and validation checks each field's type. **If we never do:** custom fields are explained only in each catalogue's README, and validation accepts any value.

## Context

stac_pointcloud_bc#12 renamed the catalogue's `nge:` fields to `lidarbc:` and `las:`. Its full rebuild (stac_pointcloud_bc#2) is **blocked** until both prefixes have a published JSON Schema at a stable URL, so that every item can list them in `stac_extensions`. crate holds NGE's canonical schemas, so they live here. pystac fetches each URL when it validates, so every catalogue build depends on those URLs answering, and a released version must never change.

Decided at the gate:
- **URL:** `https://newgraphenvironment.github.io/crate/stac/<prefix>/v<X.Y.Z>/schema.json`. This is the pkgdown site, built from `pkgdown/assets/`, and `pkgdown:::copy_assets()` copies that directory recursively to the site root (checked in pkgdown 2.2.0).
- **Scope:** `lidarbc` and `las` only. The PR says *Relates to #23*. The #23 body is edited to tick off these two, and the issue stays open for the sibling prefixes (stac_airphoto_bc#47, stac_floodplains_bc#74, stac_uav_bc#38).

## What the build emits (read from stac_pointcloud_bc `origin/main` `scripts/laz_item.py`)

- Item properties: `lidarbc:product` (`PRODUCTS = ("pointcloud", "dsm")`), `lidarbc:datetime_source` (`date_parse` returns `filename`/`path`), `lidarbc:filename_date` (only when there is a token), `las:version` (`str(laspy version)`), `las:point_format` (int).
- `copc` asset: `extra_fields` holds `las:version` and `las:point_format`.
- Collection: `summaries` holds `lidarbc:product` (`catalogue_build.py:402`).
- `lidarbc:delivery` is not emitted yet. #2 adds it, and stac_dem_bc#55 (open) shares it.

## Layout

```
pkgdown/assets/stac/
  README.md                  index: prefixes, URL rule, "a released version is never edited"
  lidarbc/
    README.md                field table (stac-extensions template shape)
    CHANGELOG.md
    v1.0.0/schema.json       published; $id == its URL
    examples/item.json       validated in tests
  las/                       same shape
```

## Schema design (template shape: draft-07, `oneOf` Feature | Collection, `definitions/fields` with `additionalProperties: false` plus `patternProperties "^(?!<prefix>:)"`)

- `$id` is the URL with no trailing `#`. `stac_extensions` must `contains` that `const`.
- **lidarbc** (in item properties and collection summaries; not on assets):
  - `product`: string, minLength 1, with no enum. stac-elevation-bc will share the prefix, and LidarBC has other product directories. The known values are listed in the README.
  - `datetime_source`: enum `filename` | `path`.
  - `filename_date`: string, minLength 1.
  - `delivery`: pattern `^[0-9]{3}/[0-9]{3}[a-p]/[0-9]{4}$`.
- **las** (in item properties, assets, and collection summaries/item_assets):
  - `version`: enum `"1.0"`–`"1.4"`. The issue says "1.2 or 1.4", but the prefix describes the LAS format rather than LidarBC, so all five spec versions are valid. A narrower enum would fail a future 1.3 file on a fact that is true.
  - `point_format`: integer 0–10.
- **No fields are required.** stac_dem_bc items will carry only `lidarbc:delivery`, so making any field required would reject them. Each catalogue's own build guard checks that its fields are present.
- **A misspelled field is rejected:** `additionalProperties: false` within the prefix catches `lidarbc:bogus`.

## Phase 1: Tests first
- [x] Add `jsonvalidate` (plus `jsonlite`) to Suggests
- [x] `tests/testthat/test-stac_schemas.R`. Discover every `pkgdown/assets/stac/*/v*/schema.json`, then for each:
  - [x] it parses, and `$schema` is draft-07
  - [x] `$id` equals the URL derived from its path, and the `stac_extensions` const equals `$id`
  - [x] the prefix's `examples/item.json` validates (engine `ajv`)
  - [x] negative cases, each of which must fail: `las:point_format` 11 or `"6"`, `las:version` `"1.5"`, `lidarbc:datetime_source` `"guess"`, a bad `lidarbc:delivery`, an unknown `lidarbc:bogus`, a bad `las:version` on the `copc` asset, and the extension URL missing from `stac_extensions`
  - [x] the directory is found (`expect_gt(length(files), 0)`) so the test cannot pass vacuously. Under `R CMD check` `pkgdown/` is not installed, so skip when the source tree is absent. `devtools::test()` and CI run it.

## Phase 2: Schemas, examples, docs
- [x] `lidarbc/v1.0.0/schema.json`, `las/v1.0.0/schema.json`
- [x] `examples/item.json` for each: a realistic item based on one stac_pointcloud_bc item, with the new names and `laz` + `copc` assets
- [x] the per-prefix README (field table), CHANGELOG, and the `stac/README.md` index
- [x] `.Rbuildignore`: `^pkgdown$`
- [x] tests green, and each negative case shown to be caught (restore the bug: remove the constraint and watch the test fail)

## Phase 3: Publishing guards (`.github/workflows/pkgdown.yaml`)
- [x] After the build, assert that each `docs/stac/<prefix>/v*/schema.json` exists. This proves the assets reached the site.
- [x] **Immutability guard** (runs on PRs and pushes): compare each built schema against the `gh-pages` branch (what is deployed), not the live URL. A version on gh-pages must be rebuilt byte for byte, and must still be built at all. A failed fetch or a bad ref fails the step. *Changed from the plan's live-URL fetch: a 404 from Pages reads as "new" whether or not the site is up, and a deletion is invisible to a URL check.*
- [x] Prove the guard fires: the step's script, extracted from the YAML, run in a scratch clone against fake published refs (see findings.md)

## Phase 4: Docs and wiring
- [x] README "How it works", and `inst/extdata/schemas/README.md` if it is the right place: one line pointing to `pkgdown/assets/stac/`
- [x] `decisions/nge/20261010_stac_field_schemas.md`: the URL and versioning contract, no required fields, the `las:version` breadth
- [x] NEWS entry (the version bump is left to `/gh-pr-merge`)
- [ ] Edit the #23 body: tick off lidarbc and las and record the URL; it stays open for the siblings

- [x] Plan-review fixes (planning/active/review-plan.md): test step in pkgdown.yaml, `$ref`-sibling assertion, version-aware examples, collection negatives, redirect recorded

## Validation
- [x] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

## Verification
- `Rscript -e 'devtools::test()'`, `lintr::lint_package()`, `pkgdown::build_site()` locally, then confirm `docs/stac/lidarbc/v1.0.0/schema.json` exists.
- **Consumer interop, before merge:** in stac_pointcloud_bc's uv env, run pystac `Item.from_file(example).validate()` with a `JsonSchemaSTACValidator` whose `schema_cache` is pre-loaded with the local schemas under their URLs. This validates against core STAC as pystac really does.
- **After merge:** check the deploy provenance on gh-pages, `curl -sI` each URL (expect 200 and JSON), run the same pystac validation against the live URLs, and fire the immutability guard once against a deliberately altered copy.
