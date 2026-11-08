# Code-check review, round 3: crate#54 (docs-only diff af8574b...HEAD, round fixes ddf40b4 and 0fb3170)

## Checklist read

- code-check-python.md: read in full. Nothing applies, because the diff has no Python.
- code-check-r.md: read 5 headings in full: "Moving prose into a code chunk hides it from tools that scan the document", "A duplicate knitr chunk label fails the build, and reading the diff will not find it", "`identical()` on two reader results tests the reader, not the file", "Reproducibility", "`tolerance` in testthat is RELATIVE, so it pins a published figure far more loosely than it looks". 112 not read.
- code-check-shell.md: 0 headings read, 70 not read. The diff has no shell.
- code-check-spatial.md: 0 headings read, 94 not read. The diff has no spatial code.
- code-check.md: read the prose of all 14 H3s under `## Mechanisms`, skipping table rows. Also read "Documentation Staleness", "A link to a repo-hosted artifact must be *tracked*, not merely present" and "An assertion that matches an interpolated value cannot see the claim around it". 20 not read.
- soul conventions/readme.md: read in full, evidence blocks included. From writing.md, read "State each claim by the code's definition", "Check that each guard covers the set its sentence names", "Choose the form that lands with the reader" and "Measure the simplification".

## The mechanism

All five findings from rounds 1 and 2, and the four below, come from one cause. A sentence was checked against what its words usually mean, not against the set the code gives them. That happens in two ways:

1. **A term is swapped for a neighbouring one with a different scope.** Examples: source for entry, kind for entry, tolerance for table agreement. This round adds verdict for identity.
2. **A clause that holds for some members is tied to the whole set.** Earlier rounds found the fix "made once in crate", which holds only for `file` entries. This round adds "custom fields in the catalogues" (true of `lidarbc` and `las`, not `receipt`), "one function per `(source, file_name)`" (true of the 2 `file` entries, not all 14) and "handlers carry no type knowledge" (true of neither handler).

It shows up wherever the branch rewrote a sentence it carried over, because a reworded sentence loses the qualifier the original had. Three of the four findings below are rewordings of old README text: "never part of an identity", the STAC qualifier "catalogues adopt it with receipts", and "handlers don't encode type knowledge". Rounds 1 and 2 checked the new sentences. They did not check every carried-over sentence against code. The enumeration below does.

## What I verified (fresh, this round)

- Reinstalled with `R CMD INSTALL --no-test-load`. `packageDescription("crate")$Title` is the new Title.
- README example, fresh `Rscript`: `identical()` printed `[1] TRUE`, and all six `crt_receipt_compare()` lines match README.md:39-44 byte for byte.
- Ran a probe of README.md:47. I added `register: {context.run: refuse}` to the shipped `receipt_keys.yaml` and passed it to `crt_receipt_compare(..., keys = crt_receipt_keys(f))` on the worked case. The output was `different (receipts only)` with `refuse context.run`.
- Ran a probe of a `schema_only` entry. `crt_schema_conform()` on `nge/form_capture` conforms. After renaming one column it aborts "required canonical columns missing". `crt_ingest()` on it aborts "registered schema_only".
- `rmarkdown::render()` of vignettes/reading.Rmd knits. Its chunk labels in that file are unique (setup, files, fixtures, ingest), and `str(long[c("spawning","rearing")])` shows `int`.
- Links curled this round: NEWS, LICENSE.md, the STAC README, the schemas README, articles/receipt.html, decisions/README.md and crate#55. All return 200. crate#55 is OPEN, with the title "crt_ingest() matches upstream variants by column names only; check types at dispatch too".
- STAC adoption: across the local checkouts of stac_airphoto_bc, stac_dem_bc, stac_floodplains_bc, stac_orthophoto_bc, stac_pointcloud_bc, stac_uav_bc and stacs, no tracked file contains `receipt:`. `lidarbc`/`las` appear in 6 of the 7. stacs#12 is OPEN.

## Findings

- **[severity: fragile]** README.md:47: "The run identifiers and times are recorded, **never part of the verdict**."
  - The register sets `context.*` to `record` by default (inst/extdata/receipt/register.csv:36-44). But a package's declaration can harden any field outside the recipe: R/crt_receipt_keys.R:33-34 says "`register` may only soften or harden fields outside the recipe", and `receipt_register()` in R/crt_receipt_compare.R applies it.
  - With `context.run: refuse`, the same worked-case comparison returns `different` with `refuse context.run`. So the run identifier can be part of the verdict.
  - The text this replaced, and vignettes/receipt.Rmd:69 and 107, say "never part of an **identity**". That holds, because context never enters `recipe_id`. The rewrite swapped identity for verdict, a word the code uses for something else.
  - Fix: "...are recorded, not part of this verdict", or go back to "never part of an identity".
  - **Rule:** writing.md "State each claim by the code's definition" ; code-check.md "A guard's scope, escape hatches, and remedies" (paragraph "Compression runs both ways": a sentence that changed a term is unsupported until checked)

- **[severity: fragile]** README.md:55: "[STAC field schemas]: JSON Schemas **for custom fields in New Graph Environment's STAC catalogues**, published on this site."
  - The set is the three published prefixes: `lidarbc`, `las` and `receipt` (pkgdown/assets/stac/README.md:7-9). No catalogue carries `receipt:` fields. No local stac_* or stacs checkout contains `receipt:`, and stacs#12, which would add them, is OPEN.
  - The removed README section said so ("catalogues adopt it with receipts ([stacs#12])"). The new one-line pointer dropped that qualifier and tied all three schemas to "fields in the catalogues".
  - crate#52's round 4 found this same claim false ("the custom fields NGE's STAC catalogues write: `lidarbc`, `las` and `receipt`"), and NEWS.md:3 records it as removed. This branch puts it back.
  - Aside, not counted as a fail: "published on this site" is true on the pkgdown home page. On GitHub, "this site" is github.com, and the schemas are served from newgraphenvironment.github.io/crate/stac/. Naming the site fixes both readings.
  - Fix: something like "JSON Schemas for custom STAC fields, published on crate's site", with no claim that catalogues carry them.
  - **Rule:** readme.md "Describe nothing that is not fully built" ; readme.md "Check each claim against the code path a run takes"

- **[severity: fragile]** vignettes/reading.Rmd:71-72: "3. **Handler** (...), **one function per `(source, file_name)`**."
  - The registry has 14 `(source, file_name)` pairs, and 2 have a handler (`handler_fn` is empty for the 12 `schema_only` rows in inst/extdata/crate_registry.csv).
  - Item 1 of the same list says it correctly ("for a `file` entry, its handler function", reading.Rmd:64-65). So the list contradicts itself, and item 3 states for all 14 pairs what holds for 2. It is the same move as round 1's "each data source" and round 2's "each kind".
  - Fix: "one function per `file` entry".
  - **Rule:** writing.md "State each claim by the code's definition" ; readme.md "Check each claim against the code path a run takes" (each/plural over its whole set)

- **[severity: fragile]** vignettes/reading.Rmd:80-81: "The schema is the one place types are declared, **so handlers carry no type knowledge**."
  - Both handlers carry type knowledge:
    - The bcfp handler builds integers itself: `ifelse(ind_norm %in% c("t","true","1"), 1L, NA_integer_)` in R/crt_handler_bcfp_user_habitat_classification.R. Item 3 of the same list says so ("turning the `habitat_ind` text into integer indicators", reading.Rmd:75).
    - The fish_data handler turns a POSIXct or Date `date` into an ISO string with `format()`, aborts on a time of day, and coerces `pit_tag_id` with `as.character()` (R/crt_handler_nge_fish_data.R:52 and the day helper below line 89).
  - The code's own roxygen makes the same claim (R/crt_schema_apply.R, "handlers do not encode type knowledge"). The branch rewrote the sentence but did not check it against the handlers.
  - What is true: handlers need not produce the declared types, because `crt_schema_apply()` coerces whatever they return.
  - Fix: "so a handler need not produce the declared types: step 5 coerces what it returns".
  - **Rule:** writing.md "State each claim by the code's definition" ; code-check.md "A guard that fails toward pass" (paragraph "Where the guard sits": a comment stating a property is an unexecuted claim; execute it over the population it quantifies over)

## Noted, not flagged

- CLAUDE.md:47 says "A function not yet built is an issue, not a name held here." The "Boundary with rfp" section in the same file (CLAUDE.md:19, 21) still names unbuilt `crt_normalize()` / `crt_validate()` and `crt_normalize/validate/export/load`. Read as "this section", the sentence holds. That section predates the diff, and the gate limited the reserved-name removal to the naming section and the Status paragraph.
- inst/extdata/schemas/README.md step 6 says to put tests in "`test-crt_ingest.R` for a `file` entry". `fish_data`'s tests live in test-crt_handler_nge_fish_data.R. That instruction predates the branch, which only appended the fixture clause.
- vignettes/reading.Rmd:110 lists "a decision entry and tests with fixtures" without the README's qualifiers ("when not self-evident", "for a `file` entry"). As a list of what the linked README covers, it is accurate.
- vignettes/reading.Rmd:85: `crt_schema_conform()` also runs `crt_schema_fingerprint_check()`, a warning, as well as steps 4 and 5. That third step does not contradict "Steps 4 and 5 are `crt_schema_conform()`" in any way a reader would act on.

## Enumeration

**121 claims**: README.md 44, DESCRIPTION and man/crate-package.Rd 9, vignettes/reading.Rmd 48, CLAUDE.md (changed lines, above the soul marker) 16, inst/extdata/schemas/README.md (changed lines) 3, _pkgdown.yml 1. **117 pass, 4 fail.**

### README.md (44)

1. L7 tagline "Canonical schemas for data that changes shape, and provenance receipts for what we build from it" — registry schemas; R/crt_receipt_write.R — pass
2. L4 lifecycle badge `experimental` — issue gate; DESCRIPTION "Under active development." — pass
3. L9 "crate declares a canonical shape for each file or table it registers" — all 14 rows of crate_registry.csv carry `schema_yaml`, and test-crt_registry_integrity.R walks each — pass
4. L9 "It reads a registered file to that shape whichever known layout arrives" — R/crt_ingest.R kind check plus the `upstream_variants` loop; 2 `file` entries with 2 and 3 variants — pass
5. L9 "when upstream changes the file's columns or layout, the fix is made once in crate and code downstream keeps working" — crt_ingest aborts on an unknown variant; the fix is a new `upstream_variant` and a handler branch (crt_ingest roxygen @details) — pass
6. L9 "data read some other way is held to the same shape" — `crt_schema_conform()` takes any registered entry; probe on form_capture — pass
7. L9 "Its provenance receipt, one JSON file beside an output" — crt_receipt_write.R:38 and :87, `receipt.json` in the output's directory — pass
8. L9 "records how the output was made and what came out" — recipe and result blocks — pass
9. L9 "judged identical, equivalent within a declared tolerance, or different, naming what differed" — crt_receipt_compare.R:156-161, `differences` tibble — pass
10. L17 "under active development and its functions change between releases (see NEWS)" — NEWS link 200 — pass
11. L17 pin line `@vX.Y.Z` — `git tag`: v0.6.0 to v0.14.1 exist — pass
12. L21 "bcfishpass reshaped `user_habitat_classification.csv` from long to wide on 2026-04-26" — decisions/bcfp/20260427_*.md:13 and :58; YAML variant ids — pass
13. L21 "crate ships a small synthetic example of each shape" — examples/bcfp/*_long.csv and *_wide.csv, `source` = "test fixture" — pass
14. L21 "one call reads either to the same columns" — fresh run, `identical()` TRUE — pass
15. L23-31 code and `#> [1] TRUE` — fresh run — pass
16. L34 "One build was made twice from the same code, and its `km` column differed in the 11th decimal place" — worked_case access_check.csv 12.3456789012 vs 12.345678901295 (9.5e-11); the other three tables are identical by `cmp`; only access_check has `km` — pass
17. L34 "because the database summed in another order" — receipt.Rmd:48-50 (knowledge#145 account; external, not code) — pass
18. L34 "crate ships a synthetic copy of both builds with their receipts" — worked_case/build_{1,2}/receipt.json; receipt.Rmd:50 — pass
19. L37-45 compare call and six output lines — fresh run, byte for byte — pass
20. L47 "The file's bytes differ" — 124 vs 128 — pass
21. L47 "the receipt says the file holds the `access_check` table" — `parts[access_check.csv]$table`, crt_receipt_compare.R:129-133 — pass
22. L47 "whose fingerprint agrees under the declared `1e-9` tolerance on `km`" — both receipts' `tolerance.tables.access_check.km`; identical fingerprints (verified R2) — pass
23. L47 "`km_total` differs within its `1e-6`" — output line 3; crt_receipt_compare.R summary loop — pass
24. L47 "so the builds are equivalent" — no refuse, some within: crt_receipt_compare.R:156-161 — pass
25. L47 "The run identifiers and times are recorded" — register.csv:36 and :38 `record` — pass
26. L47 "never part of the verdict" — crt_receipt_keys.R:33-34; probe with `context.run: refuse` gives `different` — **FAIL** (finding 1)
27. L51 How reading works: "what crate knows about, one call reading two shapes of a file, and what happens between the file and the returned table" — reading.Rmd headings at L18, L27 and L56 — pass
28. L52 Provenance receipts: "the receipt contract, writing a receipt and comparing two builds" — receipt.Rmd "## The four blocks", "## Writing a receipt", "## Comparing" — pass
29. L53 reference groups Ingest, Schemas, Provenance receipts by anchor — _pkgdown.yml:6, :12, :16; anchors verified live in R1 — pass
30. L54 Schemas: "the schema format, and how to register a new file or table" — schemas/README.md "## Format", "## Adding a new schema" — pass
31. L55 "JSON Schemas for custom fields in New Graph Environment's STAC catalogues" — set {lidarbc, las, receipt}; no catalogue carries `receipt:`; stacs#12 OPEN — **FAIL** (finding 2)
32. L55 "published on this site" — pkgdown serves /crate/stac/; true on the home page, ambiguous on GitHub — pass (noted under finding 2)
33. L61 crate row "Canonical schemas for data that changes shape, and provenance receipts for outputs" — gate decision; matches the tagline — pass
34. L62 fresh row — soul#416 decided wording (gate; verified R2) — pass
35. L63 link row — same — pass
36. L64 wet row — same — pass
37. L65 flooded row — same — pass
38. L66 drift row — same — pass
39. L67 floodplains row — same — pass
40. L68 stac_floodplains_bc row — same — pass
41. L69 cd row — same — pass
42. L70 fly row — same — pass
43. L75 `citation("crate")` — inst/CITATION; run prints the new Title — pass
44. L80 "MIT (see LICENSE.md)" — DESCRIPTION `MIT + file LICENSE`; LICENSE.md 200 — pass

### DESCRIPTION and man/crate-package.Rd (9)

45. Title "Canonical Schemas for Changing Data and Provenance Receipts" — matches the tagline — pass
46. "Declares a canonical shape for each file or table it registers" — as claim 3 — pass
47. "reads a registered file to that shape whichever known layout arrives" — as claim 4 — pass
48. "holds data read some other way to the same shape" — as claim 6 — pass
49. "so a change in a registered file's columns or layout is fixed once in crate rather than in every reader downstream" — as claim 5 — pass
50. "the provenance receipt contract: a JSON Schema, RFC 8785 canonical JSON, a table fingerprint and test vectors" — inst/extdata/receipt/schema/, R/crt_receipt_jcs.R, R/crt_table_fingerprint.R, inst/extdata/receipt/vectors/ — pass
51. "R functions that write receipts and compare two builds as identical, equivalent within a declared tolerance, or different" — crt_receipt_write, crt_receipt_compare — pass
52. "Under active development." — readme.md lifecycle rule wording — pass
53. man/crate-package.Rd \title and \description — same text as claims 45-52 (roxygen from DESCRIPTION) — pass

### vignettes/reading.Rmd (48)

54. L2/L5 title and index entry "How reading works" — matches _pkgdown.yml and README L51 — pass
55. L20 "Every file or table crate knows about is a row in its registry, keyed by a source family and a file name" — crt_registry_entry.R keys on source and file_name (scoped to data shapes; receipt and STAC schemas are not data entries) — pass
56. L20-21 "A `file` entry is one crate reads and normalizes with `crt_ingest()`" — crt_ingest.R kind check — pass
57. L21-22 "A `schema_only` entry declares a canonical shape for data crate does not read, which you hold to that shape yourself with `crt_schema_conform()`" — crt_ingest abort message; form_capture probe — pass
58. chunk `files`: `crt_files()` — live, 14 rows at render — pass
59. L28-29 "bcfishpass changed ... on 2026-04-26 from a long format" — decisions/bcfp:13 — pass
60. L29 "one row per segment, species and habitat type" — handler comment "(segment x species x habitat_type)"; YAML variant description — pass
61. L30 "with a text `habitat_ind` of `"t"` or `"f"`" — YAML pre-2026-04-26-long description — pass
62. L30 "to a wide format with integer `spawning` and `rearing` columns" — YAML 2026-04-26-wide; canonical types integer — pass
63. L31 "crate ships a small fixture of each" — examples/bcfp — pass
64. chunk `fixtures` — live; column names printed at render — pass
65. L46 "The same call reads both to the canonical wide shape" — render: `identical()` TRUE, both columns `int` — pass
66. L57-58 "When you call `crt_ingest(...)`, five pieces wire together" — crt_ingest.R body: registry entry, `crt_schema_read`, variant match and handler, `crt_schema_conform` (validate, apply) — pass
67. L62-64 Registry "maps each `(source, file_name)` pair to its kind, its schema YAML and, for a `file` entry, its handler function" — crate_registry.csv columns — pass
68. L65 "It is what `crt_files()` prints above" — crt_files.R returns `crt_registry_load()` — pass
69. L68 Schema YAML "declares the canonical columns (names, types, required flags)" — bcfp YAML `canonical.cols` — pass
70. L68-69 "and each known upstream variant: a set of column names and an id" — YAML `upstream_variants[].id/cols`; crt_ingest uses those two — pass
71. L69 "`crt_schema_read()` loads it" — crt_ingest.R — pass
72. L72 Handler "one function per `(source, file_name)`" — 2 handlers for 14 pairs — **FAIL** (finding 3)
73. L72-73 "crate matches the file's column names against each variant's (the first set-equal match wins)" — crt_ingest.R `setequal` then `break` — pass
74. L73-74 "passes the matched variant's id to the handler" — `handler(raw, matched_variant$id)` — pass
75. L74 "`2026-04-26-wide` passes the data through" — `crt_handler_bcfp_uhc_identity` — pass
76. L74-76 "`pre-2026-04-26-long` pivots the long rows to wide, turning the `habitat_ind` text into integer indicators in the same step" — `crt_handler_bcfp_uhc_pivot_long_to_wide` — pass
77. L77-78 Validation "checks that every column the schema declares `required: true` is present, and fails listing all that are missing" — crt_schema_validate.R — pass
78. L79-80 Type enforcement "coerces every declared column to its schema type (`integer`, `double`, `string`, `logical` or `datetime`)" — crt_schema_apply.R loop; `crt_schema_types()`; an absent optional column has nothing to coerce — pass
79. L80-81 "The schema is the one place types are declared" — handlers declare no types; apply reads `canonical.cols[].type` — pass
80. L81 "so handlers carry no type knowledge" — bcfp handler emits `1L`/`NA_integer_`; fish_data formats `date` and uses `as.character()` on `pit_tag_id` — **FAIL** (finding 4)
81. L81-82 "readr's guesses (a double for an integer column, a `Date` for a declared string) do not leak through" — crt_ingest `read_csv` with guessing; apply's `as.integer`/`as.character`; crt_schema_conform example (`blue_line_key`) — pass
82. L84 "Steps 4 and 5 are `crt_schema_conform()`, which `crt_ingest()` calls rather than repeats" — crt_schema_conform.R:65-66; crt_ingest's last line — pass (fingerprint warning noted)
83. L84-85 "so a file crate reads and a data frame you bring get the same treatment" — same function — pass
84. L85-86 "The handler, `crt_schema_read()`, `crt_schema_validate()` and `crt_schema_apply()` are internal" — NAMESPACE exports none of them — pass
85. L86-87 "you call `crt_ingest()` or `crt_schema_conform()`, and they call the rest" — both are exported; together they reach all four — pass
86. L91 "A `datetime` column is an instant, and crate never moves it" — `crt_datetime_utc`: stamp, UTC parse, a non-UTC offset aborts — pass
87. L91-92 "A `POSIXct` has its timezone attribute *stamped* to UTC rather than converted" — `attr(x, "tzone") <- "UTC"` — pass
88. L92-94 "Several readers return correct UTC instants with no timezone label, which R then renders in the session's zone" — crt_schema_apply.R roxygen (sf GeoPackage DATETIME) — pass
89. L94-95 "Converting them ... would put a whole-hour error into every join downstream" — same roxygen; hypothetical — pass
90. L95 "Stamping fixes the label, which was the only thing wrong" — same — pass
91. L99 "`crt_ingest()` picks the upstream variant by the set of column names alone" — crt_ingest.R `setequal(variant$cols, raw_cols)` — pass
92. L99-101 "It does not compare column types at that step, so an upstream file that kept its column names and changed a type would reach the handler misshapen" — same — pass
93. L101-102 "`crt_schema_apply()` then coerces the output, and some coercions turn a value into `NA` without an error (`as.integer("yes")`)" — `suppressWarnings(as.integer(x))` — pass
94. L102-103 "Checking types at dispatch is crate#55" — `gh issue view 55`: OPEN, title matches — pass
95. L105 "Required columns and output types are still enforced, by steps 4 and 5" — crt_schema_conform — pass
96. L107 heading "Registering a file or table" — the linked section registers a `(source, file_name)` entry of either kind — pass
97. L109 "How to add a `(source, file_name)` pair" is in schemas/README.md — schemas/README.md "## Adding a new schema" — pass
98. L109 "a schema" — step 2 — pass
99. L109 "a registry row" — step 4 — pass
100. L109 "a handler for a `file` entry" — step 3 — pass
101. L110 "a decision entry and tests with fixtures" — steps 5 and 6 (listed as what the README covers; the README qualifies both) — pass

### CLAUDE.md, changed lines above the soul marker (16)

102. L25 "Two source families registered: `bcfp` (one `file` entry with a handler) and `nge` (one `file` entry with a handler, `fish_data` ...)" — crate_registry.csv — pass
103. L25 "`fish_data` ... reads the 2023 and 2024+ individual fish files to one canonical set" — fish_data.yaml variants 2023-peace-6col, 2023-skeena-7col, 2024-field-sheet — pass
104. L25 "the rest are `schema_only` entries — the three GPS-track tables, the `form_capture` envelope, the five fish passage form schemas ..., and wet's published discharge datasets" — registry: 3 + 1 + 5 + 3 = 12 — pass
105. L25 "conformed by the caller via `crt_schema_conform()`" — crt_ingest abort for schema_only — pass
106. L25 "`crt_schema_read` / `crt_schema_apply` / `crt_schema_validate` / `crt_schema_conform` exist, and crate#13 added `crt_schema_cols` / `crt_schema_grade` / `crt_schema_variant` / `crt_schema_fingerprint`" — R/ files present — pass
107. L25 "crate also publishes STAC field schemas (`lidarbc`, `las`, `receipt`) from `pkgdown/assets/stac/` via the pkgdown site" — pkgdown/assets/stac/{lidarbc,las,receipt} — pass
108. L25 receipt contract locations: schema in `inst/extdata/receipt/schema/`, published from `pkgdown/assets/receipt/`, vectors in `inst/extdata/receipt/vectors/` — directories exist — pass
109. L25 "which stacs's planned implementation will run too, stacs#12" — stacs#12 OPEN (unchanged clause) — pass
110. L25 "`research/provenance_receipt.md` holds the design decisions" — file exists — pass
111. L25 "A version on `gh-pages` is frozen: change one by adding a version, never by editing" — pkgdown/assets/stac/README.md rule 4 — pass
112. L27 "See `vignette("reading")` for the 5-piece runtime" — reading.Rmd "## Five pieces at runtime" — pass
113. L27 "\"Naming convention\" below for the function families" — CLAUDE.md:37 heading — pass
114. L42 "`crt_schema_conform`, `crt_schema_cols`, `crt_schema_grade`, `crt_schema_variant`, `crt_schema_fingerprint` — public" — NAMESPACE — pass
115. L43 "`crt_receipt_write` ... `crt_receipt_migrate` — public ...; `crt_table_fingerprint` beside it" — NAMESPACE (all 7 exported) — pass
116. L43 "`crt_schema_fingerprint`, which hashes column names and types rather than values" — crt_schema_fingerprint.R roxygen (`name:TYPE` pairs, XXH64) — pass
117. L47 "A new function joins the family it belongs to. A function not yet built is an issue, not a name held here. See crate#4" — rule; holds for the naming section (Boundary section noted above) — pass

### inst/extdata/schemas/README.md, changed lines (3)

118. Step 5 "Write a decision log entry at `decisions/<source>/<YYYYMMDD>_<topic>.md` ... when the canonical-shape choice is not self-evident" — decisions/README.md "When to add an entry", first trigger — pass
119. Step 5 "see `decisions/README.md` for the format" — decisions/README.md "## Format"; URL 200 — pass
120. Step 6 "Update tests ... — `test-crt_ingest.R` for a `file` entry, `test-crt_schema_conform.R` for a `schema_only` one — with, for a `file` entry, small synthetic fixtures at `inst/extdata/examples/<source>/<file_name>_<variant>.csv`" — bcfp fixtures match the pattern; fish_data fixtures exist and are synthetic (project `2024-000-example-...`); test-file placement noted above — pass

### _pkgdown.yml (1)

121. Article entry "How reading works" with contents `reading` — vignettes/reading.Rmd exists; README L51 links articles/reading.html (404 until deploy, expected) — pass

## Verdict

4 findings, all fragile, all from the mechanism above: two in README.md (L47, L55) and two in vignettes/reading.Rmd (L72, L81). No broken links. No unexported function is named as user-facing. The pasted output matches a fresh run. The vignette knits. No content the issue asked to keep was lost.
