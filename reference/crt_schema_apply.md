# Apply a schema's canonical type declarations to handler output

Schema YAML is the single source of truth for canonical column types.
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
calls this after the registered handler returns, so every (source,
file_name) pair gets type enforcement for free — handlers do not encode
type knowledge.

## Usage

``` r
crt_schema_apply(df, schema)
```

## Arguments

- df:

  A data frame returned by a registered handler.

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
