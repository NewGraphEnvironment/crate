# Code review, round 3: issue #52 README restructure (docs only)

Diff: `git diff 64dc8dde...HEAD -- README.md CLAUDE.md vignettes/receipt.Rmd`

## Checklist read

- code-check-python.md: in full.
- code-check.md: 17 headings read, 20 not read. Read: the prose of all 14 H3s under `## Mechanisms` (table rows skipped), plus "Documentation Staleness", "A link to a repo-hosted artifact must be *tracked*, not merely present", and "An assertion that matches an interpolated value cannot see the claim around it".
- code-check-r.md: 0 headings read, 117 not read. No index line names a tool, shape or pattern this diff uses. The diff changes prose and an unevaluated README code block, not R code or knitr chunks.
- code-check-shell.md: 0 read, 70 not read (none apply).
- code-check-spatial.md: 0 read, 94 not read (none apply).

## Findings

- **[severity: bug]** README.md:120: the diff adds this new sentence to the README, which is also the pkgdown home page: "Python catalogues implement the same contract in `stacs.receipt` ([stacs](https://github.com/NewGraphEnvironment/stacs)) and pass the same vectors." It is false today.
  - No `stacs.receipt` module exists. `git -C ~/Projects/repo/stacs ls-tree -r origin/main` (fetched just now, tip `b73e2cb`) shows `src/stacs/` holding only `catalogue, cli, queryables, register, validate, verify`. `git grep -i receipt origin/main` finds nothing.
  - No stacs branch exists for the work, and [stacs#12](https://github.com/NewGraphEnvironment/stacs/issues/12) ("Read, write and compare provenance receipts for catalogue items, passing crate's test vectors") is **OPEN**.
  - How it went wrong: the sentence came from the vignette (vignettes/receipt.Rmd:22-25), which cites stacs#12 inline. That citation was the only sign the Python side is planned work, and the move to the README dropped it. The README links to the stacs repo root instead, so a reader who follows the link finds no receipt code.
  - The old README said nothing about stacs, so the diff introduced this claim. The same claim already existed before this diff, unchanged here, in vignettes/receipt.Rmd:22-23, inst/extdata/receipt/vectors/v1.0.0/README.md:5 and NEWS.md:17 ("Python's, in stacs, among them"). research/provenance_receipt.md:231-232 and :288 state it as the plan ("stacs' CI runs the same files at a pinned crate tag").
  - Fix: make it future tense or conditional and cite stacs#12, e.g. "Python catalogues will implement the same contract in `stacs` ([stacs#12](...))". Optionally do the same at the older sites.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies" ; code-check.md "The probe is broken before the world is"

## Checked and found sound (the restructure mechanism, README.md)

- L11 "See [Provenance receipts](#provenance-receipts) below": the section is below (L70), and it is the only heading with that slug.
- L124 "When you call `crt_ingest(...)`" and L142 "in our example": both refer back to the bcfp example. The receipt section now sits between that example and these lines, but L142 talks about the handler, `spawning`/`rearing` and `habitat_ind`, so it can only mean the bcfp example. Ambiguous at most, not false.
- L148 "steps 4–5 above": still in the same section as the numbered steps (L134-136).
- L158 "the conventions on each": still refers to the 5-step list just above. The Naming convention move does not touch it.
- Naming convention (L160-170) moved whole. Its function list matches the one at L120 and NAMESPACE exports (6 `crt_receipt_*` plus `crt_table_fingerprint`).
- The "Reserved future families" paragraph moved together with its section.
- "What crate handles today": the STAC and receipt bullets were moved out, and "More land as integration work surfaces… a YAML + a registry row" now follows the registered entries it describes.
- STAC section (L196): `lidarbc`, `las`, `receipt` match `pkgdown/assets/stac/`. The receipt STAC schema's only field is `receipt:recipe_id`, so "the `receipt:` fields mirror a receipt's `recipe_id`" holds. The README and decision-entry links are tracked files.
- The verdict definitions in L11 and L72 agree with each other, with the vignette's table (receipt.Rmd:40-44), with DESCRIPTION, and with the `_pkgdown.yml` reference description. The "(a table, raster, model or STAC item)" list and the worked-case prose (11th decimal, database summation order, synthetic copy) match receipt.Rmd:16 and :47-51.
- CLAUDE.md:27: both "How reading works" and "Naming convention" exist as README headings. No other file in the repo (planning/ and docs/ excluded) points at "How it works", "## Example", `#how-it-works` or `#example`.
- vignettes/receipt.Rmd:178-179: the sentence continues the list item correctly. A previous reviewer verified the claim itself.
- No tracked or untracked files were left in the repo by this review; only this findings file was written.
