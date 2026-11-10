# Plan review: #59/#60 (Plan agent, spawned 2026-11-10T16:04Z, delivered during Phase 4)

Written to file by the parent session; the Plan agent has no Write tool.

## Blocker
1. Validate-first contradicts the committed tests (null/NA `version` cases) and Decision 2: the
   schema requires `version`, and validation recomputes `recipe_id`. **Resolved in Phase 3:
   validate-first dropped (see findings).**
2. Validate-first makes jsonvalidate (Suggests) a runtime need; stacs does not validate. **Resolved,
   same.**

## Gap
3. `stac.json` format under-specified: `error` must be neutral (runners check "raises" only);
   `write_vectors()` uses `auto_unbox = TRUE`, so a named character `assets` loses its names (pass
   `as.list()`); a one-URL `stac_extensions` unboxes unless `I()`; empty `assets` must be `{}`; say
   whether a missing `receipt_asset` is `null` or absent; argument-shape cases stay in testthat.
4. Stale mentions of mapping v1.0.0: `R/crt_receipt_migrate.R:5-6` (+ Rd), `vignettes/receipt.Rmd:290`,
   `pkgdown/assets/stac/receipt/README.md:9`, `research/provenance_receipt.md:191,238`.
5. CHANGELOG rules: code moving a `stac.json` value is a new mapping version; "what a migrated
   receipt holds" should include what an item holds; the parts table's "carried by: nothing yet";
   the heading must match the regex at `test-crt_receipt_schema.R:111`.
6. The crosscheck script always loads the hashing files; it needs to pick by what is present or a mode.
7. Stale comments at `R/crt_receipt_compare.R:157,356` ("from crt_receipt_write()" holds NA).
8. The new `assets.{receipt}` row overlaps the `assets.*` wildcard; one note should exclude it.

## Ordering
9. mapping.csv in both places, then the version bump, then generate `stac.json`, then the pins.

## Checked, no problem
Empty `receipt_key` is harmless to the migrator; freeze guards only check tag-held dirs; every crate
caller of the write return is moved.

## Assumption
10. Hand-edited vector receipts must keep a correct `recipe_id`.
11. stacs does not type-check `version`; add it to the divergence list.

## Acceptance (missing)
12. Check the merged item against the published field schema (the `test-stac_schemas.R` pattern).
13. Check `stac.json` round-trips to byte-identical canonical JSON.
