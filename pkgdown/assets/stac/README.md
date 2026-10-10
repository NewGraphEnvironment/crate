# STAC field schemas

JSON Schemas for the custom field prefixes that New Graph Environment's STAC catalogues write, one per prefix, in the shape of the [stac-extensions template](https://github.com/stac-extensions/template). An item that carries a prefix's fields lists that prefix's schema URL in `stac_extensions`, and STAC validators (pystac, stac-validator) fetch it from there.

| prefix | describes | schema |
|---|---|---|
| [`lidarbc`](lidarbc/README.md) | LidarBC's objectstore paths and file names | `https://newgraphenvironment.github.io/crate/stac/lidarbc/v1.0.0/schema.json` |
| [`las`](las/README.md) | a file in the ASPRS LAS format | `https://newgraphenvironment.github.io/crate/stac/las/v1.0.0/schema.json` |

## Rules

- **A field with a standard STAC home uses it.** A prefix here is for a field that no published extension covers, and its name says what the field describes, not who built the catalogue.
- **A released version is never edited.** A change is a new version directory (`v1.1.0/schema.json`) beside the old one, and the old one stays, because items already published name it. The pkgdown workflow fails a build whose copy of a live version differs from what is served.
- **Each schema's `$id` is its URL**, so a same-named extension published elsewhere cannot be mistaken for this one.
- **No field is required.** One prefix serves several catalogues that each write a subset; a catalogue's own build checks for the fields it always writes.

## Layout

```
<prefix>/
  README.md            field table
  CHANGELOG.md
  v<X.Y.Z>/schema.json published at https://newgraphenvironment.github.io/crate/stac/<prefix>/v<X.Y.Z>/schema.json
  examples/            validated against the schema by tests/testthat/test-stac_schemas.R
```

This directory is published by the pkgdown site (`pkgdown/assets/` is copied to the site root) and is not part of the R package.
