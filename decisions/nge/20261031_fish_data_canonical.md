# Fish data: one canonical set under FISS names, with 2023 tags read out of comments

**Date:** 2026-10-31
**Schema:** `schemas/nge/fish_data.yaml`

## Decision

`nge/fish_data` is a `file` entry: `crt_ingest("nge", "fish_data", path)` reads
any season's individual fish file and returns the same 29 columns with the same
types, so seasons stack with `dplyr::bind_rows()`.

- **Names follow the provincial FISS individual fish template and the field
  form** (`species`, `length_mm`, `weight_g`, `haul_number_pass_number`), not
  the 2024 field spreadsheet's `length`, `weight` and `pass_number`.
- **Every canonical column is returned for every file**, null where that file
  did not record it. Only `local_name` and `species` are required.
- **2023 PIT tags are read out of `comments`** into `pit_tag_id`. A full code is
  `3DD.` and ten hex digits, matched in either case and stored upper case. A
  comment with no full code, or with two different ones, gives null, and
  `comments` is kept as recorded.
- **`date` is an ISO day string** (`YYYY-MM-DD`). Times of day are `HH:MM:SS`
  strings.
- **Species names are kept as recorded** for now (#40).

## Trigger

#6 asked for 2023's `length_mm`/`weight_g` to be renamed onto the 2024 names so a
PIT tag recapture query could include 2023. Reading the files showed the
difference is a different file, not a rename.

## Rationale

Four real files, in the public fish passage reporting repos, pinned in the
schema's variants and read by `data-raw/fish_data_check-real.R`:

| variant | rows | columns |
|---|---|---|
| `2023-peace-6col` | 171 | `reference_number, local_name, common_name, length_mm, weight_g, comments` |
| `2023-skeena-7col` | 417 | the same, plus `haul_pass` |
| `2024-field-sheet` (2024) | 674 | 28: the field sheet, with tags joined by `row_id` |
| `2024-field-sheet` (2025) | 97 | the same 28 |

- The 2023 files are the individual fish already prepared for the provincial
  template; the 2024 files are the field sheet. 2023 has no date, project or
  effort columns, and no tag column: 228 of its 588 rows carry a tag written into
  `comments`. One more comment holds a partial code (`3DD.003E192B9I`).
- **Names.** The provincial template and the field form both say `length_mm`,
  `weight_g` and `haul_number_pass_number`. The field spreadsheet is the odd one
  out, and the form is the shape the next seasons will be captured in. Units in
  the name also match `form_fiss_site`'s measurements (`wetted_width_m`).
- **Null fill.** `crt_schema_conform()` neither adds a missing optional column
  nor drops an extra one, so seasons would not bind unless the handler returns
  the full set.
- **Tags.** Without them a three-season recapture query cannot see 2023 at all.
  Reading them needs a strict pattern: a partial code is a question for whoever
  wrote it, so it stays in `comments` for the QC rules (#38).
- **Day.** The spreadsheet stores the day as a midnight UTC timestamp. crate has
  no date type, and a `datetime` would assert an instant nobody recorded. A
  stamp with any other time of day aborts the read, because the column would
  then not be the day this assumes.

With the tags read, the measured outcome is:

- 211 distinct tags in 2023, 188 in 2024 and 50 in 2025.
- The four 2024→2025 recaptures named in #6 reproduce.
- **No 2023 tag recurs in 2024 or 2025.** So 2023 adds no cross-season
  recapture; its 17 tags seen twice are within the season.

## Alternatives considered

- **The 2024 spreadsheet's names as canonical** (#6's proposal). Rejected:
  every season captured by form would then need a rename back, and the names
  would drop their units.
- **Only the columns all three shapes share.** Rejected: that is six columns,
  and it would throw away the effort data from 2024 on to suit one season.
- **Leaving 2023 `pit_tag_id` null.** Rejected: it keeps 2023 out of the query
  the schema exists for.
- **`datetime` for `date`.** Rejected, as above.

## Consequences

- A caller stacking seasons adds the season itself: a 2023 row has no `date` or
  `project_name` to say which it is.
- Growth between captures needs `date` parsed (`as.Date()`), since it is
  stored as text.
- `species` spellings differ between the shapes (`No Fish Caught` and `NFC`,
  `Cutthroat Trout (General)` and `Cutthroat Trout`), so a count by species
  splits them until #40 settles a canonical spelling.
- A new file shape, such as a season captured with the field form, is a new
  `upstream_variant` and a branch in `crt_handler_nge_fish_data()`.

## References

- `inst/extdata/schemas/nge/fish_data.yaml`, `R/crt_handler_nge_fish_data.R`
- `data-raw/fish_data_check-real.R`: the measurement above
- #6, #38, #40
