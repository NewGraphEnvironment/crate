# Progress — List the 2023–2025 versions of the fish passage forms, read from the sync service's history (#36)

## Session 2026-11-16

- Plan-mode exploration — phases approved by user (two gate decisions via AskUserQuestion)
- Read-only Mergin probe: 21 workspace projects, ~1,100 versions; form files live under several
  paths besides `form_<name>.gpkg` (season archives, `_raw`, backups, conflicted copies)
- Created branch `36-list-the-2023-2025-versions-of-the-fish` off origin/main
- Scaffolded PWF baseline from issue #36 with approved phases
- Next: start Phase 1
- Plan review returned (review-plan.md). Folded into task_plan: decision 2 made precise, the
  kept-id reason corrected, "rename" defined as both sides lacking columns, overlap against
  accepted versions, per-season check, max-pk growth, the clash/type gaps, a regenerated-text
  carve-out. Privacy finding: the baseline named a deployment file stem; scrubbed and the
  unpushed baseline amended (now 52b19ac).
- Probed Mergin's version record: `user_agent` is there (desktop pushes read `Python-client/…`,
  `Plugin/… QGIS/…`), dropped by `rfp_mergin_changeset()`; filed against the form-tooling package.
- Phase 1 `read` running in the background since 16:26 UTC (~4 s per changeset).
- First `read` finished 19:13 UTC: 274 of 575 fetches refused on checksum. Diagnosed as server
  rebuilds of geodiff versions (all 274; no whole upload); added a rebuilt-file path checked by
  integrity and by each geodiff's insert/delete summary, and wrote the cause into the form-tooling package's issue.
  Second `read` 20:16 UTC, 0 failures; 361 geodiff versions agree with their diffs.
- Phase 1 committed (9b59e24). Asked with the results (2026-11-16): `site_id` → string; earlier-only
  columns get a `variants` key. Both recommended options taken.
- Spot-checked three fingerprints through the harvester's own column set: all match. Hand-checked
  one project's pscis chains. Found the harvester refuses every 2023 file's zone-less datetimes;
  filed against the harvester.
- Asked about the one desktop-only shape; the user asked whether it was an error copy. It was: its
  one "new" record duplicated record 35. Growth now needs a new key with new content; re-run
  dropped that shape and admitted two build resets. Phases 2–3 committed (81fac9f, 8464b83).
- Phase 4: decision record, `research/form_versions.md` (71a07cf). Reworded one commit message
  that cited a private issue (unpushed). Merged origin/main (photo tables, v0.17.0), then NEWS,
  CLAUDE.md status and the research index.
