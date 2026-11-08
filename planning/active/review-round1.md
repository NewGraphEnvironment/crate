## Checklist read

- code-check-python.md: in full.
- code-check.md: prose of all 14 H3s under `## Mechanisms` (table rows skipped); plus "Documentation Staleness" and "A link to a repo-hosted artifact must be *tracked*, not merely present". 2 of the remaining headings read, all others not (none names a tool, shape or pattern this docs-only diff uses).
- code-check-r.md: 0 headings read in full. None of them names a pattern this diff uses. The diff adds no knitr chunk and moves no prose into a chunk, and the README examples call only crate functions plus `read.csv`/`write.csv`/`dir.create`, so no R trap heading applies.
- code-check-shell.md: 0 headings read (the diff has no shell).
- code-check-spatial.md: 0 headings read (the diff has no spatial code).

## What was executed against the code

- I ran the README `crt_receipt_write()` example verbatim under `devtools::load_all()`, from the scratchpad. `w$recipe$recipe_id` printed `6f2f62c41cccd8fee1a84e87cbf9486432cb942f00a965911ad4216bfaf93c02`, the same as the pasted value. `receipt.json` was written beside `access_check.csv`. The context (time, toolchain) was filled. The fingerprint and part digests were computed.
- `crt_receipt_compare(build_1, build_2)` printed exactly the five lines pasted in the README, byte for byte, with verdict `equivalent (receipts only)`.
- Prose claims checked:
  - The `access_check` fingerprints agree: the sha256 is identical in both receipts under `km = 1e-9`.
  - Same rows: 4 in each build.
  - The three verdicts match `crt_receipt_compare.R`. `warn` and `record` do not change the verdict.
  - `recipe` fields are `refuse` in `register.csv`.
  - The context is `record`, "never identity".
  - `stacs.receipt` matches the vignette and the vectors README.
  - The schema is installed: `inst/extdata/receipt/schema/v1.0.0/schema.json` ships, since `inst/` is not in `.Rbuildignore`.
  - The STAC `receipt:` schema declares only `receipt:recipe_id`.
  - "11th decimal place" is consistent with the vignette, research doc and data-raw: the largest difference is 9.5e-11.
- Vignette sentence: `crt_table_fingerprint()` of a `data.table::IDate` column equals that of the same `Date` column (NA included), and a `c("myt","POSIXct","POSIXt")` column equals the plain `POSIXct` one. The claim holds, and it matches the roxygen in `R/crt_table_fingerprint.R:28-29`.
- Links and anchors:
  - `#provenance-receipts` resolves to the new `## Provenance receipts` heading on both GitHub and pkgdown.
  - The repo-relative link targets are tracked in git: `inst/extdata/receipt/vectors/v1.0.0/README.md`, `pkgdown/assets/stac/README.md` and `decisions/nge/20261010_stac_field_schemas.md`.
- CLAUDE.md:27 points at "How reading works" and "Naming convention", and both headings exist. No other tracked file refers to the old "How it works", "## Example" or their anchors.
- The working tree was left clean: no tracked file was modified and pkgdown was not built.

## Clean
No issues found.
