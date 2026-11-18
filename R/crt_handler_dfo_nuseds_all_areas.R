#' Normalize DFO's NuSEDS All Areas file to its canonical shape
#'
#' Handler for `("dfo", "nuseds_all_areas")`, dispatched by [crt_ingest()]. The
#' file arrives with upper-case column names; the canonical names are the same
#' names in lower case. Values are passed through as read (every column as
#' character), and [crt_schema_conform()] types them from the schema YAML.
#'
#' @param raw A data frame returned by `readr::read_csv()` against the source CSV.
#' @param variant_id `character(1)` the upstream variant [crt_ingest()] matched.
#' @return A tibble with lower-case names, in the file's column order.
#' @keywords internal
#' @noRd
crt_handler_dfo_nuseds_all_areas <- function(raw, variant_id) {
  switch(
    variant_id,
    "2026-06-01" = crt_handler_dfo_nuseds_lower_names(raw),
    cli::cli_abort("Unknown variant_id for dfo/nuseds_all_areas: {variant_id}")
  )
}

crt_handler_dfo_nuseds_lower_names <- function(raw) {
  names(raw) <- tolower(names(raw))
  tibble::as_tibble(raw)
}
