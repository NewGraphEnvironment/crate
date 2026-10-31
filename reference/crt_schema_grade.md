# Which records can answer which question

Evaluates each grade a registered schema declares against every row of a
data frame. A row meets a grade when every column the grade requires is
present in the frame and non-missing in that row.

## Usage

``` r
crt_schema_grade(df, source, file_name)
```

## Arguments

- df:

  A data frame, usually the output of
  [`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md).

- source:

  Character. Source family code (e.g. `"nge"`).

- file_name:

  Character. Logical file name (e.g. `"form_pscis"`).

## Value

A tibble with one logical column per declared grade, in declaration
order, and one row per row of `df`.

## Details

A grade is a separate thing from the schema's `required` flag, on
purpose. Columns added to a form mid-season are optional in the schema,
so a record from an earlier vintage still conforms; whether that record
can answer a given question is asked here. Making the new columns
required would make the earlier records unharvestable, and having no
grade would count them as equivalent to records that carry the extra
fields.

A column the frame does not have at all fails the grade for every row:
an earlier vintage that never asked the question cannot answer it.

Throws when the schema declares no grades.

## See also

[`crt_schema_cols()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_cols.md)
for the columns themselves.

## Examples

``` r
records <- data.frame(
  project = "example", form = "form_monitoring_fish_passage",
  record_id = 1:2, source_version = "v1",
  schema_version = "35-0000000000000000",
  captured_at = "2026-09-21T18:00:00Z",
  x = c(1203451, NA), y = c(1012345, 1012400), source_epsg = 3005L
)
crt_schema_grade(records, "nge", "form_monitoring_fish_passage")
#> # A tibble: 2 × 1
#>   harvestable
#>   <lgl>      
#> 1 TRUE       
#> 2 FALSE      
```
