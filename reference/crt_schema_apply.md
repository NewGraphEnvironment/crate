# Apply a schema's canonical type declarations to handler output

Schema YAML is the single source of truth for canonical column types.
[`crt_schema_conform()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_conform.md)
calls this after validation, so every registered (source, file_name)
pair gets type enforcement for free — handlers do not encode type
knowledge.

## Usage

``` r
crt_schema_apply(df, schema)
```

## Arguments

- df:

  A data frame.

- schema:

  The parsed schema YAML (a list with `canonical$cols`).

## Value

A tibble with columns coerced to canonical types.

## Details

Reads `canonical.cols[].type` from the schema and coerces each named
column to the declared type. Columns present in the data but absent from
the schema's `canonical.cols` are left untouched. Columns absent from
the data but declared in the schema are left to
[`crt_schema_validate()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_validate.md)
to surface (this function does not validate presence — only type when
the column exists).

Supported `type` values:

- `integer` -\> [`as.integer()`](https://rdrr.io/r/base/integer.html)

- `double` -\> [`as.double()`](https://rdrr.io/r/base/double.html)

- `string` -\> [`as.character()`](https://rdrr.io/r/base/character.html)
  (handles readr's Date / POSIXct auto-parsing for columns the schema
  declares as text)

- `logical` -\> [`as.logical()`](https://rdrr.io/r/base/logical.html)

- `datetime` -\> `POSIXct` rendered in UTC, see below

## datetime is stamped, never converted

A `datetime` column means **an instant**, and this function never
changes which instant it is. A `POSIXct` input has its `tzone` attribute
*stamped* to `"UTC"`, which changes the rendering and nothing else; the
epoch is untouched.

That distinction is the whole point of the type. Several readers return
correct UTC instants with an **empty `tzone`** attribute — GeoPackage
`DATETIME` columns read through `sf` are the case this was written for —
so R renders them in
[`Sys.timezone()`](https://rdrr.io/r/base/timezones.html). On a UTC-7
machine the same instant prints seven hours earlier than it does from an
epoch, which reads as a second clock in a second timezone. Converting to
"fix" the rendering injects a real whole-hour error into every
downstream join; stamping fixes the label, which is all that was ever
wrong.

Other inputs:

- numeric is read as **epoch seconds**

- `Date` is read as UTC midnight. Note
  [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) silently
  ignores `tz` for a `Date`, converting in the system zone instead, so
  this goes through [`format()`](https://rdrr.io/r/base/format.html)
  first — west of UTC the naive call moves the day boundary.

- character is parsed as ISO 8601 in UTC, accepting a `T` separator and
  a trailing `Z`
