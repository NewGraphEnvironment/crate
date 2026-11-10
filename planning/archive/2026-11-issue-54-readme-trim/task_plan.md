# Task: README carries a tutorial, an inventory and unbuilt work; trim it to the opening, one example and pointers (#54)

## Problem

Our README convention: a README is the opening, a short example with its real output, and sections that point elsewhere. It leaves out function tables, inventories, method detail and anything not yet built, because each is kept somewhere else and goes stale in a README. After [#52](https://github.com/NewGraphEnvironment/crate/issues/52) / [PR #53](https://github.com/NewGraphEnvironment/crate/pull/53), `README.md` runs the other way:

- **The opening runs four paragraphs**, where one to three sentences should say what crate is and which decision it informs.
- **"Naming convention"** is a function table and a rule for contributors. Its "reserved future families" (`crt_schema_version`, `crt_schema_migrate`, `cols[].predicate`) describe functions that do not exist.
- **"What crate handles today"** is an inventory, and already stale: it lists 5 of the 14 entries `crt_files()` returns.
- **The ingest example prints `crt_files()`'s 14-row tibble**, which is an inventory and a count, and goes stale whenever a schema is registered.
- **"How reading works"** is method detail: the five-piece runtime, the datetime-instant paragraph, the variant-matching caveat, and "Adding a new (source, file_name) pair". The caveat calls type-aware variant matching "a planned v0.1.x improvement".
- **"Provenance receipts"** (added in PR #53) is a tour. It has a 25-line `crt_receipt_write()` call and a list of every receipt function, and says a Python implementation "is planned in stacs", which describes unbuilt work.
- **"STAC field schemas"** is a whole section for what is a pointer to `pkgdown/assets/stac/README.md`.
- **"Sibling public packages"** links GitHub repos rather than the packages' published sites, and gives no roles.
- **Missing:** a Learn more section, Citation, License, and a lifecycle badge.
- **The GitHub About text** ("Data governance — canonical schemas, data dictionary, QC rules, cross-domain normalization") does not match the DESCRIPTION title or the README tagline.


## Context

After crate#52 (PR #53), `README.md` is 201 lines of tutorial, contributor guide and inventory. It lists 5 of the 14 entries `crt_files()` returns, prints the whole `crt_files()` tibble, gives a 25-line `crt_receipt_write()` call and a full function list, and describes work that has not shipped ("planned v0.1.x", "reserved future families", "planned in stacs"). That breaks soul's `conventions/readme.md`, which I read in full for this plan (an internal issue notes that #52's plan never did). The issue has no comments. Branch `54-readme-carries-a-tutorial-an-inventory-a` will come off origin/main at af8574b.

What I found while exploring, which shaped the phases:
- `CLAUDE.md` already has a "Naming convention" section above the soul marker. It is stale: it is missing the public `crt_schema_*` and `crt_receipt_*` families, and it has its own reserved line. `CLAUDE.md:27` points at the README's "How reading works" and "Naming convention".
- `inst/extdata/schemas/README.md` already has "Adding a new schema" (6 steps). The README's 5-step "Adding a new (source, file_name) pair" adds only one thing to it: where fixtures go (`inst/extdata/examples/<source>/<file_name>_<variant>.csv`).
- `vignettes/` holds only `receipt.Rmd`. `_pkgdown.yml` lists one article and the reference groups Ingest, Schemas, Provenance receipts and Package.
- `inst/CITATION` builds the citation from DESCRIPTION (Title, `Config/DOI`), and `update-citation-cff.yaml` regenerates `CITATION.cff` from DESCRIPTION on main. So changing the Title updates both with no hand edit.
- Every `https://www.newgraphenvironment.com/<repo>/` site I tried returns 200, including crate's.

## Decided at the gate

- **Ecosystem** (user, 2026-11-08): the nine rows an internal issue decided on 2026-10-15, worded exactly as decided (fresh, link, wet, flooded, drift, floodplains, stac_floodplains_bc, cd, fly), plus a bold crate row. All link `https://www.newgraphenvironment.com/<repo>/`. gq, fpr and ngr are dropped.
- **Reserved names** (user, 2026-11-08): dropped everywhere. That means the README's list, CLAUDE.md's "Reserved future families" line, and the Status paragraph's "`crt_schema_version` / `crt_schema_migrate` reserved for future".
- **Tagline and About** keep today's tagline: "Canonical schemas for data that changes shape, and provenance receipts for what we build from it." The GitHub About is set to the same text.
- **Title** changes to "Canonical Schemas for Changing Data and Provenance Receipts" (58 characters). The current Title, set in #45, leaves receipts out.
- **The receipt vignette's "planned in stacs" sentence stays.** The issue covers the README only, and the vignette is the contract's reference.
- **No NEWS edit on the branch.** `/gh-pr-merge` writes the NEWS line and the patch bump.

## Phase 1: Move content out of the README

- [x] File an issue for type-aware variant matching (filed as crate#55): match on column names and types at dispatch, from the README's caveat. Link it from the new vignette.
- [x] Add `vignettes/reading.Rmd`, "How reading works", beside `receipt.Rmd`. It carries the five-piece runtime (registry, schema YAML, handler, validation, type enforcement), the note that steps 4–5 are `crt_schema_conform()`, datetimes as instants, and the variant-matching caveat (linking the new issue, with no "planned" line). It has live chunks: `crt_files()` and both bundled `bcfp` fixtures through `crt_ingest()`. Run live, they cannot go stale. Repo files the site does not publish are linked by absolute GitHub URL.
- [x] Add `reading` to `_pkgdown.yml` `articles:`.
- [x] `inst/extdata/schemas/README.md` "Adding a new schema": fold in the fixture path in step 6, and link `decisions/README.md` in step 5.
- [x] `CLAUDE.md` "Naming convention": merge in the README's family list (the public `crt_schema_*` functions, the `crt_receipt_*` family, and `crt_table_fingerprint` named apart from `crt_schema_fingerprint`). Drop the reserved line and the Status paragraph's reserved mention.
- [x] `CLAUDE.md:27`: point the runtime at `vignette("reading")`, and the function families at "Naming convention" below.

## Phase 2: Rewrite the README

- [x] Order: title + hex sticker; `<!-- badges: start -->` lifecycle `experimental` badge `<!-- badges: end -->`; tagline; opening; Installation; Example; Learn more; Ecosystem; Citation; License.
- [x] Opening, 2–3 plain sentences covering both jobs and naming the decision it informs. Draft, to be checked against the code in Phase 4: *crate gives each registered data source one declared shape and reads or conforms the data to it, so code downstream keeps working when the source renames a column, changes a type or changes its layout. It also writes a provenance receipt beside each output, so a rebuild can be judged identical to its reference copy, equivalent within a declared tolerance, or different, naming what differed.* The third sentence ties it to restoration planning and monitoring work, if a true one can be written.
- [x] Installation: `pak::pak("NewGraphEnvironment/crate")`, then a sentence saying crate is under active development and its functions change between releases (link NEWS), with the pin `pak::pak("NewGraphEnvironment/crate@vX.Y.Z")`.
- [x] Example: one context sentence (bcfishpass reshaped `user_habitat_classification.csv` long → wide). Then the two `crt_ingest()` calls and `identical(names(wide), names(long))`. Then the worked-case `crt_receipt_compare(build_1, build_2)` with its real output, and one sentence on why it says `equivalent`.
- [x] Learn more, one line each, linking the site: the reading article, the receipt article, reference groups by anchor (`#ingest`, `#schemas`, `#provenance-receipts`), `inst/extdata/schemas/README.md` (absolute GitHub URL), and STAC field schemas (`pkgdown/assets/stac/README.md`, absolute GitHub URL).
- [x] Ecosystem table as decided above. crate's row: "Canonical schemas for data that changes shape, and provenance receipts for outputs (this package)".
- [x] Citation: `citation("crate")`. License: MIT, with the LICENSE linked by absolute URL.
- [x] Removed: the four-paragraph opening, `crt_files()` tibble, Provenance receipts section (write example, function list, stacs sentence), How reading works, Naming convention, What crate handles today, the STAC field schemas section, and Sibling public packages.

## Phase 3: Title, Description, About in step

- [x] DESCRIPTION `Title` as decided. Rewrite `Description` in step with the opening (both jobs, no "First instance" line), ending "Under active development."
- [x] `devtools::document()`, so `man/crate-package.Rd` follows.

## Owed at the end (reported, done after merge)

- [ ] `gh repo edit NewGraphEnvironment/crate --description "<tagline>"` after the merge, so About changes when main's README does. Read it back with `gh api repos/NewGraphEnvironment/crate --jq .description`.

## Validation

- [x] Tests pass (`devtools::test()`) and `devtools::check()` is clean, including the new vignette build
- [x] `/code-check` clean (each commit, or once over the branch with `/code-check branch`): 3 rounds, ended on a 121-claim enumeration
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion

How each change is proved:
- **Example output:** run the README example in a fresh `Rscript` against the installed branch, and diff its output with the pasted output.
- **Exports:** every `crt_*` named in the README, the vignette and CLAUDE.md's naming section appears in `NAMESPACE` (grep).
- **Links:** extract every URL in README.md and `reading.Rmd` and `curl` each one for a 200. Build `pkgdown::build_site()` locally and check that the home page's links and the new article render. No relative link points at a file the site does not publish.
- **Claims audit** (readme.md, "Check each claim against the code path a run takes"): enumerate every claim in the README, tagline, Title, Description, About, the new vignette's prose and each `_pkgdown.yml` group `desc:` against the code, every claim rather than a sample. Check each "each/every/both" against its whole set.
- **Staleness:** `grep -nE "planned|will |reserved|v0\.1"` over README.md and the CLAUDE.md section returns nothing.

