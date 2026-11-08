# Progress — README presents crate as a file reader; the provenance receipts are buried (#52)

## Session 2026-11-07

- Plan-mode exploration — phases approved by user (parked: baseline only)
- Created branch `52-readme-presents-crate-as-a-file-reader-t` off origin/main
- Scaffolded PWF baseline from issue #52 with approved phases
- Next: parked 2026-11-07; paste the block under ### Resume into a fresh session

### Resume

```
Continue crate#52 from its parked PWF baseline. Repo ~/Projects/repo/crate, branch `52-readme-presents-crate-as-a-file-reader-t`,
parked 2026-11-08 by `/planning-init crate#52 park`, branched from origin/main at 64dc8dd.
Run these in order, and stop at the first that fails; each failure means what it says:

cd ~/Projects/repo/crate && git fetch -q origin
git worktree list | grep -F '[52-readme-presents-crate-as-a-file-reader-t]' || echo none   # a path printed: that tree holds the branch; cd to it and skip the checkout
git branch --show-current; git status --porcelain --untracked-files=no   # another branch with changes, or one another session may be on: do not check out here; git worktree add ../crate-52 52-readme-presents-crate-as-a-file-reader-t and cd there
git checkout 52-readme-presents-crate-as-a-file-reader-t   # fails: the branch is not on origin
git pull --ff-only   # fails: this machine has commits origin lacks; resume where they were made
git merge origin/main   # a conflict: main moved meanwhile; resolve it, commit, and go on

Then read planning/active/task_plan.md, findings.md, progress.md and review-plan.md if present.
The gate decisions, the measurements and the Plan-agent review are already folded in:
do not re-plan and do not re-ask them.
Start Phase 1 and run every phase to the PR (/code-check branch, /planning-archive,
/gh-pr-push). This message is the resume instruction that starts the run-to-PR
mandate; the merge stays with me.
```

## Session 2026-11-07 (resumed)

- Resumed from park: branch already checked out in the main tree, up to date with origin and main
- Phase 1: tagline names both jobs; receipts paragraph in the intro; `## Example` → `## Reading a file that changed shape`, `## How it works` → `## How reading works`; `## Naming convention` its own section; `CLAUDE.md:27` pointer updated
- Phase 2: `## Provenance receipts` after the ingest example: two questions / three verdicts, a `crt_receipt_write()` (recipe_id output), the worked-case compare, the contract links and stacs; inventory bullet removed
- Phase 3: `## STAC field schemas` section before siblings (carries the `receipt:` mirror sentence); inventory intro reads "Registered entries"
- Phase 4: vignette canonical-form list gains the Date/POSIXct subclass clause
- Validation: 11 relative links resolve; schema URL 200 with -L; 7 pasted output lines found verbatim by script; ingest example still TRUE; vignette renders with 0 warnings, home page builds with 0 warnings (both to tempdirs); 1973 tests pass, 0 failed
- Found: `pkgdown::build_home()` creates untracked `pkgdown/favicon/` (realfavicongenerator) even with a temp destination; removed after each build
