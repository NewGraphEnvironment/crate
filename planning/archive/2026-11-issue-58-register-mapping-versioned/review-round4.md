# Code-check round 4: the release-tag step (commit 4cff553)

## Checklist read

- code-check-shell.index.md in full; full sections read: "Git plumbing calls whose default answers a different question", "A failed `git fetch` leaves the comparison you make next reading stale refs", "A fetch can fail and still deliver the commit, so when you need an object, test the object", "`for x in $(cmd | grep … || true)` hides a failing `cmd`", "`grep -c` prints the count AND exits 1 when it is zero", "A sed/awk range can run to EOF".
- code-check.md, `## Mechanisms`: prose of every H3 read (A guard that fails toward pass; A fixture that cannot reach the failure mode; A proxy is not the property; Verification that reads its own output; A guard's scope, escape hatches, and remedies; A fix lands in one of two callers that share a harness; Restore the bug and prove the guard fires; and the rest by their index lines).
- code-check-r / -spatial / -python indexes skimmed; nothing in them applies to this step.

## Method

Extracted the step's `run:` from the YAML with `yaml::read_yaml()` and ran it in fresh `git clone --depth=1 --no-tags file://` clones of the branch in the scratchpad (the shape actions/checkout@v4 leaves: shallow, no tags). Nothing in the main checkout was modified.

- Unmutated: tag fetch on the shallow clone works (19 tags, 20 shallow points), picks v0.14.1, rc=0 with one move warning (compare.json). Matches findings.md.
- Probes that came back clean: the shallow `--depth=1` tag fetch works, and a fork PR's checkout still has the base repo as `origin`, so its tags are reachable. A fetch failure, a bad tag, an empty `released` set and a failing `git show` all fail the step closed (set -e on the assignments; pipefail sends a `git show` failure to the "differs" arm). The `ls-tree`/`grep || true` lines are assigned separately, so the `for x in $(…|| true)` trap does not apply. No `.gitattributes`, so `hash-object` and `cmp` see raw bytes. `--sort=-v:refname` picks the highest vX.Y.Z; a non-release `v*` tag that sorted above it would fail closed rather than pass. On the release commit's push the latest tag is either the previous release or the release itself, and both are correct references. A tag push does not trigger this workflow.

## Findings

- **[severity: bug]** .github/workflows/pkgdown.yaml:61-73 — the move arm accepts deleting any released version, provided its bytes turn up at any other matching path. The comment at lines 38-39 says "an edit or a deletion fails". But the `else` arm looks for the released blob anywhere in `current`: any family, any version directory, or a released file that is still present and happens to hold the same bytes. Measured in scratch clones:
  - `git mv vectors/v1.0.0/jcs.json vectors/v2.0.0/jcs.json` gives a `::warning::` and rc=0.
  - `git mv schema/v1.0.0/schema.json mapping/v9.9.9/schema.json` gives a `::warning::` and rc=0.

  CHANGELOG.md says "the old one stays". The arm was written for one move, compare.json from vectors/ to register/ in this PR. After the next release the tag holds the new layout, so the arm serves no legitimate case and stays as a permanent escape hatch that GitHub reports only as a warning. Remedy: allow exactly the one known pair (`vectors/v1.0.0/compare.json` to `register/v1.0.0/compare.json`) and fail every other missing path. The pair can be deleted once a tag holds the new layout.
  - **Rule:** code-check.md, "A guard's scope, escape hatches, and remedies"

- **[severity: bug]** .github/workflows/pkgdown.yaml:47-53 — a file added to a released version directory passes. The loop runs only over files that are in the tag. Measured: adding `vectors/v1.0.0/extra.json` (and `git add`) gives rc=0. "A released version is never edited" covers the version's file set, and a vectors directory holds several files that other implementations run as a set (stacs#12). Only the same-commit `expect_setequal()` calls in tests/testthat/test-crt_receipt_vectors.R pin that set, and they hold hand-written names that one commit can edit together with the directory. That is round 3's defect again, on the file-set axis. Remedy: for each version directory in the tag (`dirname` of each released file), require that the matching files at HEAD equal the tag's set.
  - **Rule:** code-check.md, "A guard that fails toward pass" (the population is computed from one side only, so additions are invisible)

- **[severity: fragile]** .github/workflows/pkgdown.yaml:44 — comparing only against the *latest* tag lets the next release turn an edit into the reference. Measured: edit numbers.json and commit gives rc=1 (correct). `git tag v0.15.0` on that commit, run again: rc=0. The gh-pages reference protects itself, because a failing check blocks the deploy, so gh-pages never takes a bad file. The tag has no such link: it is cut by the release step, and nothing in this workflow stops a red commit from being tagged. /gh-pr-merge waits for the PR's checks (step 3c), but a web-UI merge or a direct push to main does not. From here the token sees no ruleset listing a required status check, and branch protection returned 403, so that could not be confirmed either way. The test comment at tests/testthat/test-crt_receipt_vectors.R:60 says the tag is "a release tag, which a commit cannot edit". That is true of the tag, but the reference moves to the edited bytes at the next release. Remedy: compare each released file against every `v*` tag that contains it, or against the earliest one. The tags are already fetched, and the cost is about 19 tags × 6 files of `git show`. A later release then cannot launder an edit.
  - **Rule:** code-check.md, "Verification that reads its own output" (the reference is re-derived from the artifact it guards at each release)

## Round-3 enumeration (findings.md)

No frozen *file* is missing from it. Two gaps the table does not show:

1. **The file set of each released version directory** is frozen by the CHANGELOG rule, but its only reference is in the same commit: the hand-written `expect_setequal()` and `released` names in test-crt_receipt_vectors.R. Finding 2 above.
2. **The "latest release tag" row is independent of a commit but not of a release**: it re-bases at every tag. Finding 3 above. The `pkgdown/assets` rows avoid this because a failing check blocks the deploy.

The register.csv/mapping.csv v1.0.0 gap is inherent and documented, as stated.

## Does the fix repeat round 3's mechanism one axis over?

Yes, on three axes. The **reference** is set by hand to "latest tag" instead of each file's release tag. The **population** is set by the files present in the tag, not the version directories' file sets. The **exemption** is a generic move rule written for one case.
