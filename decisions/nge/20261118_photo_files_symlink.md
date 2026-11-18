# A symbolic link is a path, not a copy

**Date:** 2026-11-18
**Schemas:** `schemas/nge/photo_files.yaml`

## Decision

`photo_files` gains an optional `symlink` column (string): the target a symbolic link
at `path` names, as the link holds it, not resolved, so a relative target stays
relative to the link's folder. Only a link at the last component of `path` is marked.
A missing value means the row is not known to be a link. A row with `symlink` holds no
bytes of its own: its `checksum`, `size` and metadata are its target's.

## Trigger

crate#76. A photo indexer lists a symbolic link to a file as a file, and its row is
identical to its target's: same checksum, size and metadata. A reader that removes
duplicates by checksum cannot tell such a link from a copy, and can remove the file and
keep the link.

## Rationale

- The key is `(checksum, path)`, and one file's bytes at two paths are two rows
  (`20261116_photo_tables.md`, decision 1). A link at the end of a path is one way two
  rows come to be one file, and its producer, which lists the path, can see it then.
- The target is recorded as the link holds it, which is what the producer saw. A
  resolved target would be an absolute path naming the producer's machine and folders,
  and would be wrong once they move.
- Optional, and missing means "not known": a producer that does not look for links
  writes none, and a value can be lost on its way into a table that predates the
  column. Rows from several producers are bound into one table, so the meaning is per
  row, not carried by whether the column is present.

## Alternatives considered

- **A logical flag**: says a path is a link, not where it leads. Rejected at the plan
  gate.
- **Leaving links out of the listing**: where a link's target is outside the folders
  listed, its photo would be missing from the rows. Rejected.
- **The producer's own extra column**: it would pass `crt_schema_conform()`, but only
  that producer's readers would know of it, untyped. Rejected: the fact is about
  `path`, half of this table's key.

## Consequences

- A row with `symlink` is not a copy. The table does not say which rows are one file:
  a folder that is a link is never marked, the target text need not name another row,
  and an unmarked row may be a link nobody looked for. A reader that removes copies
  decides from the disk, not from this column alone.
- Marking a linked folder would mean asking every folder on a path whether it is a
  link; it is out of scope here.

## References

- crate#76 (this column), crate#67 (`photo_files`)
- `decisions/nge/20261116_photo_tables.md`
