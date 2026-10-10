# Plan review (Plan agent, 2026-10-10) — findings and disposition

Spawned at baseline, returned after Phases 1-3 had landed; read against the real code.

| id | finding | disposition |
|---|---|---|
| B1 | `newgraphenvironment.github.io/crate/...` answers 301 to `www.newgraphenvironment.com/crate/...` (org custom domain) | **Confirmed** (`curl -sIL`: 301 → 200 `application/json`, `max-age=600`). pystac follows it. `$id` kept as github.io (the gate's decision; survives CNAME removal). Dependency recorded in the decision entry and stac/README. The guard never fetched the live URL, so unaffected. |
| B2 | `$schema` must be exactly `http://json-schema.org/draft-07/schema#` | Already so; the test asserts the exact string. |
| A1 | crate has no test CI | **Fixed**: "Test the STAC schemas" step in pkgdown.yaml before the build; jsonvalidate absence is an error. Clean exit 0, mutated exit 1. |
| A2 | ajv applies `$ref` siblings, Python jsonschema ignores them | **Fixed**: test requires every `$ref` object to have no other keys (proven to fire with a harmless sibling). Negatives also run through pystac: all 16 value cases rejected. |
| A3 | template-shape Collection `anyOf` lets a bogus summary pass | Not applicable: our Collection branch points `summaries` at its own definition with `additionalProperties: false`. Negative added (`lidarbc:bogus` summary) and rejected by ajv and pystac. |
| A4/G1 | no Collection example/negatives | Example existed; negatives added (enum, bogus key, not a list, URL missing). |
| A6 | jsonvalidate → V8 now on the deploy path | Accepted; stated in the decision entry. |
| G2 | live-URL guard cannot see a deletion; 404 fails toward pass | Already fixed in Phase 3 (gh-pages comparison). |
| G3 | CDN `max-age=600` after deploy | Post-merge live check retries; noted for the #2 hand-off. |
| G4 | skip-vs-vacuous tension | Source tree detected by `_pkgdown.yml`, then `expect_gt` with no skip; R CMD check shows 4 skips, tarball has no pkgdown/. |
| G5 | unversioned examples break once v1.1.0 exists | **Fixed**: each example is checked against the version its `stac_extensions` names. |
| G6 | one source for the URL base | Test derives from `_pkgdown.yml`; guard is path-based. |
| G7 | consumer tests become network-dependent | stac/README documents preloading `schema_cache`. |
| G8 | lidarbc on assets unchecked | Stated in lidarbc/README. |
| S1 | `las:version` wider than the issue | Restated in the #23 body edit. |
| — | "URL missing" cases pass in pystac | By construction: pystac applies only listed schemas. The `contains` const guards validators that apply the schema directly. |
