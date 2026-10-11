# Progress — lidarbc v1.1.0: add lidarbc:datetime_unknown (#26)

## Session 2026-10-11

- Plan-mode exploration — phases approved by user
- Created branch `26-lidarbc-v1-1-0-add-lidarbc-datetime-unkn` off main
- Scaffolded PWF baseline from issue #26 with approved phases
- Next: start Phase 1
- Phase 1: two mutation rows (`datetime_unknown` as `"true"` and `1`) and a summary pair. Before v1.1.0: FAIL 1 | PASS 129, the failure being the boolean summary that v1.0.0 rejects as an unknown field. The mutation rows pass for the wrong reason until v1.1.0 (unknown field, not wrong type).
- Phase 2: `lidarbc/v1.1.0/schema.json` built from v1.0.0 by script; its diff is only `$id`, the const, and the field in definitions, fields and summaries. Examples point at v1.1.0. `item_undated.json` is the published albers item `albers10k2m-_completed_dem-dem_055_154` with the field renamed and the extension URL added, as stac_dem_bc PR #58's `item_lidarbc_apply` does. Tests: FAIL 0 | PASS 151. With `"type": "boolean"` deleted, the three new rows fail (FAIL 3), so they test the type and not the unknown field.
- Phase 3: pystac interop. The albers item is INVALID against v1.0.0 and VALID against v1.1.0; all three examples validate. Details in findings.md.
- `/code-check branch`, four rounds, each finding one false factual claim in the docs; all fixed (d0ea071, d51e947, c5b8f1c, and the decision-entry line in this commit). Round 3's was inside round 2's fix. Mechanism: a claim about a class written from one member or one list. Ended by enumeration: round 4's claim table checks every factual claim in the diff against the writer code and all three populations (urls_list 102,416; urls_deleted 43; bucket listing 102,378 items, 2,288 dateless, all albers). Tests FAIL 0 | PASS 151.
- #26 body: count corrected to 2,288 (2,245 + 43 deleted-upstream albers10k2m_new items still published).
