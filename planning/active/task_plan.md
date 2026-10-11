# Task: lidarbc v1.1.0: add lidarbc:datetime_unknown (#26)

**If we do it:** stac-elevation-bc's 2,245 albers items validate after NewGraphEnvironment/stac_dem_bc#2 renames their unprefixed `datetime_unknown` to `lidarbc:datetime_unknown`. **If we never do:** those items fail validation against `lidarbc` v1.0.0, so stac_dem_bc#2's rewrite cannot be published (its workflow validates every item it publishes).

## Context

`lidarbc` v1.0.0 (crate#24) rejects any undeclared `lidarbc:` key. stac_dem_bc PR #58 (#2/#55) renames the 2,245 albers items' unprefixed `datetime_unknown` to `lidarbc:datetime_unknown` and pins `LIDARBC_EXT` to the v1.1.0 URL. Its workflow validates every item it publishes, so that PR cannot merge until v1.1.0 answers. v1.0.0 stays byte-identical, and the pkgdown guard enforces that.

What the writer emits (stac_dem_bc PR #58, `item_lidarbc_apply`): `props["lidarbc:datetime_unknown"] = True` only when the legacy flag was truthy. It never writes `false`, and albers items carry no `lidarbc:delivery`.

Prefix rule check: `lidarbc` already has two writers (pointcloud and elevation), so this is a field added to a prefix that has earned its schema. It is not a new prefix.

## Design
- **The new version is a copy of v1.0.0 with three changes:** the new field in `definitions` and in `fields`, a summaries entry for it, and `$id` plus the `stac_extensions` const set to `…/lidarbc/v1.1.0/schema.json`. Nothing else changes. A minor version fits, because the change is additive and every valid v1.0.0 item is still valid apart from the URL it names.
- **`lidarbc:datetime_unknown` is `type: boolean`, as the issue specifies.** The README says `true` when neither the file name nor the path carries a date, and absent otherwise. I'm not using `const: true`: the issue says boolean, and a `false` written by some future writer would still mean something.
- **In summaries, the field is a list of booleans,** like the other fields' lists.
- **No field is required,** as before.

## Phase 1: Tests first
- [x] `test-stac_schemas.R`: add mutation rows that must be rejected: `lidarbc:datetime_unknown` given as the string `"true"`, and as `1`.
- [x] A collection summary test: `lidarbc:datetime_unknown: [true]` validates, and `["yes"]` is rejected.
- [x] Confirm these go red before v1.1.0 exists. The examples still name v1.0.0 at that point, so the new rows fail as "unknown field": the right red, for the wrong reason. Then confirm they go green once v1.1.0 exists.

## Phase 2: Schema, examples, docs
- [ ] `pkgdown/assets/stac/lidarbc/v1.1.0/schema.json`, built as described above. Check that `diff` against v1.0.0 shows only those changes.
- [ ] Point the examples at v1.1.0: `lidarbc/examples/item.json` and `collection.json`, and the lidarbc URL in `las/examples/item.json`. The tests require each prefix's examples to name the newest version.
- [ ] Add a new example, `lidarbc/examples/item_undated.json`: a minimal stac-elevation-bc albers-shaped item. It carries `lidarbc:datetime_unknown: true` and `datetime: 2000-01-01T00:00:00Z`, and no delivery, product or datetime_source. It is validated by the existing loop over the examples.
- [ ] `lidarbc/README.md`: the Identifier URL and schema link move to v1.1.0; add a field row; name stac-elevation-bc as a writer of `datetime_unknown`; add a "Versions" line saying v1.0.0 stays published.
- [ ] `lidarbc/CHANGELOG.md`: a v1.1.0 entry.
- [ ] `stac/README.md` index: the lidarbc row's URL moves to v1.1.0.
- [ ] `decisions/nge/20261010_stac_field_schemas.md`: add one line recording v1.1.0 as the first additive version under the "never edit, add a version" rule.
- [ ] Tests green. Lint is not needed, because no R/ code changes.

## Phase 3: Interop check
- [ ] Run pystac in stac_pointcloud_bc's uv env, with the local v1.1.0 schema preloaded into `schema_cache`:
  - validate the published albers item `albers10k2m-_completed_dem-dem_055_154` after renaming its field: it must pass;
  - validate the same item against v1.0.0: it must still fail with the error quoted in the issue.

  These two runs reproduce the issue's measurement in both directions.
- [ ] Record the result in `findings.md`.

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

## Notes
- NEWS and the version bump (crate 0.6.0, minor) are left to `/gh-pr-merge`. The PR closes #26.
- After the merge or release: check deploy provenance on `gh-pages`, and check that `curl -sIL` on the v1.1.0 URL returns 200 JSON identical to the source. The release run will skip its deploy (crate#25), so re-dispatch if the site is behind. Then tell the stac_dem_bc#2 session that the URL is live.
