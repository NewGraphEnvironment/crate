# LidarBC

- **Title:** LidarBC
- **Identifier:** <https://newgraphenvironment.github.io/crate/stac/lidarbc/v1.1.0/schema.json>
- **Field Name Prefix:** lidarbc
- **Scope:** Item, Collection
- **Owner:** New Graph Environment

Facts about where a file sits in [LidarBC](https://lidar.gov.bc.ca)'s objectstore and what its name says. LidarBC keys are mostly `<block>/<sheet>/<year>/<product>/<file>`, and these fields record the parts a catalogue reads from them. Some carry no date at all (the `albers10k2m/_completed_dem/` tiles), which is what `lidarbc:datetime_unknown` records. Written by [stac-pointcloud-bc](https://github.com/NewGraphEnvironment/stac_pointcloud_bc); `lidarbc:delivery` is shared with [stac-elevation-bc](https://github.com/NewGraphEnvironment/stac_dem_bc), which alone writes `lidarbc:datetime_unknown`.

- [JSON Schema](v1.1.0/schema.json); [v1.0.0](v1.0.0/schema.json) stays published for items that name it
- [Example item](examples/item.json), [undated example item](examples/item_undated.json), [example collection](examples/collection.json)
- [Changelog](CHANGELOG.md)

## Item properties

| Field | Type | Description |
|---|---|---|
| `lidarbc:product` | string | The product directory in the key. Values seen: `pointcloud`, `dsm`. Not an enumeration, because other LidarBC products may carry the prefix. |
| `lidarbc:delivery` | string | The delivery, `<block>/<sheet>/<year>` from the key, e.g. `082/082l/2019`. Pattern `^[0-9]{3}/[0-9]{3}[a-p]/[0-9]{4}$`. Joins a point cloud to the elevation rasters of the same delivery. |
| `lidarbc:datetime_source` | string | `filename` or `path`: whether the item's datetime fields came from the file name's date token or from the year directory. |
| `lidarbc:filename_date` | string | The file name's date token as written, present whenever the name has one, whether or not it was used. |
| `lidarbc:datetime_unknown` | boolean | `true` when neither the file name nor the path carries a date, so the item's `datetime` is a placeholder (stac-elevation-bc writes `2000-01-01T00:00:00Z`). Absent otherwise. Since v1.1.0. |

All fields are optional. They belong in item properties; the schema does not check assets.

## Collection summaries

Each field may be summarised as a list of values.
