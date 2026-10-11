# Progress — lidarbc v1.1.0: add lidarbc:datetime_unknown (#26)

## Session 2026-10-11

- Plan-mode exploration — phases approved by user
- Created branch `26-lidarbc-v1-1-0-add-lidarbc-datetime-unkn` off main
- Scaffolded PWF baseline from issue #26 with approved phases
- Next: start Phase 1
- Phase 1: two mutation rows (`datetime_unknown` as `"true"` and `1`) and a summary pair. Before v1.1.0: FAIL 1 | PASS 129, the failure being the boolean summary that v1.0.0 rejects as an unknown field. The mutation rows pass for the wrong reason until v1.1.0 (unknown field, not wrong type).
- Phase 2: `lidarbc/v1.1.0/schema.json` built from v1.0.0 by script; its diff is only `$id`, the const, and the field in definitions, fields and summaries. Examples point at v1.1.0. `item_undated.json` is the published albers item `albers10k2m-_completed_dem-dem_055_154` with the field renamed and the extension URL added, as stac_dem_bc PR #58's `item_lidarbc_apply` does. Tests: FAIL 0 | PASS 151. With `"type": "boolean"` deleted, the three new rows fail (FAIL 3), so they test the type and not the unknown field.
