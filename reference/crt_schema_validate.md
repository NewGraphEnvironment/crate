# Validate a data frame against a schema's canonical column declarations

Checks that every column declared `required: true` in the schema's
`canonical.cols` is present in `names(df)`. Fails loud listing all
missing required columns. Returns `invisible(NULL)` on success.

## Usage

``` r
crt_schema_validate(df, schema)
```

## Arguments

- df:

  A data frame (handler output, post-shape, pre-type).

- schema:

  The parsed schema YAML (a list with `canonical$cols`).

## Value

`invisible(NULL)` on success. Throws fail-loud
[`cli::cli_abort`](https://cli.r-lib.org/reference/cli_abort.html)
listing all missing required columns on failure.

## Details

Called by
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
AFTER handler dispatch and BEFORE
[`crt_schema_apply()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_apply.md)
— validate shape first (fail loud on missing required cols), coerce
types second. Without validation here, a missing required column would
silently become NA after `as.integer(NULL)`-style coercion in the
type-apply step; this surfaces the failure at the right layer.

Lives in the `crt_schema_*` family alongside
[`crt_schema_apply()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_apply.md)
and
[`crt_schema_read()`](https://newgraphenvironment.github.io/crate/reference/crt_schema_read.md).

Future extensions (reserved family slots; NOT in v0.0.2):

- `cols[].range` numeric range checks

- `cols[].enum` value-membership checks

- `cols[].predicate` custom predicate function refs

Each lands as additional
[`cli::cli_abort`](https://cli.r-lib.org/reference/cli_abort.html)
branches in this function as the schema YAML grows the corresponding
declaration keys. The function signature does not change — schema YAML
drives behavior.
