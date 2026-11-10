# Progress — The STAC mapping has no implementation and no vectors (#59), with #60

## Session 2026-11-10

- Plan-mode exploration; phases approved by the user, with the `crt_receipt_write()` return decided
  at the gate (it returns the digest)
- Created branch `59-the-stac-mapping-has-no-implementation-a` off origin/main (857418b; two
  housekeeping commits landed during the gate, nothing receipt-related)
- Scaffolded PWF baseline from issues #59 and #60 with the approved phases
- Next: start Phase 1
- Phase 1: tests first. `test-crt_receipt_stac.R` (7 blocks, all erroring: no function yet); the
  write tests read the receipt back from the file and pin the returned digest (fails as expected);
  compare tests that exercised the in-memory receipt now build it with `receipt_build()`
- Phase 2: `crt_receipt_write()` returns the SHA-256 of the bytes it wrote (hashed from the temp
  file before the rename), invisibly. Callers moved: the vignette, `data-raw/receipt_examples.R`,
  the roxygen example. `crt_receipt_migrate(path =)` still returns the receipt (not in scope)
- Phase 3: `crt_receipt_stac()` in `R/crt_receipt_stac.R`; all 40 expectations of
  `test-crt_receipt_stac.R` pass; example runs; `check_pkgdown()` clean. **Plan correction:** it does
  not call `crt_receipt_validate()` first, because that needs jsonvalidate (Suggests, pulls V8), and
  a catalogue builder should not need it. It checks each field it publishes instead, as stacs does
