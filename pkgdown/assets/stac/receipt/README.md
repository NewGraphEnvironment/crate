# Receipt

- **Title:** Receipt
- **Identifier:** <https://newgraphenvironment.github.io/crate/stac/receipt/v1.0.0/schema.json>
- **Field Name Prefix:** receipt
- **Scope:** Item, Asset, Collection
- **Owner:** New Graph Environment

The identity fields of an output's provenance receipt ([crate#43](https://github.com/NewGraphEnvironment/crate/issues/43)) that no published STAC extension covers. The receipt itself, `receipt.json`, is published beside the item as an asset with role `metadata`; these fields mirror its identity into the item so a STAC client or a pgstac queryable can read it without fetching the receipt. A receipt field that has a standard STAC home uses it: a part's SHA-256 is `file:checksum` (multihash `1220…`), its size `file:size`, the producing software `processing:software`, and the build time `processing:datetime`. crate's receipt mapping table lists each pairing: [mapping v1.1.0](https://newgraphenvironment.github.io/crate/receipt/mapping/v1.1.0/mapping.csv), installed with crate as `inst/extdata/receipt/mapping/v1.1.0/mapping.csv` beside `stac.json`, the vectors every implementation of it runs. The receipt asset's `file:checksum` is the digest of the published receipt's bytes, and it carries no `file:size`. crate's `crt_receipt_stac()` builds these fields from a receipt.

- [JSON Schema](v1.0.0/schema.json)
- [Example item](examples/item.json)
- [Changelog](CHANGELOG.md)

## Item properties and Asset fields

| Field | Type | Description |
|---|---|---|
| `receipt:recipe_id` | string | The receipt's `recipe.recipe_id`: SHA-256, lowercase hex, over the RFC 8785 canonical JSON of how the output was made. Two items with the same value were made the same way. |

On an Item it is the recipe of the output the item describes. An asset that is a separate output with its own receipt carries its own.

A receipt read from an older record has no recipe identity (`recipe_id` null); an item built from one leaves the field out rather than publishing a null.

All fields are optional.

## Collection summaries

`receipt:recipe_id` as a list of values.
