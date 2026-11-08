# Task: README presents crate as a file reader; the provenance receipts are buried (#52)

`README.md` describes the package as it was before the receipts landed ([#43](https://github.com/NewGraphEnvironment/crate/issues/43)):

- The tagline is "Stable file readers for shape-shifting data sources.", while the package title has been "Canonical Schemas and Data Governance for Changing Data" since [#45](https://github.com/NewGraphEnvironment/crate/issues/45).
- The opening paragraphs name only `crt_ingest()` and `crt_schema_conform()`.
- Receipts first appear at line 142 of 151, as a bullet under "What crate handles today", an inventory of schemas. The paragraph after it ("Each addition = a YAML in `inst/extdata/schemas/` + a registry row") reads as if receipts were a schema.
- The one example is the bcfishpass ingest; nothing shows a receipt written or two builds compared.

Separately, `vignettes/receipt.Rmd`'s canonical-form list ("Dates are `YYYY-MM-DD`; datetimes are UTC …") does not say that a subclass such as data.table's `IDate` is spelled as its base class, which `?crt_table_fingerprint` says since 0.14.0 ([#49](https://github.com/NewGraphEnvironment/crate/issues/49)).

## Decided at the gate

Approved by the owner at the plan gate, 2026-11-07, as a park (baseline only):

- README stays hand-written markdown; example output is pasted from a real run, not invented.
- The receipt example reuses the vignette's shipped worked case, no new fixture.
- STAC field schemas get their own short section, not folded into receipts (lidarbc/las are not receipts).
- Docs only: no code change; release is a patch at merge (`/gh-pr-merge`).
- From the plan review (`review-plan.md`, folded in before the baseline commit): the receipt section keeps the issue's heading `## Provenance receipts` (matching `_pkgdown.yml` and the article); it shows a write as well as a compare; `### Naming convention` moves to its own `##` section because it spans both families; `CLAUDE.md:27`'s pointer to README "How it works" is updated with the rename.

## Context from exploration

crate has two jobs since 0.12.0 (#43): canonical schemas for changing inputs, and the
provenance receipt contract for outputs. `README.md` (hand-written, no `README.Rmd`; it is
also the pkgdown home page) still describes only the first:

- Tagline (line 3) "Stable file readers for shape-shifting data sources." vs the package
  title "Canonical Schemas and Data Governance for Changing Data" (#45). DESCRIPTION's
  `Description:` already names receipts; `_pkgdown.yml` already has a "Provenance receipts"
  reference section and article.
- Intro (lines 5–9) names only `crt_ingest()` / `crt_schema_conform()`.
- Receipts are a bullet at line 144 inside "What crate handles today" (a schema inventory),
  beside the STAC field schemas bullet (line 140); the closing paragraph (line 146, "Each
  addition = a YAML … + a registry row") then reads as if both were schemas.
- The only example is the bcfishpass ingest. The receipt vignette's worked case
  (`inst/extdata/receipt/examples/worked_case`, `vignettes/receipt.Rmd:46-66`) runs in one
  call and prints `equivalent (receipts only)` with the differences named — reusable as is.
- `vignettes/receipt.Rmd:177` canonical-form list does not mention Date/POSIXct subclasses
  (`?crt_table_fingerprint` does since 0.14.0, #49).

## Phase 1: Say both jobs up front

- [x] Tagline names both: canonical schemas for changing inputs, provenance receipts for outputs (in step with the #45 title)
- [x] Opening paragraphs: keep the `crt_ingest()` / `crt_schema_conform()` paragraphs; add one naming receipts (one `receipt.json` per output, rebuild judged identical / equivalent / different) linking `vignette("receipt")`
- [x] Rename `## Example` to `## Reading a file that changed shape` and `## How it works` to `## How reading works`, so the ingest sections say which job they describe
- [x] Move `### Naming convention` (README.md:90-100, lists both `crt_schema_*` and `crt_receipt_*`) out of the reading section to its own `## Naming convention`
- [x] Update `CLAUDE.md:27` (repo section, above the soul marker), which points to README "How it works", to the new heading

## Phase 2: A provenance receipts section

- [x] `## Provenance receipts` after the ingest example: what a receipt answers (the vignette's two questions / three verdicts, briefly); a short write, condensed from the vignette's write chunk (`vignettes/receipt.Rmd:209-233`, which writes from the worked case's own CSV); the worked-case `crt_receipt_compare()` call with its output pasted from a real run; links to `vignette("receipt")`, the published receipt schema (keep the github.io URL: it is the schema's `$id`) and `inst/extdata/receipt/vectors/v1.0.0/`; name the Python implementation in stacs
- [x] Remove the receipts bullet from "What crate handles today"

## Phase 3: The inventory describes schemas only

- [x] Move the STAC field schemas bullet to its own short `## STAC field schemas` section before "Sibling public packages"
- [x] "What crate handles today" and its closing "each addition" paragraph now cover only `file` / `schema_only` entries; check its intro sentence still reads right

## Phase 4: Vignette clause (#49 follow-on)

- [x] `vignettes/receipt.Rmd` canonical-form list: a `Date` or `POSIXct` subclass (data.table's `IDate`) is spelled as its base class

## Validation

- [x] Every relative link and path in the changed README resolves (`ls` each); the published schema URL answers 200 with redirects followed (`curl -sL -o /dev/null -w '%{http_code}'`; it 301s to www.newgraphenvironment.com, and the github.io form stays in the text)
- [x] Each README example's output, re-run with `devtools::load_all()`, is captured with `capture.output()`, prefixed `#> `, and every line found verbatim in README.md by script (the compare prints two sha256 hashes and 12-digit decimals an eye check would miss)
- [x] The vignette renders and the home page builds without warnings, both into temp destinations so nothing untracked lands in the tree (`rmarkdown::render(..., output_dir = tempdir())`; `pkgdown::build_home(preview = FALSE, override = list(destination = tempdir()))`); `git status` clean of render output afterwards
- [x] Tests unaffected (docs only); `/code-check` clean (once over the branch with `/code-check branch`)
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion

Verification: read the rendered home page top to bottom as a newcomer: within the first screen it
must say crate does both jobs; the receipt section's pasted output matches a fresh run.
