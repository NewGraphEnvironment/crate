# Changelog

The provenance receipt contract has three published parts, each versioned on its own
([crate#58](https://github.com/NewGraphEnvironment/crate/issues/58)):

| part | what it decides | carried by | published at |
|---|---|---|---|
| form | the fields a receipt has | every receipt, as `output.receipt_version` | `receipt/v<X.Y.Z>/schema.json` |
| register | what a difference in each field does to a comparison's verdict | every comparison, as `register` | `receipt/register/v<X.Y.Z>/register.csv` |
| mapping | how an older record's fields become a receipt's, and each field's STAC key | nothing yet | `receipt/mapping/v<X.Y.Z>/mapping.csv` |

Rules:

- **A released version is never edited.** A change is a new version directory beside the old
  one, and the old one stays, because receipts and comparisons already made name it.
- **Any row change in the register is a new register version.** A row whose `action` changes
  changes published verdicts.
- **Any row change in the mapping is a new mapping version.** It changes what a migrated
  receipt holds.
- **A form change brings a register change**, because the register has one row per field of
  the form. A register or mapping change leaves the form alone, so it never moves the number
  a receipt carries.
- **Each register version names the form version it covers.**
- **A change in the code that reads a part is a change in that part.** A comparison's verdict
  also depends on rules in code (when a fingerprint difference is `within`, what makes a recipe
  unknown), and a migration on the mapping's transforms. A code change that moves any expected
  value in a register version's `compare.json`, or changes what a mapping transform produces, is
  a new register or mapping version, even when no row changes.

## register v1.0.0 (2026-11-09)

First published at a versioned URL. It covers form v1.0.0. The rows are the ones crate has
shipped since v0.12.0, unchanged.

## mapping v1.0.0 (2026-11-09)

First published at a versioned URL. The rows are the ones crate has shipped since v0.12.0,
unchanged.

## form v1.0.0 (2026-11-05)

First release. See [crate#43](https://github.com/NewGraphEnvironment/crate/issues/43).
