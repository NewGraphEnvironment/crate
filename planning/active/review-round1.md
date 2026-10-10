# Code-check round 1: #23 STAC field schemas

Reviewer scope: `git diff main...HEAD` on `23-stac-field-schemas-for-the-catalogues-cu` (schemas, examples, test file, pkgdown workflow, DESCRIPTION, .Rbuildignore, docs). All probes ran in a temp copy of the repo, or read-only against `stac_pointcloud_bc`. Nothing in the crate repo was modified except this file.

## Findings

- **[fragile]** `tests/testthat/test-stac_schemas.R:21` vs `.github/workflows/pkgdown.yaml` (guard loop `pkgdown/assets/stac/*/v*/schema.json`, and `grep -E '^stac/[^/]+/v[^/]+/schema\.json$'`): the tests and the publish guard select schemas with different patterns. The tests take only `^[a-z][a-z0-9_]*/v[0-9]+\.[0-9]+\.[0-9]+/schema\.json$`, while the guard (and the site) take any `*/v*/schema.json`. A schema committed at a path the test regex misses, such as `las/v1.1/schema.json`, `las/v1.1.0-rc1/schema.json` or an upper-case prefix, gets none of the `$id`, `contains`-const and `$ref`-sibling checks, and none of the example validation. It still deploys, and from then on the guard freezes it byte for byte. That is the one case the tests exist to stop: a broken schema becoming permanently published. Fix: use one selector for both, or have the test assert that every `*/v*/schema.json` under `pkgdown/assets/stac/` matches the strict pattern. Then a misnamed directory fails instead of going unchecked.

- **[fragile]** `.github/workflows/pkgdown.yaml`, deploy step `if: github.event_name != 'pull_request'`: this condition predates the branch, but the new freeze changes what it costs. `workflow_dispatch` (and `gh workflow run pkgdown.yaml --ref <feature-branch>`) builds and deploys whatever ref was dispatched. Any schema version present on that branch therefore lands on `gh-pages`, and the new guard treats it as released. If the branch's `v1.0.0` then changes before merge, every later `main` build fails the guard ("differs from the published version") until someone hand-edits `gh-pages`. Before this branch a stray dispatch deploy was overwritten by the next `main` deploy; now it is permanent for schemas. Fix: restrict the deploy to the default branch, e.g. `if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'`, keeping release events in mind if they should still deploy.

## Verified, no issue

- Workflow test step, run verbatim in a temp copy: `[ FAIL 0 | SKIP 0 | PASS 108 ]`. `test_path("..","..")` resolves under `test_file()`, so the step does not pass vacuously on skips. All `pkg::` calls in the test file (yaml, jsonlite, jsonvalidate, testthat) are declared in DESCRIPTION.
- Publish guard, extracted from the workflow and run against synthetic published refs via `STAC_PUBLISHED_REF`:
  - real `gh-pages` (no stac yet): rc 0
  - identical published tree: rc 0, prints "unchanged"
  - extra published version not built: rc 1
  - published version edited: rc 1
  - built file missing from `docs/`: rc 1
  - unresolvable ref: rc 1 (fails closed)
- pkgdown 2.2.0 `copy_assets()` copies `pkgdown/assets/` recursively as a byte copy into the site root, so the guard's `cmp` against `docs/stac/...` is the right comparison.
- Python `jsonschema` 4.26 (Draft7, `check_schema` OK), and pystac 1.15.2 `validate_dict` with the schema URLs served locally: all three examples validate. The mutation on a `copc` asset's `las:version` is rejected. Internal `#/definitions/...` refs resolve against `$id` with no extra fetch.
- An item built by `stac_pointcloud_bc`'s own `item_create()` + `copc_asset_add()` (test fixtures) validates against both schemas once the two URLs are added to `stac_extensions`. The real outputs check out: `str(laspy version)` is `"1.2"`, point formats are ints, and `lidarbc:filename_date` can be 8 digits. `catalogue_build.collection_build()` writes only `lidarbc:product` summaries, which is consistent with the schema.
- `lidarbc:delivery` pattern `[a-p]` is stricter than the catalogue's `key_parse` `[a-z]`. That is correct: NTS letters are a–p, `nts_sheet_bounds` would reject anything else, and no catalogue writes the field yet.
- las Collection summaries in Python: list OK, range OK, out-of-range range rejected, range on `las:version` rejected, bad `item_assets` and collection `assets` rejected. These paths have no R test (a schema mutation of the summaries range `$ref` left the suite green), but the shipped behaviour is correct.
- `pystac.validation.JsonSchemaSTACValidator().schema_cache`, used in the README's offline snippet, exists in pystac 1.15.2 and is the dict `_get_schema` consults.

## Observation (not a defect)

- `.github/workflows/pkgdown.yaml`: the new "Test the STAC schemas" step was inserted between the long CLAUDE.md comment block and the `rm -f CLAUDE.md` step that comment explains. That comment now sits directly above the test step's own comment, so it reads as if it documents the test step. Harmless to execution.
