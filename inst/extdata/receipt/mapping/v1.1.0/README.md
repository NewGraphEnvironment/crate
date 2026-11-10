# Receipt mapping, v1.1.0

How an older provenance record's fields become a receipt's, and how a receipt's fields become a STAC
item's ([crate#43](https://github.com/NewGraphEnvironment/crate/issues/43), versioned in
[crate#58](https://github.com/NewGraphEnvironment/crate/issues/58); the STAC rows executed and
pinned in [crate#59](https://github.com/NewGraphEnvironment/crate/issues/59) and
[crate#60](https://github.com/NewGraphEnvironment/crate/issues/60)).

| file | what it is |
|---|---|
| `mapping.csv` | `source_format`, `source_field`, `receipt_key`, `transform`, `stac_key`, `note`: one row per field of each older format, and the `STAC item` rows |
| `stac.json` | the vectors for the `STAC item` rows: each case is a receipt and the item fields it maps to, or a refusal |

`mapping.csv` is published at
`https://newgraphenvironment.github.io/crate/receipt/mapping/v1.1.0/mapping.csv`.

**`stac.json`**: each case is `{name, receipt, assets, receipt_asset, receipt_sha256, expected,
error}`.

- `assets` maps an asset key to its href relative to the item, which is the path a part is keyed by.
- `receipt_asset` and `receipt_sha256` are the key of the asset that links the receipt and the
  SHA-256 of the published receipt's bytes, or `null`.
- Where `error` is `null`, the item fields are `expected`: `stac_extensions` (an array, in order),
  `properties` and `assets`. Compare `properties` and `assets` as canonical JSON (RFC 8785), so
  member order does not matter.
- Where `error` is a code, the implementation must refuse the case, and `expected` is `null`.
  Messages differ between implementations, so a runner checks only that the case is refused. The
  code says what is refused: `href_not_a_part`, `receipt_asset_without_digest`,
  `digest_without_receipt_asset`, `receipt_asset_in_assets`, `digest_not_sha256`.

Every receipt in the cases is valid against receipt form v1.0.0, with a `recipe_id` that matches its
recipe, so only the mapping decides each case. Read its numbers as the hashing vectors in
`inst/extdata/receipt/vectors/v1.0.0/` describe.

The rows that differ from v1.0.0 are listed in the changelog at
`https://newgraphenvironment.github.io/crate/receipt/CHANGELOG.md`. A released version is never
edited: a row change, or a code change that moves a value in `stac.json`, is a new version
directory beside this one. `data-raw/receipt_vectors.R` in crate's repository writes `stac.json`.
