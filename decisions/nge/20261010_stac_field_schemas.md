# STAC field schemas are published by crate's site, one immutable file per version

**Date:** 2026-10-10
**Schemas:** `pkgdown/assets/stac/lidarbc/v1.0.0/schema.json`, `pkgdown/assets/stac/las/v1.0.0/schema.json`

## Decision

Each custom field prefix an NGE STAC catalogue writes gets a JSON Schema in the
shape of the stac-extensions template, published at

    https://newgraphenvironment.github.io/crate/stac/<prefix>/v<X.Y.Z>/schema.json

from `pkgdown/assets/stac/<prefix>/v<X.Y.Z>/schema.json`. Every released version
is its own committed file, and a change is a new directory beside it. The schema's
`$id` is that URL.

No field is required. `las:version` accepts every LAS version, `1.0` to `1.4`.

## Trigger

NewGraphEnvironment/stac_pointcloud_bc#12 renamed that catalogue's `nge:` fields to
`lidarbc:` and `las:`, and decided that each custom prefix is documented in crate.
Its full rebuild (NewGraphEnvironment/stac_pointcloud_bc#2) re-registers every item
and must not publish them without a schema URL in `stac_extensions`.

## Rationale

- **pystac fetches every URL in `stac_extensions` when it validates**, so the URL is
  a runtime dependency of every catalogue build, and published items name it for
  as long as they exist. Whatever answers there must never change. Committing each
  version as its own file makes "never edited" a property of the tree, and the
  pkgdown workflow's guard compares every built version against the `gh-pages`
  branch, failing on an edit or a deletion. The deploy runs with `clean: true`, so
  a version removed from the repo would otherwise be unpublished on the next push.
- **The pkgdown site was already deploying**, and `pkgdown/assets/` is copied
  recursively to its root (pkgdown 2.2.0 `copy_assets()`), so no new
  infrastructure was needed.
- **The URL redirects.** The organisation site's custom domain makes every
  github.io project path answer `301` to `https://www.newgraphenvironment.com/crate/...`,
  which serves the file as `application/json` with `max-age=600`. pystac and
  `requests` follow it. `$id` stays the github.io URL, which keeps resolving if the
  custom domain is ever removed. What it depends on is that the custom domain, while
  set, is served by GitHub Pages.
- **No required fields**, because one prefix serves several catalogues that write
  different subsets. stac-elevation-bc will carry only `lidarbc:delivery`
  (NewGraphEnvironment/stac_dem_bc#55); requiring `lidarbc:product` would reject
  its items. Each catalogue's own build checks for the fields it always writes.
- **`las:version` takes all five spec versions**, not the two LidarBC has shown
  (`1.2`, `1.4`). The prefix describes the LAS format, not LidarBC; a narrower enum
  would fail a future `1.3` file on a fact that is true of it.
- **Typos are rejected.** Within its own prefix each schema allows only its
  declared fields (`additionalProperties: false` beside `^(?!<prefix>:)`), so
  `lidarbc:filenam_date` fails validation rather than publishing.

- **Few prefixes, on purpose** (added 2026-10-10, after the first release). A
  prefix earns a schema only when more than one catalogue writes it, or something
  outside NGE reads it. Each schema is permanent, and each field change means a new
  version plus a rebuild of every catalogue that uses it. Five or more new prefixes
  for single-catalogue provenance would be a growing set of frozen files, not an
  inventory. Standard fields (`processing:*`, `derived_from`) take that provenance
  instead. Catalogue builds also validate against copies of the schemas in their own
  repo, so the published URL is a dependency for outside readers only, not for every
  build.

## Alternatives considered

- **A tagged `raw.githubusercontent.com` URL.** It couples a schema version to a
  package release tag, is served as `text/plain`, and is rate-limited.
- **One `json-schema/schema.json` per prefix, copied to a versioned path at build
  time** (the template's own layout). An in-place edit would silently replace the
  published version on the next deploy.
- **Fetching the live URL in CI to check immutability.** A Pages outage returns
  404, which the check has to read as "new version", so the guard fails toward
  pass, and it cannot see a deletion.

## Consequences

- A catalogue lists the URL in `stac_extensions` for each prefix whose fields it
  writes. NewGraphEnvironment/stac_pointcloud_bc#2 is unblocked once this deploys.
- A new prefix (stac_airphoto_bc#47, stac_floodplains_bc#74, stac_uav_bc#38) is a
  new directory with the same layout. crate#23 stays open for them.
- The schema tests run in the pkgdown job, before the build (crate has no test
  workflow), so `jsonvalidate` and V8 are now on the deploy path. A failed V8
  install stops site deploys, schema publication included.
- Python `jsonschema` (pystac) ignores keywords beside a `$ref` in draft-07 and
  ajv (the R tests) applies them, so the tests require every `$ref` to stand alone.
- A field added to an existing prefix is a new version (`v1.1.0`), and the
  catalogues move to it at their next rebuild.

## References

- `pkgdown/assets/stac/README.md` — layout and rules
- `tests/testthat/test-stac_schemas.R` — `$id` and URL agreement, examples, negative cases
- `.github/workflows/pkgdown.yaml` — "Check the STAC schemas against what is published"
- [stac-extensions template](https://github.com/stac-extensions/template)
