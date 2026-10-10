## Outcome

crate now publishes STAC extension JSON Schemas for the custom field prefixes NGE's catalogues write, starting with `lidarbc` v1.0.0 and `las` v1.0.0. They live in `pkgdown/assets/stac/<prefix>/v<X.Y.Z>/schema.json` and are served at `https://newgraphenvironment.github.io/crate/stac/...`. The URL 301-redirects to the organisation's custom domain, and pystac follows it.

The design question turned out to be the freeze rather than the schemas. A version on `gh-pages` is permanent, so the pkgdown job does three things:
- runs the schema tests before building;
- compares every built version byte for byte against `gh-pages`, and fails on an edit or a deletion;
- deploys only from `main`.

Three code-check rounds found one mechanism along five axes: the guard freezes by one rule and the tests check by another. The axes were file name, git ref twice (a dispatched run, then a release), prefix and version. It ended on an enumeration of those axes (`findings.md`), not on a quiet round.

Two consumer facts came out of the work:
- ajv applies keywords beside a `$ref` and pystac's jsonschema ignores them, so every `$ref` stands alone.
- pystac validates only against the extensions an object lists.

Issue #23 stays open for the sibling prefixes (airphoto, floodplains, uav).

## Measurement

- Tests: 120 in `test-stac_schemas.R` (355 in the suite). Each constraint and each guard was removed in a scratch copy and turned the tests red (mutation tables in `findings.md`).
- Consumer interop, pystac 1.15.2 with the schemas preloaded:
  - the examples validate against core STAC 1.1.0 and all five extensions;
  - all 16 value-level negative cases are rejected;
  - round 2's reviewer validated all 9,650 built stac_pointcloud_bc files (items and collection) under Python jsonschema with the two URLs added.
- Publishing guard: 8 published states, all with the expected exit (`findings.md`). On the way, a bad ref was found to pass the guard, because `|| true` swallowed the `git ls-tree` failure. It now fails closed.
- `R CMD check`: 0 errors, 0 warnings. The 2 NOTEs are about `CITATION.cff` and predate this work.

Closed by: PR (see branch `23-stac-field-schemas-for-the-catalogues-cu`)
