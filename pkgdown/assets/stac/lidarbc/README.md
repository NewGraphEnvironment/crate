# LidarBC

- **Title:** LidarBC
- **Identifier:** <https://newgraphenvironment.github.io/crate/stac/lidarbc/v1.0.0/schema.json>
- **Field Name Prefix:** lidarbc
- **Scope:** Item, Collection
- **Owner:** New Graph Environment

Facts about where a file sits in [LidarBC](https://lidar.gov.bc.ca)'s objectstore and what its name says. LidarBC keys are `<block>/<sheet>/<year>/<product>/<file>`, and these fields record the parts a catalogue reads from them. Written by [stac-pointcloud-bc](https://github.com/NewGraphEnvironment/stac_pointcloud_bc); `lidarbc:delivery` is shared with [stac-elevation-bc](https://github.com/NewGraphEnvironment/stac_dem_bc).

- [JSON Schema](v1.0.0/schema.json)
- [Example item](examples/item.json), [example collection](examples/collection.json)
- [Changelog](CHANGELOG.md)

## Item properties

| Field | Type | Description |
|---|---|---|
| `lidarbc:product` | string | The product directory in the key. Values seen: `pointcloud`, `dsm`. Not an enumeration, because other LidarBC products may carry the prefix. |
| `lidarbc:delivery` | string | The delivery, `<block>/<sheet>/<year>` from the key, e.g. `082/082l/2019`. Pattern `^[0-9]{3}/[0-9]{3}[a-p]/[0-9]{4}$`. Joins a point cloud to the elevation rasters of the same delivery. |
| `lidarbc:datetime_source` | string | `filename` or `path`: whether the item's datetime fields came from the file name's date token or from the year directory. |
| `lidarbc:filename_date` | string | The file name's date token as written, present whenever the name has one, whether or not it was used. |

All fields are optional.

## Collection summaries

Each field may be summarised as a list of values.
