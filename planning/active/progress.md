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
  `Plugin/… QGIS/…`), dropped by `rfp_mergin_changeset()`; filed against rfp.
- Phase 1 `read` running in the background since 16:26 UTC (~4 s per changeset).
