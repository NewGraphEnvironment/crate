#' Internal handler dispatcher: nge/fish_data
#'
#' Called by [crt_ingest()] via the registry's `handler_fn` lookup. Dispatches
#' on `variant_id` (matched upstream from schema YAML) to the rename for that
#' file shape, then returns every canonical column, in schema order, with a
#' column the shape did not record present and null. So every season comes
#' back with the same columns, and even [rbind()] stacks them.
#'
#' Not exported. See [crt_ingest()] for the public API.
#'
#' @param raw A data frame returned by `readr::read_csv()` against the source CSV.
#' @param variant_id Character. The upstream variant id matched by [crt_ingest()]
#'   against the schema YAML. One of: `"2023-peace-6col"`, `"2023-skeena-7col"`,
#'   `"2024-field-sheet"`.
#' @return A tibble with the canonical columns of
#'   `inst/extdata/schemas/nge/fish_data.yaml`, untyped: [crt_ingest()] types it
#'   through [crt_schema_conform()].
#' @keywords internal
crt_handler_nge_fish_data <- function(raw, variant_id) {
  renamed <- switch(
    variant_id,
    "2023-peace-6col" = ,
    "2023-skeena-7col" = crt_handler_nge_fish_rename_2023(raw),
    "2024-field-sheet" = crt_handler_nge_fish_rename_2024(raw),
    cli::cli_abort("Unknown variant_id for nge/fish_data: {variant_id}")
  )
  crt_handler_nge_fish_fill(renamed)
}

# 2023: the individual-fish file kept ready for the FISS template. Species is
# `common_name`, the Skeena file has the pass as `haul_pass`, and PIT tags are
# written into `comments` rather than a column of their own.
crt_handler_nge_fish_rename_2023 <- function(raw) {
  names(raw)[names(raw) == "common_name"] <- "species"
  names(raw)[names(raw) == "haul_pass"] <- "haul_number_pass_number"
  raw$pit_tag_id <- crt_handler_nge_fish_pit_tag(raw$comments)
  raw
}

# 2024 onward: the field spreadsheet, with unitless `length` and `weight`, the
# pass as `pass_number`, and the day as a midnight timestamp. Tags are upper
# cased, as 2023's are, so a recapture joins whichever way a code was typed.
crt_handler_nge_fish_rename_2024 <- function(raw) {
  renames <- c(
    pass_number = "haul_number_pass_number",
    length = "length_mm",
    weight = "weight_g"
  )
  hit <- names(raw) %in% names(renames)
  names(raw)[hit] <- renames[names(raw)[hit]]
  raw$date <- crt_handler_nge_fish_day(raw$date)
  raw$pit_tag_id <- toupper(as.character(raw$pit_tag_id))
  raw
}

# Every canonical column, in schema order. Read from the schema so the column
# list lives in one place. A column the rename left unmapped is a rename table
# out of step with the schema's variants: abort rather than drop it, or the
# fill below would put an all-NA canonical column in its place.
crt_handler_nge_fish_fill <- function(df) {
  schema <- crt_schema_get("nge", "fish_data")
  cols <- vapply(schema$canonical$cols, function(col) col$name, character(1))
  unmapped <- setdiff(names(df), cols)
  if (length(unmapped)) {
    cli::cli_abort(
      "nge/fish_data handler left {.field {unmapped}} unmapped to a canonical column."
    )
  }
  for (col in setdiff(cols, names(df))) {
    df[[col]] <- rep(NA, nrow(df))
  }
  tibble::as_tibble(df[, cols, drop = FALSE])
}

# A PIT tag code is `3DD.` and ten hex digits. Read one out of free text, upper
# cased. A comment with no full code, or with two different ones, gives NA: a
# partial code (`3DD.003E192B9I`) is left in `comments` for review, not guessed.
crt_handler_nge_fish_pit_tag <- function(comments) {
  x <- as.character(comments)
  found <- regmatches(
    x,
    gregexpr("(?<![0-9A-Fa-f])3DD[.][0-9A-Fa-f]{10}(?![0-9A-Fa-f])", x, perl = TRUE, ignore.case = TRUE)
  )
  vapply(found, function(codes) {
    codes <- unique(toupper(codes))
    if (length(codes) == 1L) codes else NA_character_
  }, character(1))
}

# The sampling day as ISO `YYYY-MM-DD`. The spreadsheet stores a day as a
# midnight UTC timestamp, which readr reads as POSIXct. A time of day other
# than midnight means the column is not the day this assumes, so abort rather
# than drop it. `format()` rather than `as.character()`, which formats a
# POSIXct per value from R 4.3 and per column before it.
crt_handler_nge_fish_day <- function(x) {
  if (inherits(x, "POSIXct")) {
    clock <- format(x, "%H:%M:%S", tz = "UTC")
    timed <- unique(clock[!is.na(clock) & clock != "00:00:00"])
    if (length(timed)) {
      cli::cli_abort("{.field date} carries a time of day ({.val {timed}}); expected a day.")
    }
    return(format(x, "%Y-%m-%d", tz = "UTC"))
  }
  if (inherits(x, "Date")) {
    return(format(x, "%Y-%m-%d"))
  }
  x <- as.character(x)
  ok <- is.na(x) | grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}(T00:00:00Z?)?$", x)
  if (!all(ok)) {
    cli::cli_abort("{.field date} value{?s} {.val {unique(x[!ok])}} {?is/are} not a day (YYYY-MM-DD).")
  }
  substr(x, 1L, 10L)
}
