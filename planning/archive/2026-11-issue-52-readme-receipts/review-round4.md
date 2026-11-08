# Code-check round 4 — #52 (docs only), focus b31d6bf

## Checklist read

- code-check-python.md: in full.
- code-check-r.md: 0 headings read in full (none names a tool, shape or pattern this docs-only diff uses: no chunk added, moved or relabelled, no code changed); 117 not read.
- code-check-shell.md: 0 read; 70 not read.
- code-check-spatial.md: 0 read; 94 not read.
- code-check.md: the prose of all 14 H3s under `## Mechanisms` (tables skipped), plus "Documentation Staleness" and "A link to a repo-hosted artifact must be *tracked*, not merely present"; 21 not read.

## Mechanisms behind rounds 1-3, and where each reaches

**(1) A claim checked against the repo's own copy rather than the system it describes.** Round 1's stacs finding: crate holds the vectors and the `receipt:` STAC schema, so the prose assumed the consumers already use them. b31d6bf fixed the three sentences that named `stacs.receipt`. Every claim in the changed files about an outside system, checked against that system:

| Where | Claim | Checked against | Result |
|---|---|---|---|
| README.md:122, vignettes/receipt.Rmd:21-25, CLAUDE.md:25 | Python receipts are planned in stacs, stacs#12 | `gh issue view 12 -R NewGraphEnvironment/stacs`: OPEN, its title and body match; `git -C stacs grep -i receipt origin/main` finds nothing | true |
| README.md:200 (new `## STAC field schemas`) | "JSON Schemas for the custom fields NGE's STAC catalogues write: `lidarbc`, `las` and `receipt`" and "The `receipt:` fields mirror a receipt's `recipe_id` into an item" | stacs origin/main and every local `stac_*` repo: no `receipt:` field anywhere. stacs#12 lists "Items carry the receipt's identity fields: `receipt:recipe_id`" as an unchecked Proposed item, and says "Each catalogue adopts it in its own issue, once this ships" | **false (Finding 1)** |
| vignettes/receipt.Rmd:15-18 (in a changed file, outside the hunks) | "Every package and catalogue that publishes a table, raster, model or STAC item writes its receipts in this one shape" | the same evidence: no catalogue writes a receipt | **false as a statement of fact (Finding 2)** |
| vignettes/receipt.Rmd:178-179 | a subclass of Date/POSIXct such as data.table's IDate is spelled as its base class | ran `crt_table_fingerprint` on `data.table::as.IDate()`, a hand-built `c("IDate","Date")` integer column, and a `c("myt","POSIXct","POSIXt")` column with another tzone: each fingerprint equals its base-class twin; R/crt_table_fingerprint.R:146-167 | true |
| README.md:11, :200 | the schemas are published at `.../crate/stac/<prefix>/v<X.Y.Z>/schema.json`; the receipt schema is also installed | curl: las v1.0.0, lidarbc v1.0.0 and v1.1.0, receipt v1.0.0 all 200; `inst/extdata/receipt/schema/v1.0.0/schema.json` exists | true |
| README.md:83 | "differed in the 11th decimal place of `km`" | worked_case access_check.csv: the differences are 9.5e-11, 3e-11 and 4e-11 | true (as a magnitude) |
| README.md:113-117 | pasted compare output | re-ran it: byte-identical | true |

**(2) A link checked in one renderer only.** Round 2: repo-relative links that GitHub resolves 404 on the pkgdown home page.

| Renderer | Checked | Result |
|---|---|---|
| GitHub | curl -L on all 33 URLs in README.md, the vignette and CLAUDE.md: every one the diff touches is 200. The only 404s are regex artifacts and placeholders in CLAUDE.md's soul section (`OWNER/PKG`, a trailing backtick), which this diff does not touch | ok |
| GitHub, tracked (the rule's predicate) | `git cat-file -e origin/main:<path>` for all 11 blob/main targets | all tracked on main |
| pkgdown home | ran `pkgdown::build_home()` in a `git archive HEAD` copy in the scratchpad (since deleted): every href is absolute or a site page; the in-page `#provenance-receipts` anchor and ids `how-reading-works`, `naming-convention`, `stac-field-schemas` exist; `vignette("receipt")` links to `articles/receipt.html` | ok |
| pkgdown, CLAUDE.md | local pkgdown writes CLAUDE.html, where `[NEWS.md](NEWS.md)` becomes a dead `NEWS.html`. But gh-pages has no CLAUDE.html and the live URL 404s, so the deployed site does not publish it. The link was there before this diff | not reachable |
| vignette | both links (crate#43, stacs#12) are absolute and 200 | ok |
| dangling pointers | `git grep` for the old headings ("How it works", "Example", the old in-list "STAC field schemas" and "Provenance receipts"), and the same search in the sibling repos under ~/Projects/repo: no hits outside planning/. CLAUDE.md:27 names "How reading works" and "Naming convention", and both headings exist | ok |

## Findings

- **[severity: bug]** README.md:200 — The new `## STAC field schemas` section says the schemas cover "the custom fields NGE's STAC catalogues write: `lidarbc`, `las` and `receipt`" and that "The `receipt:` fields mirror a receipt's `recipe_id` into an item". That is true of `lidarbc` (stac_uav_bc, stacs) but false of `receipt`: no catalogue writes a `receipt:` field. stacs#12 still has "Items carry the receipt's identity fields: `receipt:recipe_id` …" unchecked under Proposed and says each catalogue adopts it after that ships, and neither stacs origin/main nor any `stac_*` repo contains a `receipt:` field. This is round 1's mechanism one paragraph further down. b31d6bf corrected the three sentences that named `stacs.receipt` and left the sibling that makes the same claim without naming the module, in a section this diff rewrote ("The `receipt:` fields mirror…" is new wording). Suggested wording: the `receipt:` schema is published for items to mirror a receipt's `recipe_id`, and catalogues will write it once stacs#12 ships.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies" ; code-check.md "The probe is broken before the world is"

- **[severity: fragile]** vignettes/receipt.Rmd:15-18 — "Every package and catalogue that publishes a table, raster, model or STAC item writes its receipts in this one shape" is stated as present fact. The paragraph right after it, as b31d6bf rewrote it, says the catalogues' implementation is only planned, so the vignette now contradicts itself across two adjacent paragraphs. This line is outside the diff's hunks, but it is the same mechanism in a changed file. Reword it as a design rule ("is to write") or limit it to what exists today.
  - **Rule:** code-check.md "A guard's scope, escape hatches, and remedies"

No other defects found inside b31d6bf. Its stacs#12 references are accurate, all 11 rewritten links resolve to files tracked on main, and nothing it touched dangles.
