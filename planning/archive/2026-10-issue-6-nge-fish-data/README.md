## Outcome

`nge/fish_data` is crate's first NGE `file` entry: `crt_ingest("nge", "fish_data", path)` reads the 2023 individual fish files (two shapes) and the 2024+ field sheet to the same 29 columns and types, named after the provincial FISS template and the field form (`species`, `length_mm`, `weight_g`, `haul_number_pass_number`). The issue had framed 2023 as a rename. Reading the files showed it is a different file: no date, project, effort or tag columns, with PIT tags written into free-text `comments`. The handler reads those tags out, keeps `comments` verbatim, and aborts on a column its rename leaves unmapped. Decision: `decisions/nge/20261031_fish_data_canonical.md`. Follow-ups filed: species spellings across seasons (#40), and silent type coercion in `crt_ingest()`/`crt_schema_apply()` (#41). Code-check ran three rounds plus the plan review, and ended by enumerating the mechanism round 3 named.

## Measurement

Four public files at pinned commits, read through `crt_ingest()`:
- **Rows:** 1,359 (171 + 417 from 2023, 674 from 2024, 97 from 2025).
- **Tags:** 2023 has 228 tagged rows and 211 distinct tags, 17 of them seen twice within the season. 2024 has 188 distinct tags; 2025 has 50.
- **Recaptures:** the four 2024→2025 recaptures named in #6 reproduce. **No 2023 tag recurs in 2024 or 2025.** That disproves the issue's premise that 2023 recaptures were hidden "purely by column names". Adding 2023 extends the series without adding a cross-season recapture.
- **Data quality:** one 2023 comment holds a partial code (`3DD.003E192B9I`). Species are spelled differently between the shapes (`No Fish Caught`/`NFC`, `Cutthroat Trout (General)`/`Cutthroat Trout`).

Wrong turns:
- A first tag regex of 12 hex digits matched nothing. Codes are 10.
- Plan review caught that `as.character()` formats a POSIXct per value from R 4.3 but per column before it. The day is now taken with `format(tz = "UTC")`, and a non-midnight stamp aborts.

## Evidence

`data-raw/fish_data_check-real.R`: re-fetches the pinned files and asserts every number above. Its pins are checked against the schema's variants.

Closed by: PR (see `/gh-pr-push`)
