# Code-check review, round 2: crate#54 (docs-only diff af8574b...HEAD, round 1 fix ddf40b4)

## Checklist read

- code-check-python.md: in full. Nothing applies, because the diff has no Python.
- code-check-r.md: 3 headings read in full: "Moving prose into a code chunk hides it from tools that scan the document", "A duplicate knitr chunk label fails the build, and reading the diff will not find it", and "`R CMD build` ships every top-level directory not in `.Rbuildignore`". 114 not read.
- code-check-shell.md: 0 headings read, 70 not read. The diff has no shell.
- code-check-spatial.md: 0 headings read, 94 not read. The diff has no spatial code.
- code-check.md: the prose of all 14 H3s under `## Mechanisms`, with table rows skipped. Also "Documentation Staleness" and "A link to a repo-hosted artifact must be *tracked*, not merely present". 21 not read.
- soul conventions/readme.md: in full, evidence blocks included. From writing.md: "State each claim by the code's definition", "Choose the form that lands with the reader" and "Measure the simplification".

## What I verified

- **The installed package was stale.** `packageDescription("crate")$Title` returned the pre-branch Title ("Canonical Schemas and Data Governance for Changing Data"). I reinstalled from the working tree with `R CMD INSTALL --no-test-load`, and the Title now matches DESCRIPTION. No R code changed on the branch, so round 1's output check still holds.
- **README example.** I ran it fresh against the reinstall. `identical()` printed `[1] TRUE`, and all six lines of `crt_receipt_compare()` output match README.md:39-44 byte for byte.
- **Round 1 fix 3, README.md:47.** Both worked-case receipts declare `tolerance.tables.access_check.km = 1e-09` and `tolerance.summary.km_total = 1e-06`. Each `parts[access_check.csv]` names `table: access_check`. Its fingerprints are identical in both receipts, because `crt_table_fingerprint()` writes `km` to 9 decimals. That fits R/crt_receipt_compare.R:127-139. The sentence is now correct.
- **Round 1 fix 2, the opening and DESCRIPTION.** The fix is now scoped to "a registered file". That holds for the two `file` entries through `crt_ingest()`'s variant match (R/crt_ingest.R). "Data read some other way is held to the same shape" holds through `crt_schema_conform()`, which validates and types any registered entry, `file` ones included (test-crt_schema_conform.R uses the bcfp fixture). README and DESCRIPTION say the same thing.
- **Vignette.** `rmarkdown::render()` of vignettes/reading.Rmd knits clean against the reinstall. Its chunk labels (setup, files, fixtures, ingest) are unique, and it reads no network. I checked each claim against code:
  - first set-equal variant wins: R/crt_ingest.R
  - steps 4-5 are validate then apply: R/crt_schema_conform.R
  - the five types, and the POSIXct tzone stamp: R/crt_schema_apply.R
  - all missing required columns listed: R/crt_schema_validate.R
  - "t"/"f" text pivoted to integer: the bcfp handler and YAML
  - registry columns: inst/extdata/crate_registry.csv

  Only the heading in finding 2 failed.
- **Ecosystem.** All ten rows match an internal issue's decided table, including fly's softened row ("select photos that cover a study area"). flooded's and drift's READMEs still carry the old "optimal coverage", and an internal issue records that as known.
- **Links.** decisions/README.md (new in inst/extdata/schemas/README.md) returns 200, and so do the reference anchors. CLAUDE.md is removed before the pkgdown deploy (`rm -f CLAUDE.md`, .github/workflows/pkgdown.yaml:71). `CLAUDE.html` 404s on the live site, so the CLAUDE.md edit does not publish.
- **.Rbuildignore** covers `planning`, `pkgdown`, `CLAUDE.md`, `decisions` and `research`. The new vignette is a real vignette under `vignettes/` and builds offline.

## Findings

- **[severity: fragile]** README.md:9, DESCRIPTION:11, man/crate-package.Rd:11. These read "a canonical shape for each **kind** of file or table it registers". Round 1's fix replaced "data source" with "kind", which is the repo's name for the other axis.
  - `kind` is a registry column with two values, `file` and `schema_only`. inst/extdata/schemas/README.md:15-17, which the README links from Learn more, opens "Two kinds of entry: A schema is registered as one of two `kind`s". The vignette introduces it the same way (reading.Rmd:64, "maps each `(source, file_name)` pair to its kind").
  - So by the repo's own definition the sentence claims two shapes. In fact there is one per `(source, file_name)` entry, 14 today.
  - This is round 1's finding 1 moved one axis over: one code term swapped for another that also names the wrong set. Naming the entry, as the vignette's fixed sentence does ("each file or table it registers"), avoids both.
  - **Rule:** writing.md "State each claim by the code's definition" ; readme.md "Write the tagline, the description field, the GitHub About and the opening together"

- **[severity: fragile]** README.md:54 ("how to register a new **source**") and vignettes/reading.Rmd:107 (heading "## Registering a **source**"). Round 1's fix did not reach these two places.
  - In crate, `source` is the family code (`@param source Character. Source family code`). The linked section, "Adding a new schema" (inst/extdata/schemas/README.md:44-51), registers a `(source, file_name)` entry. Its step 1 says to use an existing family where there is one.
  - The vignette's own body, right under the heading, says "How to add a `(source, file_name)` pair". The pre-change README called this section "Adding a new (source, file_name) pair".
  - A reader adding a table to `nge` is told the page is about registering a new source, which they are not doing.
  - **Rule:** writing.md "State each claim by the code's definition" ; readme.md "Check each claim against the code path a run takes"

## Noted, not flagged

- inst/extdata/schemas/README.md:51 step 6 (and reading.Rmd:110, "tests with fixtures") now attaches CSV fixtures at `inst/extdata/examples/<source>/<file_name>_<variant>.csv` to both kinds of entry. None of the 12 `schema_only` entries has one, and test-crt_schema_conform.R reads only the bcfp fixture. The pre-change README tied fixtures to `file` pairs. It is a contributor instruction, wider than practice, and harmless.
- `_pkgdown.yml`'s Ingest `desc:` ("Read a registered source file to its canonical shape.") lists `crt_files()`, which reads nothing. It predates the diff and is unchanged, but the README now links that group by anchor.
- `pkgdown/favicon/` is untracked in the working tree, probably left by a local `pkgdown::build_site()`. It is not in the diff. Stage by path so it does not ride into a commit.

## Verdict

2 findings, both fragile, both claim wording that round 1's fix left or introduced. No broken links, no unexported function named as user-facing, and the pasted output matches a fresh run. The vignette knits, and no content the issue asked to keep was lost.
