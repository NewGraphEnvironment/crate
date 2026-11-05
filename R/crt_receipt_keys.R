#' Read a package's receipt declaration
#'
#' Each package declares, as data beside the code that writes an output, what only
#' it knows about that output's receipt: which inputs, settings and config files are
#' its recipe, which tables are fingerprinted with what tolerances, which summary
#' values it reports, and any change to what a difference in a field does. crate reads
#' the declaration; the package never re-implements the hashing (crate#43).
#'
#' @section The declaration:
#' A YAML file:
#'
#' ```yaml
#' receipt_keys: 1
#' output: link_evidence
#' recipe:
#'   config_files: [inst/method/settings.csv]
#'   settings: [species, watershed_group]
#'   inputs: [flow, fwa_stream_networks]
#'   seed: false
#' result:
#'   tables:
#'     access_check:
#'       tolerance: {km: 1.0e-9}
#'     visits_link: {}
#'   summary:
#'     rows: {}
#'     km_total: {tolerance: 1.0e-6}
#' register:
#'   output.schema: record
#' ```
#'
#' Write a tolerance with a decimal point (`1.0e-9`): YAML reads `1e-9` as a string,
#' which is accepted, but `1.0e-9` is a number everywhere. `register` may only soften
#' or harden fields outside the recipe: every recipe field refuses, because
#' `recipe_id` covers it.
#'
#' Pass the result to [crt_receipt_write()] as `keys`, which then takes the
#' tolerances from it and refuses inputs, settings, config files or tables the
#' declaration does not list, or lacks ones it does; and to [crt_receipt_compare()],
#' which applies `register`.
#'
#' @param path Path to the YAML declaration.
#'
#' @return A list of class `crt_receipt_keys`: `output`, `config_files`, `settings`,
#'   `inputs`, `seed`, `tables`, `summary`, `tolerance` and `register`.
#'
#' @examples
#' keys <- crt_receipt_keys(system.file("extdata", "receipt", "examples",
#'                                      "receipt_keys.yaml", package = "crate"))
#' keys$tolerance
#'
#' @export
crt_receipt_keys <- function(path) {
  chk::chk_file(path)
  y <- tryCatch(
    yaml::read_yaml(path),
    error = function(e) cli::cli_abort("{.path {path}} is not YAML: {conditionMessage(e)}", call = NULL)
  )
  if (!is.list(y) || !identical(y$receipt_keys, 1L)) {
    cli::cli_abort(c(
      "{.path {path}} is not a receipt declaration.",
      "i" = "It must begin with {.code receipt_keys: 1}."
    ))
  }
  receipt_known(y, c("receipt_keys", "output", "recipe", "result", "register"), "the declaration")
  chk::chk_string(y$output, x_name = "output")
  recipe <- y$recipe %||% list()
  result <- y$result %||% list()
  receipt_known(recipe, c("config_files", "settings", "inputs", "seed"), "recipe")
  receipt_known(result, c("tables", "summary"), "result")

  names_of <- function(x, what) {
    if (is.null(x)) return(character())
    if (!is.character(x) || anyNA(x) || any(!nzchar(x))) {
      cli::cli_abort("{.field {what}} must be a list of names.")
    }
    if (anyDuplicated(x)) cli::cli_abort("{.field {what}} repeats {.val {unique(x[duplicated(x)])}}.")
    x
  }
  seed <- recipe$seed %||% FALSE
  chk::chk_flag(seed, x_name = "recipe$seed")

  tables <- result$tables %||% list()
  summary <- result$summary %||% list()
  for (what in c("tables", "summary")) {
    x <- get(what)
    if (length(x) && (!is.list(x) || is.null(names(x)))) {
      cli::cli_abort("{.field result${what}} must map each name to its settings.")
    }
    for (nm in names(x)) {
      e <- x[[nm]] %||% list()
      receipt_known(e, "tolerance", paste0("result$", what, "$", nm))
    }
  }
  tol_tables <- lapply(tables, function(e) e$tolerance)
  tol_tables <- tol_tables[!vapply(tol_tables, is.null, TRUE)]
  tol_summary <- lapply(summary, function(e) e$tolerance)
  tol_summary <- tol_summary[!vapply(tol_summary, is.null, TRUE)]
  tolerance <- receipt_tolerance(list(tables = tol_tables, summary = tol_summary))

  register <- y$register %||% list()
  if (length(register) && (!is.list(register) || is.null(names(register)))) {
    cli::cli_abort("{.field register} must map a field path to refuse, warn or record.")
  }
  register <- tibble::tibble(field = as.character(names(register)),
                             action = as.character(unlist(register, use.names = FALSE)))
  bad <- register$field[!register$action %in% c("refuse", "warn", "record")]
  if (length(bad)) {
    cli::cli_abort("{.field register} actions must be refuse, warn or record: {.val {bad}}.")
  }
  in_recipe <- register$field[startsWith(register$field, "recipe.")]
  if (length(in_recipe)) {
    cli::cli_abort(c(
      "{.field register} cannot change recipe fields: {.val {in_recipe}}.",
      "i" = "Every recipe field refuses, because {.field recipe_id} covers it."
    ))
  }

  structure(
    list(
      output = y$output,
      config_files = names_of(recipe$config_files, "recipe$config_files"),
      settings = names_of(recipe$settings, "recipe$settings"),
      inputs = names_of(recipe$inputs, "recipe$inputs"),
      seed = seed,
      tables = names_of(names(tables), "result$tables"),
      summary = names_of(names(summary), "result$summary"),
      tolerance = tolerance,
      register = register
    ),
    class = "crt_receipt_keys"
  )
}

# The values a writer supplies against what its package declared.
receipt_keys_check <- function(keys, rec, tables, summary) {
  check <- function(got, want, what) {
    extra <- setdiff(got, want)
    missing_ <- setdiff(want, got)
    if (length(extra) || length(missing_)) {
      cli::cli_abort(c(
        "The {what} supplied do not match the declaration for {.val {keys$output}}.",
        "x" = if (length(missing_)) "Declared but not supplied: {.val {missing_}}.",
        "x" = if (length(extra)) "Supplied but not declared: {.val {extra}}."
      ))
    }
  }
  check(names(rec$inputs), keys$inputs, "inputs")
  check(names(rec$config$settings), keys$settings, "settings")
  check(names(rec$config$files), keys$config_files, "config files")
  check(names(tables), keys$tables, "tables")
  check(names(summary), keys$summary, "summary values")
  if (keys$seed && is.null(rec$seed)) {
    cli::cli_abort("The declaration for {.val {keys$output}} says it has a seed, and none was supplied.")
  }
  if (!keys$seed && !is.null(rec$seed)) {
    cli::cli_abort("A seed was supplied, but the declaration for {.val {keys$output}} says it has none.")
  }
  invisible(TRUE)
}
