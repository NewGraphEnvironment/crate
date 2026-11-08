## Outcome

The README went from 201 lines of tutorial, inventory and unbuilt work to 80 lines in soul's `readme.md` order: lifecycle badge, an opening covering both jobs (canonical schemas, provenance receipts), install with a pin line, one ingest and one compare example with fresh-run output, Learn more, Ecosystem (soul#416's nine rows plus crate, published-site links), Citation and License. The runtime, datetime and variant-matching material moved to a new `vignettes/reading.Rmd`, whose `crt_files()` and fixture chunks run live so they cannot go stale. The naming convention merged into CLAUDE.md with the reserved names dropped. "Adding a pair" folded into `inst/extdata/schemas/README.md`. Type-aware variant matching became crate#55 instead of a "planned" line. The DESCRIPTION Title now names receipts, and the Description matches the opening. What was learned: every false claim the three `/code-check` rounds found came from one mechanism. A plain word (source, kind, tolerance, verdict, handler) was used where the code gives it a narrower set. A rewording of old README text also dropped the qualifier the original carried, and round 3 found it reintroduced a STAC claim crate#52 had removed. Only an enumeration of every changed claim (121) ended the loop.

## Measurement

- README: 201 → 80 lines.
- `/code-check branch`: round 1 found 3 false claims, round 2 found 2 (one inside round 1's fix), and round 3's enumeration found 4 of 121 claims false. All 9 were fixed.
- `devtools::check()`: 0 errors, 0 warnings, 0 notes. The README example's output matched a fresh run byte for byte in every round.

## Owed

- `gh repo edit NewGraphEnvironment/crate --description "<tagline>"` after the merge, so About changes when main's README does. Read it back with `gh api repos/NewGraphEnvironment/crate --jq .description`.

Closed by: PR (opened by /gh-pr-push) for #54
