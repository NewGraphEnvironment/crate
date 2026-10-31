# What each column of a registered schema means

Returns the schema's column declarations as a tibble, one row per column
in schema order: type, whether it is required, and what the schema says
the column means, including the allowed values a QC rule can check a
record against.

## Usage

``` r
crt_schema_cols(source, file_name)
```

## Arguments

- source:

  Character. Source family code (e.g. `"nge"`).

- file_name:

  Character. Logical file name (e.g. `"form_pscis"`).

## Value

A tibble with columns:

- `name`, `type`, `required`:

  as declared; see
  [`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md)

- `units`:

  unit of a measurement, e.g. `"m"`, else `NA`

- `values`:

  list of character vectors: the values the column may store, or
  `character(0)` when the schema sets none

- `labels`:

  list of character vectors, parallel to `values`: what a form displays
  for each. The same as `values` unless the vocabulary is coded, e.g.
  stores `"4"` and displays `"Coniferous Trees"`

- `range_min`, `range_max`:

  numeric bounds, else `NA`

- `relative_to`:

  for a column holding file paths, what they are relative to, else `NA`

- `null`:

  what a null means in this column when it means something other than
  "not recorded", else `NA`

- `notes`:

  the schema's description of the column, else `NA`

## Details

This is the reading of a schema meant for other code. A form builder
takes the column list, types and vocabularies from here and adds only
how the form shows them; a QC rule takes `values` and `range_min` /
`range_max` and flags a record whose value falls outside them. Neither
has to parse the YAML.

`values` and the range are declarations, not checks:
[`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md)
does not refuse a value outside them. A value typed or dictated outside
a vocabulary is a record to flag, not one to drop.

## See also

[`crt_schema_grade()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_grade.md)
for which records can answer a question,
[`crt_files()`](https://newgraphenvironment.github.io/crate/reference/crt_files.md)
to list registered entries.

## Examples

``` r
cols <- crt_schema_cols("nge", "form_capture")
cols[, c("name", "type", "required")]
#> # A tibble: 6 × 3
#>   name           type     required
#>   <chr>          <chr>    <lgl>   
#> 1 project        string   TRUE    
#> 2 form           string   TRUE    
#> 3 record_id      integer  TRUE    
#> 4 source_version string   TRUE    
#> 5 schema_version string   TRUE    
#> 6 captured_at    datetime TRUE    
```
