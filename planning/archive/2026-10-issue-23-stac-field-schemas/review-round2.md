# Code-check round 2: #23 STAC field schemas

Reviewer scope: `git diff main...HEAD` on `23-stac-field-schemas-for-the-catalogues-cu`, with the three round-1 fixes reviewed first. All probes ran in a temp copy of the repo (scratchpad `crate/`), or read-only in `stac_pointcloud_bc`'s uv env. Nothing in the crate repo was modified except this file.

## Findings

- **[fragile, low]** `.github/workflows/pkgdown.yaml`, deploy step `if:` (`... && (github.ref == 'refs/heads/main' || github.event_name == 'release')`): fix 2 closes the dispatch route but leaves the same defect one axis over. A `release: published` event deploys whatever commit the tag points at, and nothing requires that commit to be on `main`. `gh release create vX --target <feature-branch>`, or a release cut from a hotfix branch, builds that branch's `pkgdown/assets/stac/`. The guard passes, because a new version is not yet on `gh-pages`, and the deploy then freezes that version: every later `main` build fails "differs from the published version" until someone edits `gh-pages` by hand. The path is narrow, because `/gh-pr-merge` tags the `main` head, where the release run rebuilds exactly what the push run already deployed. That same fact makes the release deploy redundant: `_pkgdown.yml` has no `development: mode`, so a release adds nothing that the push to `main` has not published. The simplest fix is to drop `|| github.event_name == 'release'`. Gating on `github.event.release.target_commitish == 'main'` is not reliable: for a tag that already exists, GitHub reports the default branch as the target wherever the tag actually points.

## Verified, no issue

- **Fix 1 (one selector).** I planted a schema at `las/v1.1/`, `las/v1.1.0-rc1/` and an upper-case prefix in the temp copy, and each one turns `test-stac_schemas.R` red. R `list.files(recursive = TRUE)`, the shell glob `*/v*/schema.json` and pkgdown's `fs::dir_ls(recurse = TRUE)` all skip dot-entries, so the three agree on what counts as published.
- **Fix 3 (las summaries/item_assets).** Mutation table on `las/v1.0.0/schema.json` in the temp copy. Each mutation turns one test red:
  - delete the `item_assets` block
  - delete the `properties` of the `point_format` summary range
  - delete the `point_format` summary `items`
  - delete the `las:version` summary `type`
  - delete the top-level `assets`
- **The workflow test step**, run verbatim in the temp copy: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 116 ]`, with every block run and none skipped. All `pkg::` calls in the test are declared: yaml is in Imports; jsonlite and jsonvalidate are in Suggests.
- **pkgdown 2.2.0 `copy_assets()`** copies `pkgdown/assets` recursively, skipping only `.scss`, so the guard's `docs/stac/...` paths are right.
- **Python jsonschema 4.26 (Draft7, `check_schema` OK) on the consumer's real output.** All 9,650 files in `stac_pointcloud_bc/data/build` (the items plus `collection.json`) validate against both schemas once both URLs are added to `stac_extensions`.
- **Mutations in Python.** Python jsonschema rejects every mutation the R tests reject.
- **pystac 1.15.2.** I used `validate_dict` with the README's `schema_cache` preload and core schemas fetched live. All three examples validate, and both `las:point_format = 11` and `lidarbc:bogus` raise `STACValidationError`.
- **Known validator differences (not defects).**
  - `6.0` is accepted as an integer by both validators, as draft-07 specifies.
  - Python `re.search` lets `$` match before a trailing `\n`, so `"092/092g/2019\n"` passes the delivery pattern in pystac and fails in ajv. Catalogues derive the value from a `/`-split object key, so this is not reachable from real data.
