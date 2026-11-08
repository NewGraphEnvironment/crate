## Outcome

README.md (also the pkgdown home page) now says crate does two jobs: canonical schemas for changing inputs, and provenance receipts for outputs. The tagline and intro name both. A `## Provenance receipts` section shows a `crt_receipt_write()` and the worked-case `crt_receipt_compare()`, with output pasted from a real run and checked line by line, verbatim, by script. `## Naming convention` and `## STAC field schemas` have their own sections, so "What crate handles today" describes registered schemas only. The receipt vignette says a `Date`/`POSIXct` subclass (data.table's `IDate`) is spelled as its base class (#49 follow-on). Learned in review: the docs said stacs already implemented receipts and that catalogues wrote `receipt:` fields. Both were copied from crate's own docs and never checked against stacs, where [stacs#12](https://github.com/NewGraphEnvironment/stacs/issues/12) is still open. They now say "planned". The README's repo-relative links all 404ed on the pkgdown site, which publishes none of those files, so they are absolute GitHub URLs now. `pkgdown::build_home()` drops an untracked `pkgdown/favicon/` into the tree even with a temp destination.

## Measurement

- 7 pasted output lines (one `recipe_id`, five-line compare) found verbatim in README.md by script after a fresh `devtools::load_all()` run
- 13 repo-relative links were 404 on the live site (the 4 sampled all 404); after the rewrite, all 13 return 200 on GitHub
- Vignette render and home-page build: 0 warnings; 1973 tests pass, 0 failed
- /code-check: 4 rounds, 5 findings (one found twice), all fixed; ended by an 11-candidate enumeration (`review-enumeration.md`)

## Owed

- `inst/extdata/receipt/vectors/v1.0.0/README.md:5` and `NEWS.md:17` still name a stacs implementation as existing: the first is in a frozen directory, the second a released entry; left deliberately

Closed by: PR for #52
