# Internal: load the bundled registry CSV.
# Single source of truth for both crt_files() (public listing) and
# crt_ingest() (lookup-then-dispatch). Centralizing here avoids duplicated
# system.file() resolution.

crt_registry_load <- function() {
  registry_path <- system.file("extdata/crate_registry.csv", package = "crate")
  if (!nzchar(registry_path)) {
    cli::cli_abort(
      "crate_registry.csv not found in installed package - reinstall crate"
    )
  }
  reg <- readr::read_csv(
    registry_path,
    show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
  tibble::as_tibble(reg)
}
