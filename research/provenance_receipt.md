# A provenance receipt

**Verified:** 2026-11-10 · **Issues:** crate#43, #58, #59, #60 · **Produced by:** design notes;
the vectors by `data-raw/receipt_vectors.R`, cross-checked by `data-raw/receipt_vectors_crosscheck.py`.

crate#43. The design of `receipt.json`, kept here and revised in place while the branch builds it.
It becomes the vignette (`vignettes/receipt.Rmd`) once the R API is stable.

**Verified:** 2026-11-09 (versioning, crate#58) · **Issues:** crate#43, crate#58

## Why

Every package and catalogue that publishes an output records how it was made, each in its own
shape: a `manifest.json` with a `provenance` block, a `provenance.json` sidecar, a log table, STAC
properties, raster tags. An internal census of NGE's records (2026-11-05) found 272 field names answering "built from what"
alone. No two records can be compared without a hand-written mapping.

A rebuild asks two questions, and they need two answers:

- **Was it made the same way?** The recipe: code, config, the inputs' identities, a seed.
- **Did it come out the same?** The result. One recipe can give slightly different results on
  another machine or day (row order, float summation order, random draws).

So the comparison has three verdicts, not two. `identical` is the same recipe and the same result.
`equivalent` is the same recipe with every result value within the tolerance the output declares.
`different` is another recipe, or a value past its tolerance, and it names what differed.

## The worked case

knowledge#145 (2026-11-04): one link build's evidence, built twice on one machine from the same
code. `visits_link.csv`, `visits_species.csv` and `walks.csv` were byte-identical. `access_check.csv`
had the same rows and counts but differed in the 11th decimal place, at most 9.5e-11 km, because
Postgres summed the km in another order.

A receipt for that output declares `km` with a tolerance of `1e-9`. Both builds then write the same
recipe, and their `access_check` fingerprints agree, because each rounds `km` to 9 decimals before
hashing. The comparison reads both receipts and answers `equivalent`: same `recipe_id`, every
fingerprint equal, and the `km_total` summary within its `1e-6`. Without the declaration the
fingerprints differ and the answer is `different`, naming `result: fingerprint access_check`.

The vignette carries this through with a synthetic copy of the four tables, so its examples run.

## The four blocks

```json
{
  "output":  { "name": "...", "scope": "...", "receipt_version": "1.0.0", "schema": "..." },
  "recipe":  { "code": {}, "config": {}, "inputs": {}, "seed": null, "recipe_id": "<64 hex>" },
  "result":  { "fingerprint": {}, "parts": {}, "summary": {}, "tolerance": {} },
  "context": { "time": "...", "host": "...", "run": {}, "session": "...", "toolchain": {}, "inputs": {} }
}
```

### `output`: what the thing is. Not hashed.

| field | type | |
|---|---|---|
| `name` | string | the output's name, e.g. `link_evidence` |
| `scope` | string or null | the partition: a watershed group, a region, a year |
| `receipt_version` | `"1.0.0"` | the schema version the receipt was written to |
| `schema` | string or null | the crate schema the output conforms to, e.g. `nge/discharge/fwa/v1/segment_monthly` |

### `recipe`: how it was made. Identity.

| field | type | |
|---|---|---|
| `code` | object, keyed by repository | per repository of ours: `commit` (40 hex), `version` (string or null), `dirty` (boolean) |
| `config` | object | `files` (keyed by path: the sha256 of its bytes), `settings` (the resolved run settings, verbatim) |
| `inputs` | object, keyed by input name | exactly one of `recipe_id`, `version_id`, `sha256`, or `none` (a string saying why) |
| `seed` | integer or null | the seed of any fit |
| `recipe_id` | 64 lowercase hex | SHA-256 over the RFC 8785 canonical JSON of the other recipe fields |

### `result`: what came out. Identity.

| field | type | |
|---|---|---|
| `fingerprint` | object, keyed by table name | `sha256` (64 hex), `rows` (integer) |
| `parts` | object, keyed by path relative to the receipt | `bytes` (integer), `sha256` (64 hex), and `table` where the file holds a fingerprinted table |
| `summary` | object, keyed by name | a number: `rows` and named totals such as `km_total` |
| `tolerance` | object | `tables` (keyed by table, then column: a tolerance), `summary` (keyed by name: a tolerance) |

### `context`: where and when. Never identity.

| field | type | |
|---|---|---|
| `time` | string | UTC, ISO 8601 with a trailing `Z` |
| `host` | string, optional | left out of a receipt that is published |
| `run` | object | run identifiers: a link `run_id`, a CI run, a job id |
| `session` | string or null | a session or operator note |
| `toolchain` | object, keyed by tool | third-party versions: `R`, `GDAL`, `terra`, `arrow`, `Python` |
| `lockfile_sha256` | 64 hex or null | the sha256 of `renv.lock` (or another lockfile) |
| `inputs` | object, keyed by input name | each input's own result (its fingerprint or sha256), for reporting |
| `legacy` | object, optional | in a migrated receipt, the older record's fields with no receipt key, verbatim |

## Decisions

Each with a line of why. Those marked *gate* were decided by the owner on 2026-11-05; those marked
*issue* were decided before #43 and are not reopened.

**The name is `receipt`, one `receipt.json` per output** (*issue*). In crate a record is a data row.

**Toolchain versions are context; a seed is recipe; resolved run settings are config** (*issue*). A
GDAL upgrade alone should read "same recipe, equivalent result" or "different result", which the
result decides. A different seed draws differently, so it is a different recipe. Two runs that
differ only in a command-line argument are two recipes.

**crate owns every part that must agree byte for byte; each package declares what only it knows**
(*issue*). The schema, the canonical forms, the fingerprint, the `recipe_id` hashing, the comparison
and the R writer are crate's. Which inputs and settings are recipe, which tables are fingerprinted
and their tolerances are the package's, declared as YAML beside its writer and read by
`crt_receipt_keys()`.

**SHA-256 everywhere, stored as lowercase hex** (*gate*). The hash for `recipe_id`, the table
fingerprint, the `config.files` digests and `parts`. stacs' body digest already uses SHA-256 over
JCS, and Python's `hashlib` and Postgres's `sha256()` both carry it, so no other implementation needs
a library for the hash. The receipt schema version pins the algorithm: a change of hash is a new
schema version. `crt_schema_fingerprint()` stays XXH64; it hashes column names and types, a
different contract with its own stored values.

**`recipe_id` is SHA-256 over the RFC 8785 (JCS) canonical JSON of the recipe block, without
`recipe_id` itself** (*issue*). Any language with a JCS serializer computes the same bytes.

**Collections in the recipe are objects keyed by name, never arrays.** `code` is keyed by
repository and `inputs` by input name, because JCS sorts object keys and leaves arrays in the order
given. With arrays, two writers listing the same inputs in another order would compute two
`recipe_id`s; with objects there is no ordering rule to get wrong. `parts`, `fingerprint` and
`tolerance` follow suit.

**`recipe_id` hashes each input's recipe identity, never its result** (*issue*). An input rebuilt
equivalently has a new result. Folding that into `recipe_id` would make everything downstream
`different`, one level below every equivalent rebuild. floodplains' `fp_provenance.R` keeps
`inputs_hash` and `outputs_hash` apart for the same reason. Input results go in `context.inputs`,
listed for reporting and outside both identities.

**An input with no receipt names its version, its bytes, or why it has neither.** `version_id` is an
object store's version id, `sha256` the hash of its bytes, and `none` a string saying why neither is
available ("live API, not versioned"). Exactly one is present. A declared `none` is honest; an
omitted input is not allowed.

**`config` stores the settings themselves, not only a hash of them.** The issue asked for a hash
over the config bytes and the resolved settings, with a list of what it covers. The keys of
`config.files` and `config.settings` are that list, and storing the settings verbatim lets a
`different` verdict name the setting (`recipe: config.settings.species`), not only "config". The
config's bytes stay hashed (`config.files`), since a config file can be large.

**The table canonical form is the JCS of `{"columns": [...], "rows": [[...], ...]}`** (*gate*).
- Columns are sorted by name, in C collation (bytes of UTF-8).
- Every cell is a string or `null`; `null` is NA.
- Characters and factors are their UTF-8 text, not Unicode-normalized.
- Integers are their decimal digits.
- Doubles with a declared tolerance `10^-k` are written with exactly `k` decimals, rounding the
  double's exact binary value, ties to even. That is what C's `printf("%.*f")` (R's `sprintf()`)
  and Python's `format(x, ".kf")` do, so neither needs a rounding routine of its own. Rounding the
  decimal you see instead (half-up on the printed decimal, Postgres's `round(numeric)` after a
  cast that keeps 15 digits) disagrees wherever the binary value is not the decimal printed, and
  on exact ties: `printf` gives `0`, `2`, `2` for 0.5, 1.5, 2.5. With no tolerance a double is
  written as ECMAScript's shortest round-trip form (exact). `-0`, and any value that rounds to
  zero, is written without a sign. NaN and Inf abort.
- Logicals are `true` and `false`.
- Dates are `YYYY-MM-DD`; datetimes are converted to UTC and written `YYYY-MM-DDTHH:MM:SSZ`. A
  datetime with fractional seconds is refused, not truncated: round it, or fingerprint it as a
  number with a tolerance. A tolerance on a datetime would need rules for carrying into the next
  second and for times before 1970 that every implementation must match, for a case no output
  has yet.
- Rows are sorted by the bytes of each row's own JCS.
- The fingerprint is the SHA-256 hex of the UTF-8 bytes of that JCS.

This reuses the `recipe_id` serializer, so there are no CSV quoting, escaping or line-ending rules to
specify, and Python's `rfc8785` reproduces it. Every cell is a string, so JCS's number rules never
apply to cell values.

**A tolerance is an absolute `10^-k`.** A column's tolerance says both how the fingerprint rounds
(`k` decimals) and what the comparison accepts (`|a - b| <= 10^-k`). A tolerance that is not a power
of ten has no rounding that matches it, so it is refused. A declared spread or an invariant for a
model fitted with random draws ("the same pick and region") is for a later schema version.

**A value near a rounding boundary can fingerprint apart while within tolerance.** `0.0000000014`
and `0.0000000016` are 2e-10 apart, well within `1e-9`, yet round to `0.000000001` and
`0.000000002`. A comparison of
receipts alone cannot tell this from a real difference, so it says `different` (`result:
fingerprint <table>`), and says it compared receipts only. Given both tables (`tables =`), the
comparison re-reads the cells and returns `equivalent` when every cell is within tolerance. Its
report says which it did.

**Every recipe field refuses; the register says what a difference in each other field does.**
`recipe_id` covers every recipe field, so a recipe difference is always `different`. The register
still lists each recipe field, as `refuse`, so the report names the field, and its test asserts
none is anything else. Result fields refuse unless within tolerance. `warn` fields are reported
without changing the verdict (`output.receipt_version`, `output.schema`). `record` fields are listed only: all of `context`.

**A receipt's version is its form's; the register and the mapping are versioned on their own**
(crate#58). A verdict is a function of the register's rows and a migrated receipt of the mapping's,
so each is frozen under its own version directory (`inst/extdata/receipt/register/v1.0.0/`,
`mapping/v1.0.0/`) and published at the same path under the site's `receipt/`. The number a
receipt carries in `output.receipt_version` answers what fields it has, so a register or mapping
change never moves it: tying the register to it would make a one-row action change a new form,
and `crt_receipt_read()` reads only the current form, so every receipt already written would stop
reading. Two receipts of one shape must not `warn` at each other because the rulebook moved
between them. The comparison names the register version it judged under, and the declared action
of each field a package overrode. A register version covers one form version (a form change brings
a register change; not the reverse). `compare.json` records the register's actions, so it moved
from the form's vectors to the register's directory; the four hashing vector files stay with the
form. The rules, including that a code change moving an expected verdict is a new register
version, are in `pkgdown/assets/receipt/CHANGELOG.md`.

Open in crate#62: reading older form versions in `crt_receipt_read()`, and recording the mapping
version on a migrated receipt. Both need the first form change (v1.1.0), and they go together:
the bump before the reader would make every published v1.0.0 receipt unreadable.

**Only plain values are serialized; every other R class is refused.** Lists, character, double,
integer and logical vectors, factors (as their labels) and `I()`; a table's columns may also be
`Date` or `POSIXct`. Any other class or attribute (octmode, hexmode, `ts`, a `units` attribute, S4,
POSIXlt, a data frame as a value, integer64, a matrix's `dim`, a vector's names) is refused rather
than written through its print or subset methods, which wrote octmode 493 as `755`, dropped a
`ts()` start and turned 5 km into 5 (code-check round 3 enumerated 37 shapes). A writer in another
language holds none of these, so no spelling of them is shared.

**A config file is hashed as its bytes, as checked out.** Git for Windows checks text out with
CRLF by default, so a repo whose config enters `recipe_id` should pin line endings in
`.gitattributes` (`*.yaml text eol=lf`). Normalizing line endings in crate would hash something
other than the file, which no other implementation could reproduce from the bytes alone.

**A published receipt leaves out `host`.** A host name tells a public reader nothing; it stays in
the private run log. `crt_receipt_write(publish = TRUE)` drops it.

**`parts` paths are relative to the receipt's directory**, written with `/`. A receipt moved with
its output stays true.

**A part names the table it holds.** In the worked case `access_check.csv`'s bytes differ between
the builds while its fingerprint agrees. Without knowing that file holds that table, the
comparison could only refuse every byte change (and never say `equivalent`) or accept every one
(and wave through a changed raster nobody fingerprinted). `parts.<path>.table` says which; a part
whose bytes differ and that names no table, or whose table does not agree, is `different`.

**A migrated receipt has `recipe_id` null.** `crt_receipt_migrate()` reads an old manifest or
sidecar through the mapping table. Old records lack fields the recipe needs (a seed, resolved
settings), so a migrated receipt sets `recipe_id` to `null` and `output.migrated_from` to the
source format, and the comparison reports `recipe: unknown` rather than inventing an identity.

**The mapping table covers what migrate reads, not the whole census.** The census holds 887
fields in 227 record formats across 26 repos. `inst/extdata/receipt/mapping/v1.1.0/mapping.csv` maps every
field of the formats `crt_receipt_migrate()` reads (link's `manifest.json`, floodplains'
`provenance.json`), STAC's keys (`file:checksum`, `file:size`, `processing:software`,
`processing:datetime`) beside the receipt keys they mirror, and the names most repos share
(`<repo>_sha`, `<repo>_version`, `host`, `built`). A format joins it when its writer next moves,
which is the forward-only rule; the census stays the inventory. Exact receipt keys for 887 fields
written at once would be guesses. The two private repos' field names stay out of crate.

**What a migrated receipt cannot place, it keeps.** An old field with no receipt key (an md5
where a part needs sha256, floodplains' own `inputs_hash`, a raster's cell digest that is not a
crate fingerprint) goes verbatim into `context.legacy`, keyed by its path in the record. A field
the mapping does not know at all goes there too, with a warning. Nothing is dropped, and nothing
old is passed off as a receipt identity.

**The STAC rows are executed and pinned** (crate#59, #60). `crt_receipt_stac()` runs them, and
`mapping/v1.1.0/stac.json` holds receipts with the item fields each maps to, or a refusal, so a
second implementation cannot read the rows differently and still pass. Where v1.0.0 was silent,
v1.1.0 decides: a null `recipe_id` or `version` is left out, never published as null; a part no
asset names is not mirrored, since an item may publish fewer files than the build made; an asset
whose href names no part is refused rather than given a guessed checksum. The receipt asset's
`file:checksum` is the digest of the published receipt's bytes, which `crt_receipt_write()`
returns: nothing else can compute it, since a receipt is not one of its own parts. It carries no
`file:size`, because the digest already identifies the bytes. `crt_receipt_write()` used to return
the receipt as built in memory, which held `NA` where the file holds `null`; the file is the record,
so the digest that names it is the return value, and `crt_receipt_read()` gives back what was
written.

**One R implementation, one written contract** (*issue*). Producers that cannot call R implement
the contract and pass the same test vectors: stacs (stacs#12) for the Python catalogues.

## Implementing JCS: the number spelling needs a correct parser

RFC 8785 writes a number the way ECMAScript does: the fewest significant digits that read back
as the same double. Finding them needs a decimal-to-double parser that rounds correctly. Not
every language's default one does. R's `as.numeric()` misread 84% of 200,000 random 17-digit
spellings on arm64 macOS, where long double is double; the C library's `strtod` (which
`jsonlite` and Python use) misread none. An implementation should check its parser against the
number vectors before trusting it, and its own tests should build doubles from their bits, not
from 17-digit literals its parser may misread.

Two more things an implementation must get right, both found writing the Python cross-check:

- **Read every JSON number as a double.** JSON has one number type, and RFC 8785 spells every
  number as ECMAScript does. Python's `json` reads `1152921504606846976` as an `int`, which
  `rfc8785` refuses past 2^53; `parse_int=float` reads it as JavaScript would.
- **Rows sort by the bytes of their JSON, not by their values.** `["a b"]` sorts before `["a"]`,
  because a space (0x20) is below the closing quote (0x22). The rule is mechanical so that no
  implementation needs a collation.

## The comparison

`crt_receipt_compare(a, b, tables = NULL)` reads two receipts and returns:

- `verdict`: `identical`, `equivalent` or `different`
- `mode`: `receipts` (the receipts alone) or `bytes` (the result's tables re-read)
- `differences`: one row per field that differed, with its side (`output`, `recipe`, `result`,
  `context`), the field's path, the register's action, and a detail (`result: column km, 3 rows
  past 1e-9`)

It reads the register to decide what each difference does, overlaid by the package's declaration.
Tables supplied are each checked against their own receipt's fingerprint, whether or not the two
receipts disagree: re-reading certifies that what is on disk is what the receipt claims, and
`mode` is then `bytes`.
A field is written `block.member`, with a key of a keyed collection in brackets
(`result.parts[access_check.csv].sha256`), because keys such as file paths contain dots.

The worked case compares as:

```
equivalent (receipts only)
  within result.parts[access_check.csv].bytes: 124 vs 128; table access_check agrees
  within result.parts[access_check.csv].sha256: "04994f..." vs "6801fb..."; table access_check agrees
  within result.summary[km_total]: 47.3767792597 vs 47.376779259805; within 1e-06
  record context.run: {"link_run_id":"20261104T181900Z-bulk"} vs {"link_run_id":"20261104T214400Z-bulk"}
  record context.time: "2026-11-04T18:22:05Z" vs "2026-11-04T21:47:31Z"
```

Without the `km` tolerance the same pair is `different`, naming
`result.fingerprint[access_check].sha256`.

## Test vectors

Committed under `inst/extdata/receipt/vectors/v1.0.0/` and versioned with the schema: JCS inputs
with their exact bytes, recipes with their `recipe_id`, and tables with their fingerprint. Receipt
pairs with their verdict test the register, so they are in
`inst/extdata/receipt/register/v1.0.0/compare.json` (crate#58; moved byte-identical, the one edit
to a frozen vector directory, whose hashing files did not change). Receipts with the STAC item
fields they map to test the mapping, so they are in `inst/extdata/receipt/mapping/v1.1.0/stac.json`
(crate#59). crate's tests run every file, and stacs' CI runs the same files at a pinned crate tag.

## Not in v1

- `crt_receipt_lineage()`: follow inputs' `recipe_id`s upstream.
- Tolerances for fits with random draws (a spread, an invariant).
