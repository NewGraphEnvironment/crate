## Enumeration after round 4 (terminal)

Mechanism: a claim about who adopts the receipt contract (stacs, STAC catalogues) checked against
crate's own copies of the claim rather than against stacs. Rounds 2-3 found `stacs.receipt`;
round 4 found the same claim one sentence over (README STAC section, vignette opening), inside
b31d6bf's fix.

Candidate set: every line in the changed files (README.md, vignettes/receipt.Rmd, CLAUDE.md repo
section) matching stacs|catalogu|python|every package/implementation|receipt:|implement, plus every
README line naming receipts. 11 candidates:

| where | claim | status |
|---|---|---|
| README:3 | tagline, crate's own job | holds |
| README:11 | definition of a receipt | holds (not adoption) |
| README:120 | Python implementation | fixed b31d6bf: planned, stacs#12 |
| README:166 | R function list | holds (NAMESPACE) |
| README:196 | `receipt:` STAC fields | fixed: adopted with receipts, stacs#12 |
| vignette:16 | every publisher writes receipts | fixed: "is to write" |
| vignette:22-25 | Python implementation | fixed b31d6bf: planned |
| vignette:150, 174 | Python json / format behaviour | holds (library facts) |
| vignette:288 | recipe_id goes on an item as receipt:recipe_id | holds (normative mapping) |
| vignette:293 | every implementation runs the vectors | holds (normative) |
| CLAUDE.md:25 | stacs runs the vectors | fixed b31d6bf: planned, stacs#12 |

Outside the changed files, left deliberately and noted in the PR: inst/extdata/receipt/vectors/v1.0.0/README.md:5
(frozen directory), NEWS.md:17 (released entry).
