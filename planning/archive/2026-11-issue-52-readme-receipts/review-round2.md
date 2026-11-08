## Checklist read

- code-check-python.md: in full.
- code-check.md: the prose of all 14 H3s under `## Mechanisms` (table rows skipped), plus "Documentation Staleness" and "A link to a repo-hosted artifact must be *tracked*, not merely present". I did not read the other 28 headings.
- code-check-r.md: 2 headings read ("Moving prose into a code chunk hides it from tools that scan the document" and "`tempfile()` lives in the session tempdir, so a path printed in an error names a file R is about to delete"). I did not read the other 172.
- code-check-shell.md: 0 headings read, because the diff has no shell.
- code-check-spatial.md: 0 headings read, because the diff has no spatial code.

## What was executed

- Claims about other systems were checked against those systems, not against crate's own prose:
  - stacs `origin/main` (fetched; `b73e2cb`) has no file that mentions "receipt", and its `src/stacs/` has no `receipt` module.
  - `gh api .../stacs/branches` lists only `main` and `gh-pages`.
  - stacs#12 ("Read, write and compare provenance receipts ... passing crate's test vectors") is OPEN.
- pkgdown home page: the live site at https://newgraphenvironment.github.io/crate/ was built with pkgdown 2.2.1, the same major and minor version as the local 2.2.0. It renders each repo-relative README link as a relative `.html` link, and those links return HTTP 404.
- I ran the README `crt_receipt_write()` block twice in one session under `load_all()`. Both runs printed the pasted `recipe_id`. The only side effect of the second run is a `dir.create()` "already exists" warning, so this is not a failure.
- Sibling repos under ~/Projects/repo have no links to the old `#how-it-works` or `#example` anchors, and no "crate README" pointers to those headings.
- No tracked file was modified, and pkgdown was not built.

## Findings

- **[severity: bug]** README.md:120 says "Python catalogues implement the same contract in `stacs.receipt` ([stacs](https://github.com/NewGraphEnvironment/stacs)) and pass the same vectors." This is false today. stacs main has no `stacs.receipt` module and no receipt code of any kind. The work is stacs#12, which is still open. A reader who follows the stacs link finds nothing to use. This sentence is new to the README. The text it replaces, the old "Provenance receipts" bullet, made no claim about stacs. It copies vignettes/receipt.Rmd:22-25, but leaves out the vignette's stacs#12 citation, which was the only sign that the work is planned. The README's own pasted output was checked against a run, but this claim was checked only against the vignette, which is another copy of the same claim. Fix: say the work is planned, e.g. "stacs will implement the same contract in Python ([stacs#12](https://github.com/NewGraphEnvironment/stacs/issues/12))", or drop the sentence. These copies are outside the diff and make the same present-tense claim: vignettes/receipt.Rmd:22-23, inst/extdata/receipt/vectors/v1.0.0/README.md:5, NEWS.md:17 ("Python's, in stacs, among them") and CLAUDE.md:25 ("which stacs runs too").
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies"

- **[severity: bug]** README.md:120 and README.md:196: the repo-relative links `inst/extdata/receipt/vectors/v1.0.0/README.md`, `pkgdown/assets/stac/README.md` and `decisions/nge/20261010_stac_field_schemas.md` are broken on the pkgdown home page. pkgdown publishes none of these files, and it rewrites each link to a relative `.html` path. On the live site, `/crate/inst/extdata/receipt/vectors/v1.0.0/README.html`, `/crate/pkgdown/assets/stac/README.html` and `/crate/decisions/README.html` all return 404. The links work on GitHub. Round 1 checked that the targets are tracked in git, which shows they work on GitHub, not on the site. Scope: the same three links were already broken on main, and so are the other repo-relative links in the README (lines 126, 128, 130, 154, 158, 188, 190, 192). This diff rewrites lines 120 and 196, so it carries the broken links into new text. Fix: use absolute `https://github.com/NewGraphEnvironment/crate/blob/main/...` URLs, which work in both places. Fixing only the lines in this diff is enough for this PR.
  - **Rule:** none
