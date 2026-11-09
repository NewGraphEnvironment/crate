# Plan review (#58), Plan agent, spawned 2026-11-09T18:59Z, delivered after Phase 3

Findings as delivered, with the verdict on each after a probe.

| # | finding | verdict |
|---|---|---|
| 1 | Blocker: test-crt_receipt_schema.R calls internal `receipt_register_version()` bare; the pkgdown step runs `testthat::test_file()` without attaching crate | **Reproduced** (installed branch, ran as the workflow does: the published-copy test fails). Fix: `crate:::` |
| 2 | README.md:110 pasted `print()` output and :120 contract list | Confirmed. PR #56 (#54) rewrites README and keeps the same output line (its :40); owed in both |
| 3 | `overrides` names fields only, so a verdict cannot be reproduced | Accepted: named character, field = declared action |
| 4 | Hard-coded v1.0.0 in data-raw and tests | Accepted for data-raw (would regenerate into a frozen dir) and tests |
| 5 | Nothing checks the current register covers the current form | Accepted: changelog test |
| 6 | R-CMD-check expected-skip comment says six | Confirmed: now nine (stac 5, receipt schema 3, registry 1) |
| 7 | research doc and vignette still name old paths | Confirmed; Phase 4 |
| 8 | No NEWS entry | Declined here: `/gh-pr-merge` writes NEWS at release |
| 9 | Gate proof cannot run against real gh-pages | Already done with a constructed published ref (findings.md) |
| 10 | Algorithm changes leave versions unmoved | Accepted: CHANGELOG rule |
| 11 | vectors/v1.0.0 is declared frozen and its README edited | Accepted as a recorded one-time exception (hashing vector bytes unchanged); vignette "planned" stacs claim fixed |
| 12 | stacs issue contents | Folded into Phase 5 |
| 13 | crosscheck step unnecessary | Already noted |
| 15 | vignette broken until Phase 4 | Fixed before first push |
| 17d | data-raw line over 120 chars | Confirmed (123); fixed |
