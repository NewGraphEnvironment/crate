#' Internal handler dispatcher: bcfp/user_habitat_classification
#'
#' Called by [crt_ingest()] via the registry's `handler_fn` lookup. Dispatches
#' on `variant_id` (matched upstream from schema YAML) to the appropriate
#' normalization path. Returns canonical wide-shape tibble.
#'
#' Not exported. See [crt_ingest()] for the public API.
#'
#' @param raw A data frame returned by `readr::read_csv()` against the source CSV.
#' @param variant_id Character. The upstream variant id matched by [crt_ingest()]
#'   against the schema YAML. One of: `"2026-04-26-wide"`, `"pre-2026-04-26-long"`.
#' @return A tibble in canonical wide shape (per
#'   `inst/extdata/schemas/bcfp/user_habitat_classification.yaml`).
#' @keywords internal
crt_handler_bcfp_user_habitat_classification <- function(raw, variant_id) {
  switch(
    variant_id,
    "2026-04-26-wide" = crt_handler_bcfp_uhc_identity(raw),
    "pre-2026-04-26-long" = crt_handler_bcfp_uhc_pivot_long_to_wide(raw),
    cli::cli_abort("Unknown variant_id for bcfp/user_habitat_classification: {variant_id}")
  )
}

#' @keywords internal
#' @rdname crt_handler_bcfp_user_habitat_classification
#' @noRd
# Wide-input identity passthrough — validates required cols and returns
# tibble in canonical column order.
crt_handler_bcfp_uhc_identity <- function(raw) {
  required <- c(
    "blue_line_key", "downstream_route_measure", "upstream_route_measure",
    "watershed_group_code", "species_code", "spawning", "rearing"
  )
  missing <- setdiff(required, names(raw))
  if (length(missing) > 0L) {
    cli::cli_abort(
      "Wide-variant input missing required cols: {paste(missing, collapse = ', ')}"
    )
  }
  optional <- c("reviewer_name", "review_date", "source", "notes")
  cols_in_order <- c(required, intersect(optional, names(raw)))
  tibble::as_tibble(raw[, cols_in_order, drop = FALSE])
}

# Long-input pivot to wide-canonical.
#
# Long shape (pre-2026-04-26): one row per (segment x species x habitat_type)
# tuple. habitat_type ∈ {"spawning", "rearing"}; habitat_ind ∈ {"t", "f"} text.
#
# Wide canonical: one row per (segment x species), separate spawning + rearing
# integer columns. Metadata cols (reviewer_name, review_date, source, notes)
# are included as id_cols in the pivot — paired spawning + rearing long rows
# for the same (segment x species) collapse to one wide row IF their metadata
# matches (the typical case in pre-2026-04-26 upstream data). Divergent
# metadata across paired long rows would split into two wide rows, violating
# the "one row per (segment x species)" canonical contract — known limitation
# that has never bitten real-world data. If it does, refactor to aggregate
# metadata strictly by data keys (blue_line_key, route measures, watershed,
# species_code) using a "first non-NA per group" rule.
#' @keywords internal
#' @rdname crt_handler_bcfp_user_habitat_classification
#' @noRd
crt_handler_bcfp_uhc_pivot_long_to_wide <- function(raw) {
  required <- c(
    "blue_line_key", "downstream_route_measure", "upstream_route_measure",
    "watershed_group_code", "species_code", "habitat_type", "habitat_ind"
  )
  missing <- setdiff(required, names(raw))
  if (length(missing) > 0L) {
    cli::cli_abort(
      "Long-variant input missing required cols: {paste(missing, collapse = ', ')}"
    )
  }

  # Map text habitat_ind → integer (1 = true; NA = false/blank)
  ind_norm <- tolower(trimws(as.character(raw$habitat_ind)))
  raw$.ind_int <- ifelse(
    ind_norm %in% c("t", "true", "1"),
    1L,
    NA_integer_
  )

  optional <- intersect(c("reviewer_name", "review_date", "source", "notes"), names(raw))
  id_cols <- c(
    "blue_line_key", "downstream_route_measure", "upstream_route_measure",
    "watershed_group_code", "species_code", optional
  )

  wide <- tidyr::pivot_wider(
    raw,
    id_cols = dplyr::all_of(id_cols),
    names_from = "habitat_type",
    values_from = ".ind_int",
    values_fn = function(x) if (length(x) > 0L) x[[1L]] else NA_integer_
  )

  # Ensure both habitat columns exist even if input had only one habitat_type
  if (!"spawning" %in% names(wide)) wide$spawning <- NA_integer_
  if (!"rearing" %in% names(wide)) wide$rearing <- NA_integer_

  cols_in_order <- c(
    "blue_line_key", "downstream_route_measure", "upstream_route_measure",
    "watershed_group_code", "species_code", "spawning", "rearing", optional
  )
  tibble::as_tibble(wide[, cols_in_order, drop = FALSE])
}
