# Code-check review, round 1: crate#54 (docs-only diff af8574b...HEAD)

## Checklist read

- code-check-python.md: in full (none applies; the diff has no Python).
- code-check-r.md: read 3 headings: "A duplicate knitr chunk label fails the build, and reading the diff will not find it", "Moving prose into a code chunk hides it from tools that scan the document", "`R CMD build` ships every top-level directory not in `.Rbuildignore`". 114 not read.
- code-check-shell.md: 0 headings read; 70 not read. The diff has no shell.
- code-check-spatial.md: 0 headings read; 94 not read. The diff has no spatial code.
- code-check.md: read the prose of all 14 H3s under `## Mechanisms` (table rows skipped), plus "Documentation Staleness" and "A link to a repo-hosted artifact must be *tracked*, not merely present". 21 not read.
- soul conventions/readme.md: in full, evidence blocks included. writing.md: read "State each claim by the code's definition", "Choose the form that lands with the reader" and "Measure the simplification".

## What I verified

- **Pasted output.** I ran the README example in a fresh `Rscript` against the installed branch (crate 0.14.1). `identical()` printed `[1] TRUE`, and the `crt_receipt_compare()` print matches the README byte for byte, all six lines.
- **Exports.** The README names `crt_ingest`, `crt_receipt_compare` and `citation`. CLAUDE.md's naming section names `crt_ingest`, `crt_files`, five public `crt_schema_*`, six `crt_receipt_*` and `crt_table_fingerprint`. All of them are in NAMESPACE. The vignette says the handler, `crt_schema_read`, `crt_schema_validate` and `crt_schema_apply` are internal, and NAMESPACE agrees.
- **Links.** I curled every URL in README.md, vignettes/reading.Rmd, inst/extdata/schemas/README.md and DESCRIPTION. All return 200 except `articles/reading.html`, which 404s until deploy, as expected. The three reference anchors (`id="ingest"`, `id="schemas"`, `id="provenance-receipts"`) are present on the live reference page. crate#55 exists and is open.
- **Vignette.** `vignettes/reading.Rmd` knits clean, and its chunk labels are unique.
- **Spec boxes.** All nine Proposed boxes in issue #54 are met by the diff, and so is each gate decision: the Ecosystem rows, reserved names dropped from the README and from CLAUDE.md's naming section and Status paragraph, the Title, the receipt vignette's stacs sentence left alone, and no NEWS edit. CITATION.cff still carries the old Title, but `update-citation-cff.yaml` regenerates it on a DESCRIPTION push to main, so that is expected.
- **Vignette claims.** Each was checked against R/crt_ingest.R, R/crt_schema_conform.R, R/crt_schema_apply.R, R/crt_schema_validate.R, the bcfp handler, the bcfp schema YAML and the fixtures. None failed except the line in finding 1.

## Findings

- **[severity: bug]** README.md:9, DESCRIPTION:11 (Description, line 1), man/crate-package.Rd:11, vignettes/reading.Rmd:21. "One declared shape for each data source it registers" and "Every source crate knows about is a row in its registry" are false by the code's definition of a source. In crate, `source` is the family code (`@param source Character. Source family code (e.g. "nge")`). The registry has 2 sources and 14 rows: `nge` alone registers 13 schemas. The shape belongs to each `(source, file_name)` entry, not to each source. In the vignette, the `crt_files()` output printed right under the sentence contradicts it, with `nge` repeated in its `source` column. The fix is to name the entry ("each file or table it registers", "every `(source, file_name)` pair is a row").
  - **Rule:** writing.md "State each claim by the code's definition" ; readme.md "Check each claim against the code path a run takes"

- **[severity: bug]** README.md:9, DESCRIPTION:11-13, man/crate-package.Rd:11. Both texts tie "reads **or conforms**" to "when a source renames a column … or changes its layout, the fix is made once in crate and code downstream keeps working". That holds only for `file` entries, which have upstream variants and a handler (R/crt_ingest.R). For the 12 `schema_only` entries, `crt_schema_conform()` (R/crt_schema_conform.R) only validates required columns and coerces types. It has no rename or variant step, so a renamed column aborts with "required canonical columns missing", and the fix lands in the caller's reader, not in crate. Only "changes a type" holds for both kinds.
    - The DESCRIPTION goes further than the README. It drops "the fix is made once in crate" and says downstream code "keeps working when a source renames a column … or changes its layout". For a `file` entry, a new shape aborts with "Input shape does not match any known upstream variant" until crate registers it. So the Description claims a resilience the README conditions on a crate change, and the two are out of step.
  - **Rule:** readme.md "Check each claim against the code path a run takes" ; readme.md "Write the tagline, the description field, the GitHub About and the opening together"

- **[severity: bug]** README.md:47. "The file's bytes and `km_total` differ, each within a tolerance the receipts declare". The receipts declare no tolerance on a file's bytes or sha256. R/crt_receipt_compare.R:127-139 accepts a part's differing bytes and sha256 only because the receipt names the table the file holds (`parts[...]$table`) and that table agrees (`agreed()`). The printed detail says so ("; table access_check agrees"). The `1e-9` tolerance is on the table's `km` column and acts through the fingerprint. The old README stated that condition ("the receipt says that file holds the `access_check` table, whose fingerprint agrees under the `1e-9` tolerance on `km`"). The rewrite drops it and moves the tolerance onto the bytes. A reader would expect a byte-count tolerance in the receipt, which does not exist.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies" (its paragraph "Compression runs both ways") ; writing.md "State each claim by the code's definition"

## Verdict

3 findings, all claim accuracy, in the README opening, DESCRIPTION/Rd and one sentence after the example. No broken links, no unexported function named as user-facing, the pasted output matches a fresh run, and no content the issue asked to keep was lost.
