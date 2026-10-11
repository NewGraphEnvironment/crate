# STAC field schemas

JSON Schemas for the custom field prefixes that New Graph Environment's STAC catalogues write, one per prefix, in the shape of the [stac-extensions template](https://github.com/stac-extensions/template). An item that carries a prefix's fields lists that prefix's schema URL in `stac_extensions`, and STAC validators (pystac, stac-validator) fetch it from there.

| prefix | describes | schema |
|---|---|---|
| [`lidarbc`](lidarbc/README.md) | LidarBC's objectstore paths and file names | `https://newgraphenvironment.github.io/crate/stac/lidarbc/v1.0.0/schema.json` |
| [`las`](las/README.md) | a file in the ASPRS LAS format | `https://newgraphenvironment.github.io/crate/stac/las/v1.0.0/schema.json` |

## Rules

- **A field with a standard STAC home uses it.** A prefix here is for a field that no published extension covers, and its name says what the field describes, not who built the catalogue.
- **A prefix earns a schema here only when more than one catalogue writes it, or something outside NGE reads it.** Every schema is permanent and every field change is a new version, so provenance that only one catalogue writes goes in the standard fields instead (`processing:lineage`, `processing:software`, a `derived_from` link).
- **Catalogue builds validate against copies of the schemas in their own repo** (see "Validating offline" below), so a Pages or DNS outage cannot fail a build. The published URL is for readers outside the build.
- **A released version is never edited.** A change is a new version directory (`v1.1.0/schema.json`) beside the old one, and the old one stays, because items already published name it. The pkgdown workflow fails a build whose copy of a live version differs from what is served.
- **Add one version at a time, and point the examples at it.** The tests compile every version but validate the examples only against the newest, and the examples must name it. A version is frozen the moment it deploys.
- **Each schema's `$id` is its URL**, so a same-named extension published elsewhere cannot be mistaken for this one.
- **No field is required.** One prefix serves several catalogues that each write a subset; a catalogue's own build checks for the fields it always writes.

## Validating offline

pystac fetches each schema when it validates, so a test suite that calls `validate()` on items listing these URLs needs the network. Preload them instead:

```python
import json
from pystac.validation import JsonSchemaSTACValidator, set_validator
v = JsonSchemaSTACValidator()
v.schema_cache["https://newgraphenvironment.github.io/crate/stac/las/v1.0.0/schema.json"] = json.load(open("las_v1.0.0.json"))
set_validator(v)
```

The github.io URL answers with a 301 to the organisation's custom domain, which pystac and `requests` follow. `$id` stays the github.io URL, which keeps working if the custom domain is removed.

## Layout

```
<prefix>/
  README.md            field table
  CHANGELOG.md
  v<X.Y.Z>/schema.json published at https://newgraphenvironment.github.io/crate/stac/<prefix>/v<X.Y.Z>/schema.json
  examples/            validated against the schema by tests/testthat/test-stac_schemas.R
```

This directory is published by the pkgdown site (`pkgdown/assets/` is copied to the site root) and is not part of the R package.
