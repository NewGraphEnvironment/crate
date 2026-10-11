## Outcome

`lidarbc` v1.1.0 is published from `pkgdown/assets/stac/lidarbc/v1.1.0/schema.json`. It is v1.0.0 plus one optional boolean field, `lidarbc:datetime_unknown`, for stac-elevation-bc's albers items, whose LidarBC keys carry no date. v1.0.0 is byte-identical to `gh-pages`. The examples point at v1.1.0, and a new `item_undated.json` example is the published albers item with its flag renamed.

The schema change was mechanical. All the review findings were in the prose: four rounds each found one false factual claim in the docs, and the third sat inside the second's fix. Each came from the same mechanism: a claim about a class of items written from one member or one list. The worst case was `urls_list.txt`, which lists what LidarBC serves now, not what the catalogue publishes. The loop ended when every factual claim in the diff had been checked against the writer code and the populations.

## Measurement

- **Before v1.1.0:** the tests read FAIL 1 | PASS 129. The failure was the boolean summary.
- **After v1.1.0:** the tests read FAIL 0 | PASS 151. Deleting `"type": "boolean"` makes exactly the 3 new rows fail.
- **pystac 1.15.2:** the published albers item `albers10k2m-_completed_dem-dem_055_154`, with the field renamed, is INVALID when it names v1.0.0 and VALID when it names v1.1.0.
- **Items that need v1.1.0:** 2,288, not the 2,245 the issue first said. 2,245 are under `albers10k2m/_completed_dem/` in `urls_list.txt`, and 43 are under `albers10k2m_new/_completed_dem/` in `urls_deleted.txt`: their source was deleted upstream, but they are still published and still flagged.
- **Bucket listing:** 102,378 items, 2,288 of them dateless, all of them albers. That is 0 dateless items outside albers, counted with the writer's `date_extract_from_path`.

Closed by: PR for #26
