# Findings — A shared provenance receipt: a language-neutral contract, crate's R implementation, and a three-way comparison (#43)

## Issue context

**If we do it:** every package and catalogue that publishes a table, raster, model or STAC item
writes one receipt per output in one shape, saying how it was made and what came out. crate holds
the contract in a form any language can implement (a JSON Schema, a canonical-JSON rule, a
fingerprint specification with test vectors), and the R code that writes and compares receipts, so
R packages share one implementation rather than each writing their own. Any rebuild can then be
compared with a reference copy and answered `identical`, `equivalent` within a declared tolerance,
or `different`, naming what differed. **If we never do:** each package keeps its own manifest or
sidecar under its own field names, and the STAC catalogues, built mostly in Python, keep theirs. A
check either trusts a label (a run id) or demands exact bytes, and an equivalent rebuild, for
example a floating sum that came out in another order, reads as a failure.

## Problem

The packages and catalogues that publish outputs each record provenance their own way. Some write a
`manifest.json` with a `provenance` block and per-part md5, some a `provenance.json` sidecar, some
log tables, some STAC properties and raster tags. Across them there are hundreds of distinct field
names for what an output was built from. No two records can be compared without a hand-written
mapping, and an R-only answer would leave the catalogues, whose items are mostly built and
registered in Python, outside it.

A rebuild asks two separate questions:

- **Was it made the same way?** This is the recipe: code commits, config, and the identities of the
  inputs.
- **Did it come out the same?** This is the result. The same recipe can give slightly different
  results on another machine or another day, through row order, float summation order, or a model
  fitted with random draws. "Equivalent" has to be an answer in its own right.

A worked case: the same build's evidence, built twice from the same code, gave three
byte-identical tables and a fourth differing in the 11th decimal place (max 9.5e-11 km), because
the database summed in another order. A receipt that fingerprints the tables that matter and
declares a rounding on the km sum calls that `equivalent`. Today that choice is one package's
habit, written nowhere.

## Decided before this issue, and not reopened here

- **The name is `receipt`**, one `receipt.json` per output, replacing the manifests and sidecars as
  each writer is next touched. Not "record": in crate a record is a data row.
- **Toolchain versions are context**, never part of identity. **A seed is recipe.** **Resolved run
  settings** (command-line arguments, defaults filled at run time) are hashed with the config.
- **crate owns every part that must agree byte for byte**: the schema, the canonical forms, the
  fingerprint, the `recipe_id` hashing, the comparison and the R writer. **Each package owns what
  only it knows**: which inputs and settings are recipe, which tables are fingerprinted, their
  tolerances. It declares them as data beside its writer, and crate reads the declaration.
- **One R implementation, one written contract.** Producers that cannot call R (Python catalogues,
  SQL) implement the contract and pass the same test vectors.

## Proposed

- [ ] **`research/provenance_receipt.md` first**, revised in place as each decision below is made:
      the worked case carried through two receipts, a comparison and its verdict; the four blocks;
      the decisions above with a line of why each. It becomes the vignette. Add `^research$` to
      `.Rbuildignore`.
- [ ] **The receipt schema**, a versioned JSON Schema published at a stable URL that a version never
      leaves, the way the STAC field schemas are (#23). Four blocks:
  - `output`: name, scope or partition, receipt version, and the crate schema the output conforms
    to where there is one. Names the thing; not hashed.
  - `recipe`: `code` (per repository of ours: repo, commit, version, dirty), `config` (a hash over
    the config bytes **and** the resolved run settings, with a list of what it covers), `inputs`
    (per input: its name and its own `recipe_id`; for an input with no receipt, its object version
    id or content hash, else an explicit "none, declared"), `seed` for any fit, and `recipe_id`.
  - `result`: `fingerprint` per fingerprinted table, `parts` (per file: path, bytes, sha256),
    `summary` (rows and named totals), `tolerance` (per column or summary value).
  - `context`: host, time (UTC), run identifiers, session, and third-party toolchain versions
    (GDAL, terra, arrow, R, Python, lockfile hash). Recorded, never part of identity. `host` is
    optional and left out of a receipt that is published: a host name tells a public reader nothing.
- [ ] **`recipe_id`** is a hash over the RFC 8785 (JCS) canonical JSON of the recipe block, so any
      language with a JCS serializer computes the same bytes. It hashes each input's **recipe**
      identity, recursively, never an input's result: an input rebuilt equivalently must not make
      everything downstream `different`. Input results are listed beside the recipe for reporting.
- [ ] **The table fingerprint specification**: the canonical form (column order, row sort, float
      rounding to the declared tolerance, NA and empty spellings, UTF-8 bytes) and the hash.
      `crt_table_fingerprint()` implements it, a name kept apart from `crt_schema_fingerprint()`,
      which hashes column names and types, not values.
- [ ] **Test vectors**, committed under `inst/extdata/receipt/vectors/` and versioned with the
      schema: recipes with their `recipe_id`, tables with their fingerprint, receipt pairs with
      their verdict. crate's tests run them; every other implementation runs the same files.
- [ ] **The R family, `crt_receipt_*`**: `crt_receipt_write()` takes the values a package supplies,
      computes the ids and fingerprints, and writes `receipt.json`; `crt_receipt_read()`,
      `crt_receipt_validate()` (against the schema), `crt_receipt_compare()`, and
      `crt_receipt_keys()`, which reads a package's declaration of its recipe inputs and settings,
      fingerprinted tables, tolerances and register.
- [ ] **The comparison**: two receipts in, one verdict out. `identical` is the same recipe and the
      same result. `equivalent` is the same recipe with every result value within its declared
      tolerance. `different` is another recipe, or a value past its tolerance. Each verdict names the
      side and the field that differed, and says whether it compared receipts only or re-read the
      result's bytes.
- [ ] **A per-field register as the comparison's input**: one row per receipt field saying whether a
      difference refuses, warns or is recorded. Tested by building, per field, two receipts that
      differ only there, so a field added with no row fails.
- [ ] **A mapping table** from the field names packages and catalogues write today to the receipt's
      keys, and to STAC's (`file:checksum`, `file:size`, `processing:software`,
      `processing:datetime`), so existing records stay readable during the move;
      `crt_receipt_migrate()` reads an old manifest or sidecar through it. Writers converge
      forward-only, each when it is next touched.
- [ ] **A `receipt:` STAC field schema**, published the way #23 publishes `lidarbc:` and `las:`,
      for the receipt's identity fields that have no standard STAC home (`receipt:recipe_id` first).
      A STAC item then carries its provenance where STAC clients and pgstac queryables can read it.
- [ ] **The vignette**, last, from the research file once the R API is stable, with examples that
      run on the worked case.

Later members of the family, not in this issue: `crt_receipt_lineage()` (follow inputs'
`recipe_id`s upstream) and `crt_receipt_stac()` (write a receipt's STAC fields onto an item).

**Boundary.** crate knows none of its consumers. Packages pin a floor (`crate (>= x.y)`), never a
tag. Open for this issue's planning: the hash (stacs' body digest already uses SHA-256 over JCS;
`crt_schema_fingerprint()` uses XXH64) and the canonical table form's exact bytes.

Relates to #23

## Comments

None at plan time (2026-11-05).

## Phase 2: the gh-pages guard fires for receipt/ (2026-11-05)

The "Check the published schemas against what is on gh-pages" step was extracted from
`.github/workflows/pkgdown.yaml` and run in a scratch git repo, with `docs/` built by copying
`pkgdown/assets/*` (what pkgdown does) and a fake gh-pages commit made from that `docs/`,
passed as `SCHEMAS_PUBLISHED_REF`:

| case | result |
|---|---|
| nothing changed | exit 0, `4 schema(s) built` (lidarbc 1.0.0, 1.1.0, las 1.0.0, receipt 1.0.0) |
| `receipt/v1.0.0/schema.json` edited in source and build | exit 1, "differs from the published version" |
| `pkgdown/assets/receipt/` removed | exit 1, "no receipt schema" and "published but no longer built" |
| ref `deadbeef` | exit 1 (set -e on `git rev-parse --verify`) |

Restore-the-bug on the schema: with `maxProperties` dropped from `definitions/input`, an input
carrying both `recipe_id` and `sha256` validates; with it, ajv rejects it.
