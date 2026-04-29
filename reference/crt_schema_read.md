# Read a bundled schema YAML by relative path

Resolves the YAML file path within crate's installed package via
[`system.file()`](https://rdrr.io/r/base/system.file.html), then reads +
parses it via
[`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html).
Single source of truth for "load a schema YAML by registry-declared
path" — used by
[`crt_ingest()`](https://newgraphenvironment.github.io/crate/reference/crt_ingest.md)
and available for any future `crt_schema_*` family member that needs
schema access.

## Usage

``` r
crt_schema_read(yaml_path)
```

## Arguments

- yaml_path:

  Character. Path relative to `inst/extdata/` in crate. E.g.,
  `"schemas/bcfp/user_habitat_classification.yaml"`.

## Value

The parsed schema as a nested list (yaml::read_yaml output).
