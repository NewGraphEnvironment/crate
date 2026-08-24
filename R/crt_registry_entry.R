# Internal: resolve one (source, file_name) pair to its registry row.
#
# Shared by crt_ingest() and crt_schema_conform() so the "unknown pair" error
# reads the same however a caller arrived, and so the two entry points cannot
# disagree about what is registered.

crt_registry_entry <- function(source, file_name) {
  reg <- crt_registry_load()
  matched <- reg[reg$source == source & reg$file_name == file_name, , drop = FALSE]
  if (nrow(matched) == 0L) {
    cli::cli_abort(c(
      "Unknown (source, file_name) pair: ({source}, {file_name}).",
      "i" = "See {.code crt_files()} for registered entries."
    ))
  }
  matched[1L, , drop = FALSE]
}

# Internal: what kind of registry entry is this?
#
# `file`        - crate reads the source file and dispatches to a handler
# `schema_only` - crate declares the canonical shape but does not read anything
#
# Read through a helper rather than inline so an older registry without the
# column still resolves to the only kind that existed then.

crt_registry_kind <- function(entry) {
  kind <- if ("kind" %in% names(entry)) entry$kind[[1L]] else NA_character_
  if (is.na(kind) || !nzchar(kind)) "file" else kind
}
