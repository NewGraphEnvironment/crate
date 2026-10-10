# LAS

- **Title:** LAS
- **Identifier:** <https://newgraphenvironment.github.io/crate/stac/las/v1.0.0/schema.json>
- **Field Name Prefix:** las
- **Scope:** Item, Asset, Collection
- **Owner:** New Graph Environment

Facts about a file in the ASPRS LAS format, read from its header: true of a `.las`, a `.laz` and a COPC file alike. The [pointcloud](https://github.com/stac-extensions/pointcloud) extension (v1.0.0) has no field for either. If one appears upstream, the catalogues move to it.

- [JSON Schema](v1.0.0/schema.json)
- [Example item](examples/item.json)
- [Changelog](CHANGELOG.md)

## Item properties and Asset fields

| Field | Type | Description |
|---|---|---|
| `las:version` | string | The LAS specification version in the header, `1.0` to `1.4`. |
| `las:point_format` | integer | The point data record format ID in the header, 0 to 10. |

On an Item they describe its source-of-record asset (in stac-pointcloud-bc, `laz`). An asset that is a different file, such as a COPC copy, carries its own, because a copy can be written at another version or format.

All fields are optional.

## Collection summaries

`las:version` as a list of values; `las:point_format` as a list or a `minimum`/`maximum` range.
