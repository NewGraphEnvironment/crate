#' Read an older provenance record as a receipt
#'
#' Reads a `manifest.json` or `provenance.json` written before its package moved to
#' receipts, through the receipt mapping table
#' (`inst/extdata/receipt/mapping.csv`), so existing records stay readable in the
#' receipt's keys while writers converge forward, each when it is next touched
#' (crate#43).
#'
#' A migrated receipt has no recipe identity: an older record lacks fields a recipe
#' needs (resolved settings, a seed, inputs' own ids), so `recipe.recipe_id` is null,
#' `output.migrated_from` names the format, and [crt_receipt_compare()] reports its
#' recipe as unknown. Fields the mapping places nowhere are kept verbatim in
#' `context.legacy`, keyed by their path in the record. Fields the mapping does not
#' know at all go there too, and are reported with a warning of class
#' `crate_receipt_unmapped`, so nothing is dropped silently.
#'
#' @section Formats:
#' * `"link manifest.json"`: link's export manifest.
#' * `"floodplains provenance.json"`: one section of floodplains' per-area record,
#'   named by `section`, such as `"floodplain/all_ff02"` or `"network/CO3"`.
#'
#' The mapping table also lists STAC's keys (`file:checksum`, `file:size`,
#' `processing:software`, `processing:datetime`) beside the receipt keys they mirror.
#'
#' @param x Path to the record, or the record as a list from [jsonlite::read_json()].
#' @param format The record's format; see Formats.
#' @param section For a record holding several outputs: the path to one, its parts
#'   separated by `/`.
#' @param name The output's name, when the record carries none. Defaults to
#'   `section` for a section of a record.
#' @param time UTC time in ISO 8601 with a trailing `Z`, when the record carries none.
#' @param path Optional: where to write the receipt, a file or a directory (which gets
#'   `receipt.json`). It is written as [crt_receipt_write()] writes, canonical JSON
#'   pretty-printed, so [crt_receipt_read()] reads it back to the same bytes.
#'
#' @return A receipt, as a list, invisibly when `path` is given. Compare it with
#'   [crt_receipt_compare()].
#'
#' @examples
#' rec <- system.file("extdata", "receipt", "examples", "legacy", "link_manifest.json",
#'                    package = "crate")
#' r <- crt_receipt_migrate(rec, "link manifest.json")
#' r$recipe$code
#'
#' @export
crt_receipt_migrate <- function(x, format, section = NULL, name = NULL, time = NULL, path = NULL) {
  mapping <- receipt_mapping()
  formats <- setdiff(unique(mapping$source_format), c("any record", "STAC item"))
  chk::chk_string(format)
  if (!format %in% formats) {
    cli::cli_abort(c(
      "{.val {format}} is not a format {.fn crt_receipt_migrate} reads.",
      "i" = "Formats: {.val {formats}}."
    ))
  }
  if (is.character(x)) {
    chk::chk_file(x)
    x <- jsonlite::read_json(x, simplifyVector = FALSE)
  }
  if (!is.list(x) || is.null(names(x))) {
    cli::cli_abort("{.arg x} must be a JSON object, or a path to one.")
  }

  rows <- mapping[mapping$source_format %in% c(format, "any record"), ]
  # A part of the record mapped whole to legacy (link's parts, configs) is kept whole,
  # not walked into fields that a name-only rule could misread.
  literal <- !grepl("[*{]", rows$source_field)
  whole <- rows[rows$source_format == format & rows$receipt_key == "context.legacy" & literal, ]
  stop_at <- function(path) {
    any(vapply(strsplit(whole$source_field, ".", fixed = TRUE), function(p) {
      !is.null(receipt_pattern_match(p, path))
    }, TRUE))
  }
  fields <- receipt_migrate_fields(x, section, stop_at)
  receipt <- list(
    output = list(name = name, scope = NULL, receipt_version = receipt_version(),
                  schema = NULL, migrated_from = format),
    recipe = list(recipe_id = NULL),
    result = list(fingerprint = receipt_object(NULL), parts = receipt_object(NULL),
                  summary = receipt_object(NULL),
                  tolerance = list(tables = receipt_object(NULL), summary = receipt_object(NULL))),
    context = list(time = time)
  )
  legacy <- list()
  unmapped <- character()
  for (f in fields) {
    hit <- receipt_mapping_match(rows, format, f$path)
    if (is.null(hit)) {
      unmapped <- c(unmapped, f$label)
      legacy[f$label] <- list(f$value)
      next
    }
    value <- receipt_mapping_transform(f$value, hit$transform)
    if (identical(hit$key, "context.legacy") || is.null(value)) {
      legacy[f$label] <- list(f$value)
      next
    }
    # Two fields mapped to one key keep the first; the other is not lost.
    held <- receipt_get_key(receipt, hit$key)
    if (!is.null(held) && !identical(held, value)) {
      legacy[f$label] <- list(f$value)
      next
    }
    receipt <- receipt_set_key(receipt, hit$key, value)
  }

  receipt <- receipt_migrate_tidy(receipt, legacy)
  # A section of a record holding several outputs is named by its path there.
  if (is.null(receipt$output$name) && !is.null(section)) receipt$output$name <- section
  if (is.null(receipt$output$name)) {
    cli::cli_abort("The record names no output; pass {.arg name}.")
  }
  if (is.null(receipt$context$time)) {
    cli::cli_abort("The record carries no time; pass {.arg time}.")
  }
  if (length(unmapped)) {
    cli::cli_warn(
      c(paste("{length(unmapped)} field{?s} of the {format} {?is/are} not in the receipt mapping;",
              "kept in {.field context.legacy}."),
        "i" = "{.val {unmapped}}"),
      class = "crate_receipt_unmapped"
    )
  }
  if (!is.null(path)) {
    chk::chk_string(path)
    if (dir.exists(path)) path <- file.path(path, "receipt.json")
    receipt_write_file(receipt, path)
    return(invisible(receipt))
  }
  receipt
}

receipt_mapping <- function() {
  path <- system.file("extdata", "receipt", "mapping.csv", package = "crate", mustWork = TRUE)
  m <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8", na.strings = character())
  m
}

# The record's leaves, as list(path = <segments>, label = "a.b.c", value). A selected
# section is read relative to itself, beside the record's top-level scalars. Arrays and
# empty objects are leaves.
receipt_migrate_fields <- function(x, section, stop_at = function(path) FALSE) {
  out <- list()
  walk <- function(v, path) {
    if (is.list(v) && !is.null(names(v)) && length(v) && !(length(path) && stop_at(path))) {
      for (k in names(v)) walk(v[[k]], c(path, k))
    } else {
      out[[length(out) + 1L]] <<- list(path = path, label = paste(path, collapse = "."), value = v)
    }
  }
  if (is.null(section)) {
    walk(x, character())
    return(out)
  }
  chk::chk_string(section)
  segs <- strsplit(section, "/", fixed = TRUE)[[1]]
  node <- x
  for (s in segs) {
    if (!is.list(node) || !s %in% names(node)) {
      cli::cli_abort("The record has no section {.val {section}}.")
    }
    node <- node[[s]]
  }
  for (k in names(x)) {
    if (!is.list(x[[k]])) walk(x[[k]], k)
  }
  walk(node, character())
  out
}

# The first mapping row matching a path: the format's own rows by the whole path,
# then the rows for any record by the field's last name.
receipt_mapping_match <- function(rows, format, path) {
  for (i in seq_len(nrow(rows))) {
    pat <- strsplit(rows$source_field[i], ".", fixed = TRUE)[[1]]
    target <- if (rows$source_format[i] == "any record") utils::tail(path, 1L) else path
    caps <- receipt_pattern_match(pat, target)
    if (is.null(caps)) next
    key <- rows$receipt_key[i]
    for (nm in names(caps)) key <- gsub(paste0("[", nm, "]"), paste0("[", caps[[nm]], "]"), key, fixed = TRUE)
    return(list(key = key, transform = rows$transform[i]))
  }
  NULL
}

# Captures from matching pattern segments to path segments: `*` takes a whole segment,
# `{name}` the part of a segment it stands for. NULL when they do not match.
receipt_pattern_match <- function(pat, path) {
  if (length(pat) != length(path)) return(NULL)
  caps <- list()
  for (i in seq_along(pat)) {
    p <- pat[i]
    if (p == "*") {
      caps[["*"]] <- path[i]
    } else if (grepl("{", p, fixed = TRUE)) {
      nm <- sub("^.*\\{([a-z_]+)\\}.*$", "\\1", p)
      parts <- strsplit(p, paste0("{", nm, "}"), fixed = TRUE)[[1]]
      pre <- parts[1]
      post <- if (length(parts) > 1) parts[2] else ""
      re <- paste0("^\\Q", pre, "\\E(.+)\\Q", post, "\\E$")
      if (!grepl(re, path[i], perl = TRUE)) return(NULL)
      caps[[paste0("{", nm, "}")]] <- sub(re, "\\1", path[i], perl = TRUE)
    } else if (!identical(p, path[i])) {
      return(NULL)
    }
  }
  caps
}

# NULL when the value cannot take the receipt key's form; it then goes to legacy.
receipt_mapping_transform <- function(value, transform) {
  if (!nzchar(transform)) return(value)
  switch(transform,
    strip_prefix = if (is.character(value)) sub("^sha256:", "", value),
    multihash = if (is.character(value) && grepl("^1220[0-9a-f]{64}$", value)) substring(value, 5),
    number = if (is.numeric(value) && length(value) == 1L) value,
    value
  )
}

receipt_key_segments <- function(key) {
  segs <- regmatches(key, gregexpr("\\[[^]]*\\]|[^.\\[]+", key))[[1]]
  sub("^\\[(.*)\\]$", "\\1", segs)
}

receipt_get_key <- function(x, key) {
  for (s in receipt_key_segments(key)) {
    if (!is.list(x) || !s %in% names(x)) return(NULL)
    x <- x[[s]]
  }
  x
}

# Set a value at a receipt key such as recipe.code[flooded].commit.
receipt_set_key <- function(x, key, value) {
  segs <- receipt_key_segments(key)
  set <- function(node, s) {
    if (length(s) == 1L) {
      node[[s]] <- value
      return(node)
    }
    child <- if (is.list(node) && s[1] %in% names(node)) node[[s[1]]] else list()
    node[[s[1]]] <- set(child, s[-1])
    node
  }
  set(x, segs)
}

# Place what the schema would refuse into legacy rather than write an invalid receipt.
receipt_migrate_tidy <- function(receipt, legacy) {
  code <- receipt$recipe$code
  for (repo in names(code)) {
    e <- code[[repo]]
    ok <- (is.null(e$commit) || (is.character(e$commit) && grepl("^[0-9a-f]{7,40}$", e$commit))) &&
      (is.null(e$dirty) || is.logical(e$dirty)) &&
      (is.null(e$version) || is.character(e$version))
    if (!ok) {
      legacy[[paste0("recipe.code.", repo)]] <- e
      code[[repo]] <- NULL
    }
  }
  if (!is.null(code)) receipt$recipe$code <- receipt_object(code)
  inputs <- receipt$recipe$inputs
  for (nm in names(inputs)) {
    if (!grepl("^[0-9a-f]{64}$", inputs[[nm]]$sha256 %||% "")) {
      legacy[[paste0("recipe.inputs.", nm)]] <- inputs[[nm]]
      inputs[[nm]] <- NULL
    }
  }
  if (!is.null(inputs)) receipt$recipe$inputs <- receipt_object(inputs)
  tc <- receipt$context$toolchain
  if (!is.null(tc)) {
    keep <- vapply(tc, function(v) is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v), TRUE)
    for (nm in names(tc)[!keep]) legacy[[paste0("context.toolchain.", nm)]] <- tc[[nm]]
    receipt$context$toolchain <- receipt_object(tc[keep])
  }
  if (length(legacy)) receipt$context$legacy <- legacy
  # recipe_id last and null: a migrated receipt claims no identity.
  rid <- receipt$recipe
  rid[["recipe_id"]] <- NULL
  receipt$recipe <- c(rid, list(recipe_id = NULL))
  receipt
}
