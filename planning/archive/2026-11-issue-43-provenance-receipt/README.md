## Outcome

crate now holds the provenance receipt (crate#43): one `receipt.json` per output, with `output`,
`recipe`, `result` and `context` blocks, and a comparison that answers identical, equivalent within
a declared tolerance, or different, naming each field. The contract other languages implement is
the receipt schema v1.0.0 (installed, and published from `pkgdown/assets/receipt/`), SHA-256 over
RFC 8785 canonical JSON for `recipe_id`, a table fingerprint over the JCS of
`{"columns", "rows"}`, and test vectors in `inst/extdata/receipt/vectors/v1.0.0/`. The R side is
`crt_receipt_write/read/validate/keys/compare/migrate` and `crt_table_fingerprint`, a per-field
register, a mapping table, and a `receipt:` STAC field schema. Design and decisions:
[`research/provenance_receipt.md`](../../../research/provenance_receipt.md); reference:
`vignette("receipt")`.

What was learned: a byte-for-byte contract is mostly about what R does quietly. R's own decimal
parser is not correctly rounded on arm64; printf's rounding is not ECMAScript's shortest spelling
at powers of two; `format("%Y")` pads years differently on Linux and macOS; and every R class
that reaches a serializer through its methods (octmode, `ts`, units, factor names, integer64)
loses meaning. The serializer now accepts a whitelist and refuses the rest. Two schema fields were
added during the work, while v1.0.0 was unpublished: `parts.<path>.table` (so a file whose
bytes moved is equivalent only when its table agrees) and `context.legacy` (so a migrated record
drops nothing).

## Measurement

- R's `as.numeric()` misread 167,261 of 199,915 random 17-digit spellings (84%) on arm64 macOS;
  `jsonlite::parse_json()` misread none. The number spelling reads back through jsonlite.
- R's JCS numbers against Python `rfc8785` 0.1.4: 0 mismatches on 199,915 random doubles at
  first; code-check round 2 then found 46 of the 2,098 powers of two spelled with 17 digits where
  Python and Node write 16 (2^-24). After the fix, 0 of 2,098 and 0 of 199,915; `numbers.json`
  carries every power of two (2,637 cases). 6.5 s per 200k arbitrary doubles.
- The Python cross-check (`data-raw/receipt_vectors_crosscheck.py`, its own table canonical form)
  reproduces every numbers, jcs, recipe_id and fingerprint vector: 0 mismatches.
- The worked case (knowledge#145, synthetic): two builds, one `recipe_id`; `access_check` differs
  by up to 9.5e-11 km and compares `equivalent` under a 1e-9 tolerance, `different` without it.
- The gh-pages freeze guard, run from the workflow in a scratch repo: passes unchanged; fails on an
  edited, removed or bad-ref receipt schema.
- `/code-check branch`: 3 rounds (6, 7, 9 findings; rounds 2 and 3 found defects inside earlier
  fixes), ended by re-running round 3's enumeration of 37 value shapes, 14 representation
  meetings and 15 identity inputs. `R CMD check`: 0 errors, 0 warnings, 0 notes.

## Owed

- After the deploy, check that the receipt and `receipt:` STAC schema URLs serve (curl returns 200 and the `$id` matches)
- Tell stacs#12 the crate tag carrying vectors v1.0.0, so it can pin it
- soul `conventions/provenance.md` rule 4: point at the published vignette and drop the detail it now holds (the rule says to once the vignette exists)

Closed by: PR from branch `43-a-shared-provenance-receipt-a-language-n`
