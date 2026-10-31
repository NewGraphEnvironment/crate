## Outcome

Registered canonical schemas for the five fish passage field forms (`nge/form_pscis`,
`form_fiss_site`, `form_monitoring_fish_passage`, `form_monitoring_general`, `form_monitoring`),
derived from rfp's field CSVs (and `form_monitoring`'s QML) by `data-raw/forms_derive-schemas.R`
at a pinned rfp SHA. Each declares the `form_capture` envelope plus position as required and every
form column optional, with units, allowed values (labels for coded vocabularies), ranges,
photo-path roots and off-form nulls; grades (`harvestable`, and `crew_attributed` on monitoring);
and known versions as fingerprinted `upstream_variants`. New exports: `crt_schema_fingerprint()`,
`crt_schema_cols()`, `crt_schema_grade()`, `crt_schema_variant()`; `crt_schema_conform()` warns
(`crate_unknown_fingerprint`) on an unlisted fingerprint. Learned: trap's fingerprint hashed R's
serialization rather than the string (user chose the plain string mid-run), monitoring's two field
shapes rename rather than nest, rfp declares seven text dropdowns `real` (user: canonical
`string`), and `crt_schema_read()` silently truncated non-ASCII schemas under a C locale
(pre-existing, fixed). The plan review's "help text names a person" claim was wrong (CHRIS is
MoTI's system). Decision: `decisions/nge/20261030_form_schemas_fish_passage.md`.

## Measurement

- Fingerprints, measured 2026-10-30 over the four fish passage projects' live forms: every 2026
  capture of pscis, fiss_site, monitoring_fish_passage and monitoring_general equals rfp's build;
  form_monitoring has a second 122-column shape (2025) against the build's 124, not a subset.
  2023–2025 local files showed ~15 more pscis and ~10 fiss_site column sets, many of them
  processed copies, so deferred to crate#36.
- Serialized vs plain-string XXH64 on rfp's form_pscis: `36743b027ac0c93f` vs `c084e87fbf17e20e`;
  plain matches published XXH64 vectors. Changed what crate defines.
- Units from trailing label parentheses: 12 of 23 were scales or examples, not units; moved the
  derive to an allow-list plus name-suffix patterns (`_m_s_cm` is mS/cm, not cm).
- Same unmarked UTF-8 name: `1-dae53876043f69f5` (en_US.UTF-8) vs `1-aa9633b74f361115` (C)
  before the round-2 fix; one value after.
- bcfp schema read under `LC_ALL=C`: 1 of 2 upstream variants and 4 of 7 top-level keys before
  the read fix; identical to the UTF-8 read after.
- Code-check: 3 rounds plus 1 plan review. Round 2 found a defect inside round 1's fix, so the loop
  ended by enumeration (27 "no value" representations, every text-to-bytes point; findings.md).
  Mutation table: 9 guards, each fails with its defect restored.

## Owed

- trap switches to `crate::crt_schema_fingerprint()` (trap follow-up issue)
- rfp's builder reads meaning via `crt_schema_cols()` (rfp's work, unblocked by this PR)

Closed by: PR (opened next)
