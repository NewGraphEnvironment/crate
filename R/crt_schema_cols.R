#' What each column of a registered schema means
#'
#' Returns the schema's column declarations as a tibble, one row per column in
#' schema order: type, whether it is required, and what the schema says the
#' column means, including the allowed values a QC rule can check a record
#' against.
#'
#' This is the reading of a schema meant for other code. A form builder takes
#' the column list, types and vocabularies from here and adds only how the form
#' shows them; a QC rule takes `values` and `range_min` / `range_max` and flags a
#' record whose value falls outside them. Neither has to parse the YAML.
#'
#' @param source Character. Source family code (e.g. `"nge"`).
#' @param file_name Character. Logical file name (e.g. `"form_pscis"`).
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{`name`, `type`, `required`}{as declared; see [crt_schema_conform()]}
#'     \item{`units`}{unit of a measurement, e.g. `"m"`, else `NA`}
#'     \item{`values`}{list of character vectors: the values the column may
#'       store, or `character(0)` when the schema sets none}
#'     \item{`labels`}{list of character vectors, parallel to `values`: what a
#'       form displays for each. The same as `values` unless the vocabulary is
#'       coded, e.g. stores `"4"` and displays `"Coniferous Trees"`}
#'     \item{`range_min`, `range_max`}{numeric bounds, else `NA`}
#'     \item{`relative_to`}{for a column holding file paths, what they are
#'       relative to, else `NA`}
#'     \item{`null`}{what a null means in this column when it means something
#'       other than "not recorded", else `NA`}
#'     \item{`notes`}{the schema's description of the column, else `NA`}
#'   }
#'
#' @details
#' `values` and the range are declarations, not checks: [crt_schema_conform()]
#' does not refuse a value outside them. A value typed or dictated outside a
#' vocabulary is a record to flag, not one to drop.
#'
#' @examples
#' cols <- crt_schema_cols("nge", "form_capture")
#' cols[, c("name", "type", "required")]
#'
#' @seealso [crt_schema_grade()] for which records can answer a question,
#'   [crt_files()] to list registered entries.
#' @export
crt_schema_cols <- function(source, file_name) {
  crt_schema_cols_tbl(crt_schema_get(source, file_name))
}

# Internal worker over a parsed schema, so the reading can be tested on a
# schema built for the purpose.
crt_schema_cols_tbl <- function(schema) {
  cols <- schema[["canonical"]][["cols"]]
  chr <- function(key) {
    vapply(cols, function(col) {
      v <- col[[key]]
      if (is.null(v)) NA_character_ else as.character(v)
    }, character(1))
  }
  bound <- function(i) {
    vapply(cols, function(col) {
      r <- col[["range"]]
      if (is.null(r)) NA_real_ else as.numeric(unlist(r))[[i]]
    }, numeric(1))
  }
  # A vocabulary entry is either a bare stored value or a {value, label} map
  # for a coded one. as.character() rather than trusting the YAML type: a
  # vocabulary of codes reads back as integers.
  vocab <- function(col, part) {
    v <- col[["values"]]
    if (is.null(v)) return(character(0))
    vapply(as.list(v), function(e) {
      if (is.list(e)) as.character(if (is.null(e[[part]])) e[["value"]] else e[[part]])
      else as.character(e)
    }, character(1))
  }

  tibble::tibble(
    name = chr("name"),
    type = chr("type"),
    required = vapply(cols, function(col) isTRUE(col[["required"]]), logical(1)),
    units = chr("units"),
    values = lapply(cols, vocab, part = "value"),
    labels = lapply(cols, vocab, part = "label"),
    range_min = bound(1L),
    range_max = bound(2L),
    relative_to = chr("relative_to"),
    null = chr("null"),
    notes = chr("notes")
  )
}
