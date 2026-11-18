# Decision: nuseds_all_areas canonical = the file's own columns, lower-cased, dates as written

**Date:** 2026-11-17
**Domain / source:** dfo
**File:** nuseds_all_areas

## Decision

The canonical shape for `dfo/nuseds_all_areas` is the NuSEDS All Areas file's own 51 columns, one row per
estimate (`act_id`; a population on one stream, `pop_id` and `gfe_id`, in one year), with the names in lower case.
Counts are `double`; the year and the inspections used are `integer`; the three ids and every date stay `string`,
as DFO wrote them.

## Trigger

knowledge needs one NuSEDS table for its salmon records per stream (NewGraphEnvironment/knowledge#108), and
every reporting repo reads its own copy. The file's columns already moved between releases (a 49-column
release without `FWA_WATERSHED_CDE` and `FULL_CU_IN`, then the 51-column `20260601`).

## Rationale

- **No reshaping.** The file is already long and keyed (`act_id`, and `pop_id` with `analysis_yr`), so a
  consumer's filters and joins are the file's own. Renaming beyond the case would make every reader learn
  a second vocabulary for DFO's.
- **Counts as double.** Filled count cells hold integers, decimals (`77.8333333333333`, an estimate) and
  scientific notation (`1e+05`). `integer` would truncate the decimals.
- **Ids as strings.** In the `20260601` release `act_id` reaches 2,146,955,744 and `gfe_id` 2,049,268,617, at
  the edge of a 32-bit integer (2,147,483,647). An `integer` id would read as `NA` the release after it passes.
- **One row per estimate, not per population and year.** A population can be counted on several streams in one
  year (pop 2178, chinook, on the Seton River and Portage Creek): 518 rows share a population, species and year,
  none a population, stream (`gfe_id`) and year.
- **Dates as strings.** Dates are `DD-MON-YY`. A two-digit year needs the row's `analysis_yr` to resolve,
  and the spawn and arrival dates are read by month and day more often than as instants, so the reader
  decides.
- **Encoding on the variant.** The `20260601` file is Latin-1 (`BARRIÈRE RIVER`, `FRANÇOIS LAKE`). A release
  could move to UTF-8, so the encoding belongs to the variant, not to the schema: `crt_ingest()` reads the
  header, picks the variant, then reads the file in the variant's encoding, and refuses bytes that are not
  UTF-8 where a variant declares none.
- **`fwa_watershed_cde` and `full_cu_in` not required**, so an earlier release conforms once a copy as
  received is registered.

## Alternatives considered

- **Registering the 49-column release now.** The copies we hold were renamed by our own scripts
  (`janitor::clean_names()`), so their column names are not the release's. A variant registered from them
  would describe a file nobody downloads.
- **Typing dates as `datetime`.** Rejected for the two-digit year (above).
