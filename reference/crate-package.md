# crate: Canonical Schemas for Changing Data and Provenance Receipts

Declares a canonical shape for each file or table it registers, reads a
registered file to that shape whichever known layout arrives, and holds
data read some other way to the same shape, so a change in a registered
file's columns or layout is fixed once in crate rather than in every
reader downstream. Also holds the provenance receipt contract: a JSON
Schema, RFC 8785 canonical JSON, a table fingerprint and test vectors,
with R functions that write receipts and compare two builds as
identical, equivalent within a declared tolerance, or different. Under
active development.

## See also

Useful links:

- <https://github.com/NewGraphEnvironment/crate>

- <https://newgraphenvironment.github.io/crate/>

- Report bugs at <https://github.com/NewGraphEnvironment/crate/issues>

## Author

**Maintainer**: Allan Irvine <al@newgraphenvironment.com>
([ORCID](https://orcid.org/0000-0002-3495-2128)) (New Graph Environment
Ltd.)

Other contributors:

- New Graph Environment Ltd. \[copyright holder, funder\]
