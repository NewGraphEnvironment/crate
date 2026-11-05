#' Read a provenance receipt
#'
#' @param path Path to a `receipt.json`, or to the directory holding one.
#'
#' @return The receipt as a list, as [jsonlite::read_json()] gives it with
#'   `simplifyVector = FALSE`: objects are named lists, arrays unnamed ones.
#'
#' @seealso [crt_receipt_write()], [crt_receipt_validate()].
#'
#' @examples
#' r <- crt_receipt_read(system.file("extdata", "receipt", "examples", "worked_case",
#'                                   "build_1", package = "crate"))
#' r$recipe$recipe_id
#'
#' @export
crt_receipt_read <- function(path) {
  chk::chk_string(path)
  if (dir.exists(path)) path <- file.path(path, "receipt.json")
  if (!file.exists(path)) {
    cli::cli_abort("No receipt at {.path {path}}.")
  }
  if (file.size(path) == 0) {
    cli::cli_abort("{.path {path}} is empty.")
  }
  x <- tryCatch(
    jsonlite::read_json(path, simplifyVector = FALSE),
    error = function(e) {
      cli::cli_abort("{.path {path}} is not JSON: {conditionMessage(e)}", call = NULL)
    }
  )
  if (!is.list(x) || is.null(names(x)) || !"output" %in% names(x)) {
    cli::cli_abort("{.path {path}} is not a receipt: it has no {.field output} block.")
  }
  v <- x$output$receipt_version
  if (!identical(v, receipt_version())) {
    cli::cli_abort(c(
      "{.path {path}} is receipt version {.val {v %||% 'none'}}.",
      "i" = "This crate reads version {.val {receipt_version()}}."
    ))
  }
  x
}

#' Validate a provenance receipt
#'
#' Checks a receipt against the receipt JSON Schema installed with crate, then
#' recomputes its `recipe_id`, which the schema cannot check.
#'
#' @param x A receipt, as a list from [crt_receipt_read()], or a path to one.
#' @param error If `TRUE` (the default), abort on an invalid receipt, listing what
#'   is wrong; if `FALSE`, return `FALSE` with the problems as attribute `errors`.
#'
#' @return `TRUE`, invisibly, for a valid receipt.
#'
#' @section Requires: the jsonvalidate package.
#'
#' @examples
#' if (requireNamespace("jsonvalidate", quietly = TRUE)) {
#'   crt_receipt_validate(system.file("extdata", "receipt", "examples", "worked_case",
#'                                    "build_1", package = "crate"))
#' }
#'
#' @export
crt_receipt_validate <- function(x, error = TRUE) {
  chk::chk_flag(error)
  if (!requireNamespace("jsonvalidate", quietly = TRUE)) {
    cli::cli_abort(c(
      "Validating a receipt needs the {.pkg jsonvalidate} package.",
      "i" = "Install it with {.code install.packages(\"jsonvalidate\")}."
    ))
  }
  if (is.character(x)) x <- crt_receipt_read(x)
  if (!is.list(x)) {
    cli::cli_abort("{.arg x} must be a receipt or a path to one.")
  }
  schema <- system.file("extdata", "receipt", "schema", paste0("v", receipt_version()),
                        "schema.json", package = "crate", mustWork = TRUE)
  txt <- crt_receipt_jcs(x)
  ok <- jsonvalidate::json_validate(txt, schema, engine = "ajv", verbose = TRUE)
  problems <- character()
  if (!ok) {
    e <- attr(ok, "errors")
    problems <- paste0(e$instancePath %||% e$dataPath, " ", e$message)
  } else if (!is.null(x$recipe$recipe_id)) {
    want <- crt_receipt_recipe_id(x$recipe)
    if (!identical(want, x$recipe$recipe_id)) {
      problems <- paste0("/recipe/recipe_id is ", x$recipe$recipe_id,
                         " but the recipe hashes to ", want)
    }
  }
  if (!length(problems)) return(invisible(TRUE))
  if (error) {
    cli::cli_abort(c("The receipt is not valid.", stats::setNames(problems, rep("x", length(problems)))))
  }
  structure(FALSE, errors = problems)
}
