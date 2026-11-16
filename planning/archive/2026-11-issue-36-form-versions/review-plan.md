# Plan review — #36 (Plan agent, 2026-11-16, background, returned while Phase 1's walk ran)

Findings as returned (condensed to one line each; verdicts added after probing):

- **Blocker — privacy:** baseline commit named a deployment file stem (scrubbed) and
  hinted at whom such files are named for; the privacy guard greps only project names. Extend the
  guard to every deployed file stem found in the walk. *Verdict: fold in (scrub, amend unpushed
  baseline, widen guard).*
- **Gap — decision 2 wording:** must say growth is measured against the previous version *in the
  same shape*, and a removal resets the chain (the code already does). *Fold into plan text.*
- **Gap — processed file refreshed at one path grows within a shape:** consider the version's
  pushing client (`user_agent`, unverified) as the discriminator. *Probe.*
- **Assumption — earlier seasons may survive only as archives:** require per-season counts of
  shapes that grew; stop and ask if a season has none. Baseline before 2023. *Fold in; the walk
  already reads every version, no date cut.*
- **Gap — row count misses delete+insert:** also compare max primary key. *Fold in at `write`.*
- **Assumption — pk handling vs harvester** for TEXT/composite pk; spot-check must not reuse
  `gpkg_decl`; exclude `layer_styles`. *Fold in: report non-integer pk tables, exclude by name,
  spot-check through the harvester's column set.*
- **Gap — decl_map / test fill types; envelope clash for old-only columns; the form builder would see
  retired columns as live unless marked machine-readably.** *Fold in the first two; the marker is
  a schema-key choice → ask with Phase 1's results.*
- **Gap — build descriptions' "every 2026 capture … except the variant below" becomes false;
  the 2025 variant's description is regenerated.** *Fold in; carve-out noted.*
- **Assumption — reason for keeping `capture-utm-columns-2025`:** harvested `schema_version`
  holds the fingerprint, not the id; keep it because it is a published id. *Confirmed; reword.*
- **Acceptance — "rename" iff not a subset is wrong for a superset.** Rename means each side has
  columns the other lacks. *Confirmed; fix test and derive.*
- **Scope — 50% overlap vs the 2026 build only** may reject a heavily reworked real version.
  *Fold in: best overlap against build ∪ accepted versions, and review rejects by hand.*
- **Ordering:** fine; red comes from the existing fixture↔variant one-to-one test.
- **Assumption — the changeset reader's parse of a removal with null checksum may error.** *Check
  failures.txt after the walk.*
