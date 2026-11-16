# Research

What is known, kept current: settled designs, methods and measured facts. The story of each
issue is in `planning/archive/`; this directory holds the verdict.

Naming: `<topic>.md`, revised in place, from 2026-11-05.

| file | covers |
|---|---|
| [`provenance_receipt.md`](provenance_receipt.md) | the provenance receipt's design and decisions (crate#43): the four blocks, SHA-256 over RFC 8785, the table canonical form, tolerances, the register, migration, and what implementing JCS needs (a correctly rounded parser; powers of two) |
| [`form_versions.md`](form_versions.md) | which column sets the five fish passage forms were captured with since 2023 (crate#36): read from the sync service's history, the rule that a set counts if records went into it, the counts, how each was checked, and how to re-run it for a new season |
