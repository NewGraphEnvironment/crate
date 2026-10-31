# Plan review — #13 (Plan agent, spawned 2026-10-31T02:36Z, returned after Phase 1 landed)

Written by the parent from the agent's reply (Plan agents cannot write). Verdicts after probing.

| # | Cat | Finding | Probe / verdict |
|---|-----|---------|-----------------|
| 1 | Gap | pscis fixture's expected value computed by crate only; tie fixture to the measured live set via `serializeVersion = 2` digest = `99-36743b027ac0c93f` | Accept: cheap, proves the fixture is the live column set |
| 2 | Gap | Phase 4 fingerprints otherwise untested strings; need fixtures for every listed variant incl. 122 vintage (names/types only, no project name) | Accept |
| 3 | Assumption | `enc2utf8()` names before hashing | Accept |
| 4 | Assumption | trap's already-harvested tables carry serialized values and will warn until re-harvested | Accept: say so in decision + trap issue |
| 5 | Blocker | fiss_site declares 7 `real` valuemap columns with text vocabularies; conform would coerce them to NA silently | **Confirmed** (method_for_temperature, utm_method, method_for_channel_width, method_for_gradient, method_for_residual_pool_depth, method_for_bankfull_depth, method_for_p_h). User: canonical `string`, file rfp issue |
| 6 | Gap | units by trailing parens: 12 of 23 wrong; use allow-list + name-suffix fallback | Accept; re-measure in Phase 3 |
| 7 | Gap | monitoring QML: no aliases, coded valuemaps, int32 sentinel ranges, photo root `@project_folder + '/photos'`, `date_time_start` never filled | Accept; verify in Phase 3 |
| 8 | Gap | `<NULL>` sentinel option, empty options, unquoted Yes/No -> TRUE | Accept: integrity test that `values` are character |
| 9 | Acceptance | Phase 5: unknown-fingerprint on a registered form; QC flag test (near-miss, label-for-code) | Accept |
| 10 | Acceptance | trap's `trp_form_stack()` aborts on non-nested vintages | Add to trap follow-up issue |
| 11 | Acceptance | grade "envelope" undefined (source_version may be NA) | Accept: harvestable = project, form, record_id, x, y non-NA |
| 12 | Gap | `form_pscis_newgraph` has no schema under the flat key | Accept: document that the `form` value maps to the base schema by the reader; note in trap issue |
| 13 | Blocker | rfp is PRIVATE, crate PUBLIC: derived help text republishes private content (a person's name, internal link, citation keys) | **Visibility confirmed; content claim wrong.** `moti_chris_culvert_id` = MoTI's CHRIS system, not a person; links are public gov.bc.ca PDFs; `*citation_key*` are column names with no keys. Nothing to scrub; meaning published as the issue intends (user asked, 2026-10-30, answered) |
| 14 | Scope | derive script is a one-off bootstrap once rfp#24 lands | Accept: say so in script header + decision |
| 15 | Acceptance | `_pkgdown.yml` has no reference section | No change: none needed |
| 16 | Acceptance | `crt_schema_validate.R` names reserved `cols[].enum`; rename to `values` | Accept |
| 17 | Ordering | land "values character / on string cols" integrity tests before Phase 3 | Accept (Phase 2) |
| — | Wording | gate decision 2 / Phase 1 box still say "byte-identical to trap's" | Accept |
