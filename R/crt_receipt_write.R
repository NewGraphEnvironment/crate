#' Write a provenance receipt
#'
#' Writes `receipt.json` for one output: what it is, how it was made, what came out,
#' and where and when. The package supplies the values it knows; this function
#' computes everything that must agree byte for byte across implementations: the
#' `recipe_id`, each table's fingerprint, each part's size and SHA-256, and the
#' config files' SHA-256 (crate#43).
#'
#' @section The blocks:
#' * `output`: `name`, and optionally `scope` (the partition: a watershed group, a
#'   region) and `schema` (the crate schema the output conforms to).
#' * `recipe`: `code`, a list keyed by repository of `list(commit, version, dirty)`,
#'   with `commit` the full 40-character SHA; `config`, a list of `files` (paths,
#'   hashed here; named to set the key, otherwise keyed by the path as given) and
#'   `settings` (the resolved run settings, written verbatim: wrap a length-one
#'   vector in [I()] to keep it an array); `inputs`, keyed by input name, each
#'   exactly one of `list(recipe_id = )`, `list(version_id = )`, `list(sha256 = )`
#'   or `list(none = "why")`; and `seed`, an integer or `NULL`.
#' * `result`: `tables`, a named list of data frames to fingerprint; `parts`, the
#'   output's files as paths relative to `dir`; `summary`, named numbers such as
#'   `rows` or `km_total`; and `tolerance`, `list(tables = list(<table> =
#'   list(<column> = 1e-9)), summary = list(<name> = 1e-6))`.
#' * `context`: anything of `run` (identifiers), `session`, `inputs` (each input's
#'   own result, for reporting), `toolchain` and `time`. `time` defaults to now, in
#'   UTC; `toolchain` is filled with R's version and, when loaded, GDAL's, terra's,
#'   sf's and arrow's, and entries given here win. The host is recorded unless
#'   `publish = TRUE`.
#'
#' Toolchain versions and every other part of `context` are never part of an
#' identity: a GDAL upgrade alone leaves `recipe_id` unchanged, and the comparison
#' decides from the result whether the output still agrees.
#'
#' @param dir Directory to write `receipt.json` into: the output's directory. `parts`
#'   are relative to it.
#' @param output,recipe,result,context Named lists, one per block (see above).
#' @param keys Optional: the package's declaration, from [crt_receipt_keys()]. When
#'   given, the tolerances come from it and the inputs, settings, config files and
#'   tables supplied must be exactly those it declares.
#' @param lockfile Path to a lockfile whose SHA-256 is recorded in `context`, or
#'   `NULL`. Defaults to `renv.lock` in the working directory when one exists.
#' @param publish `TRUE` for a receipt that will be published: leaves the host out.
#'
#' @return The receipt, as a list, invisibly. The file is `file.path(dir,
#'   "receipt.json")`.
#'
#' @seealso [crt_receipt_read()], [crt_receipt_validate()], [crt_receipt_compare()],
#'   [crt_table_fingerprint()].
#'
#' @examples
#' dir <- file.path(tempdir(), "evidence")
#' dir.create(dir, showWarnings = FALSE)
#' access <- data.frame(segment = c("s1", "s2"), km = c(12.3456789012, 7.25))
#' write.csv(access, file.path(dir, "access_check.csv"), row.names = FALSE)
#'
#' r <- crt_receipt_write(
#'   dir,
#'   output = list(name = "link_evidence", scope = "BULK"),
#'   recipe = list(
#'     code = list(link = list(commit = strrep("a", 40), version = "0.31.2", dirty = FALSE)),
#'     config = list(settings = list(species = I("CO"))),
#'     inputs = list(fwa = list(version_id = "3HL4kqtJlcpXroDTDmJ"))
#'   ),
#'   result = list(
#'     tables = list(access_check = access),
#'     parts = "access_check.csv",
#'     summary = list(rows = 2L, km_total = sum(access$km)),
#'     tolerance = list(tables = list(access_check = list(km = 1e-9)),
#'                      summary = list(km_total = 1e-6))
#'   ),
#'   publish = TRUE
#' )
#' r$recipe$recipe_id
#'
#' @export
crt_receipt_write <- function(dir, output, recipe, result = list(), context = list(),
                              keys = NULL, lockfile = NULL, publish = FALSE) {
  chk::chk_string(dir)
  chk::chk_flag(publish)
  if (!dir.exists(dir)) {
    cli::cli_abort("Directory {.path {dir}} does not exist.")
  }
  if (missing(lockfile) && file.exists("renv.lock")) lockfile <- "renv.lock"
  if (!is.null(keys) && !inherits(keys, "crt_receipt_keys")) {
    cli::cli_abort("{.arg keys} must come from {.fn crt_receipt_keys}.")
  }

  receipt <- receipt_build(dir, output, recipe, result, context, keys, lockfile, publish)
  receipt_write_file(receipt, file.path(dir, "receipt.json"))
  invisible(receipt)
}

receipt_build <- function(dir, output, recipe, result, context, keys, lockfile, publish) {
  for (arg in c("output", "recipe", "result", "context")) {
    v <- get(arg)
    if (!is.list(v) || (length(v) && is.null(names(v)))) {
      cli::cli_abort("{.arg {arg}} must be a named list.")
    }
  }
  receipt_known(output, c("name", "scope", "schema"), "output")
  receipt_known(recipe, c("code", "config", "inputs", "seed"), "recipe")
  receipt_known(result, c("tables", "parts", "summary", "tolerance"), "result")
  receipt_known(context, c("time", "host", "run", "session", "toolchain", "inputs"), "context")

  chk::chk_string(output$name, x_name = "output$name")
  out <- list(
    name = output$name,
    scope = receipt_null_string(output$scope, "output$scope"),
    receipt_version = receipt_version(),
    schema = receipt_null_string(output$schema, "output$schema")
  )

  rec <- list(
    code = receipt_code(recipe$code),
    config = receipt_config(recipe$config),
    inputs = receipt_inputs(recipe$inputs),
    seed = receipt_seed(recipe$seed)
  )

  tolerance <- if (!is.null(keys)) keys$tolerance else result$tolerance
  tolerance <- receipt_tolerance(tolerance)
  tables <- result$tables %||% list()
  if (length(tables) && (!is.list(tables) || is.data.frame(tables) || is.null(names(tables)))) {
    cli::cli_abort("{.arg result$tables} must be a named list of data frames.")
  }
  stray <- setdiff(names(tolerance$tables), names(tables))
  if (length(stray)) {
    cli::cli_abort("A tolerance is declared for {.val {stray}}, which {?is/are} not among the tables.")
  }
  fingerprint <- lapply(names(tables), function(nm) {
    list(sha256 = crt_table_fingerprint(tables[[nm]], tolerance$tables[[nm]]),
         rows = nrow(tables[[nm]]))
  })
  names(fingerprint) <- names(tables)

  summary <- receipt_summary(result$summary)
  if (!is.null(keys)) receipt_keys_check(keys, rec, tables, summary)
  stray <- setdiff(names(tolerance$summary), names(summary))
  if (length(stray)) {
    cli::cli_abort("A tolerance is declared for summary {.val {stray}}, which {?is/are} not in {.arg result$summary}.")
  }

  res <- list(
    fingerprint = receipt_object(fingerprint),
    parts = receipt_parts(dir, result$parts),
    summary = receipt_object(summary),
    tolerance = tolerance
  )

  ctx <- receipt_context(context, lockfile, publish)

  rec$recipe_id <- crt_receipt_recipe_id(rec)
  list(output = out, recipe = rec, result = res, context = ctx)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

receipt_version <- function() "1.0.0"

# An empty list serializes as an array; the blocks' keyed collections are objects.
receipt_object <- function(x) {
  if (is.null(x) || !length(x)) return(stats::setNames(list(), character()))
  x
}

receipt_known <- function(x, known, block) {
  extra <- setdiff(names(x), known)
  if (length(extra)) {
    cli::cli_abort(c(
      "{.arg {block}} has {cli::qty(extra)}{?a field/fields} the receipt does not hold: {.val {extra}}.",
      "i" = "Known: {.val {known}}."
    ))
  }
}

receipt_null_string <- function(x, what) {
  if (is.null(x)) return(NULL)
  chk::chk_string(x, x_name = what)
  if (!nzchar(x)) cli::cli_abort("{.arg {what}} must not be empty; leave it out instead.")
  x
}

receipt_named_list <- function(x, what) {
  if (is.null(x)) return(stats::setNames(list(), character()))
  if (!is.list(x) || (length(x) && (is.null(names(x)) || any(!nzchar(names(x)))))) {
    cli::cli_abort("{.arg {what}} must be a list keyed by name.")
  }
  if (anyDuplicated(names(x))) {
    cli::cli_abort("{.arg {what}} repeats {.val {unique(names(x)[duplicated(names(x))])}}.")
  }
  receipt_object(x)
}

receipt_code <- function(code) {
  code <- receipt_named_list(code, "recipe$code")
  for (repo in names(code)) {
    e <- code[[repo]]
    what <- paste0("recipe$code$", repo)
    if (!is.list(e) || !all(c("commit", "dirty") %in% names(e)) ||
        !all(names(e) %in% c("commit", "version", "dirty"))) {
      cli::cli_abort("{.arg {what}} must be {.code list(commit, version, dirty)}; {.field version} may be left out.")
    }
    if (!is.character(e$commit) || length(e$commit) != 1L || !grepl("^[0-9a-f]{40}$", e$commit)) {
      cli::cli_abort(c(
        "{.arg {what}$commit} must be a full 40-character lower-case SHA.",
        "i" = "A short SHA is ambiguous and would give the same recipe two ids."
      ))
    }
    chk::chk_flag(e$dirty, x_name = paste0(what, "$dirty"))
    code[[repo]] <- list(commit = e$commit,
                         version = receipt_null_string(e$version, paste0(what, "$version")),
                         dirty = e$dirty)
  }
  code
}

receipt_config <- function(config) {
  config <- config %||% list()
  receipt_known(config, c("files", "settings"), "recipe$config")
  files <- config$files %||% character()
  if (!is.character(files)) {
    cli::cli_abort("{.arg recipe$config$files} must be a character vector of paths.")
  }
  keys <- names(files) %||% files
  keys[!nzchar(keys)] <- files[!nzchar(keys)]
  if (anyDuplicated(keys)) {
    cli::cli_abort("{.arg recipe$config$files} repeats {.val {unique(keys[duplicated(keys)])}}.")
  }
  missing_files <- files[!file.exists(files)]
  if (length(missing_files)) {
    cli::cli_abort("Config file{?s} not found: {.path {missing_files}}.")
  }
  hashed <- lapply(files, receipt_file_sha256)
  names(hashed) <- keys
  list(files = receipt_object(hashed),
       settings = receipt_named_list(config$settings, "recipe$config$settings"))
}

receipt_inputs <- function(inputs) {
  inputs <- receipt_named_list(inputs, "recipe$inputs")
  kinds <- c("recipe_id", "version_id", "sha256", "none")
  for (nm in names(inputs)) {
    e <- inputs[[nm]]
    what <- paste0("recipe$inputs$", nm)
    if (!is.list(e) || length(e) != 1L || !names(e) %in% kinds) {
      cli::cli_abort(c(
        "{.arg {what}} must hold exactly one identity.",
        "i" = "One of {.code list(recipe_id = )}, {.code list(version_id = )}, {.code list(sha256 = )} or {.code list(none = \"why\")}."
      ))
    }
    v <- e[[1]]
    chk::chk_string(v, x_name = what)
    if (names(e) %in% c("recipe_id", "sha256") && !grepl("^[0-9a-f]{64}$", v)) {
      cli::cli_abort("{.arg {what}${names(e)}} must be 64 lower-case hex digits.")
    }
    if (!nzchar(v)) cli::cli_abort("{.arg {what}} is empty.")
  }
  inputs
}

receipt_seed <- function(seed) {
  if (is.null(seed)) return(NULL)
  if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) || seed != trunc(seed)) {
    cli::cli_abort("{.arg recipe$seed} must be a whole number or {.code NULL}.")
  }
  if (abs(seed) > .Machine$integer.max) seed else as.integer(seed)
}

# Tolerances as exact powers of ten, so each is spelled 1e-9 and not 1.0000000000000001e-9.
receipt_tolerance <- function(tolerance) {
  tolerance <- tolerance %||% list()
  receipt_known(tolerance, c("tables", "summary"), "result$tolerance")
  norm <- function(x, what) {
    x <- receipt_named_list(x, what)
    for (nm in names(x)) {
      v <- x[[nm]]
      if (is.character(v)) v <- suppressWarnings(as.numeric(v))
      if (!is.numeric(v) || length(v) != 1L) {
        cli::cli_abort("{.arg {what}${nm}} must be one number.")
      }
      x[[nm]] <- 10^-receipt_decimals(stats::setNames(v, nm), what)
    }
    x
  }
  tables <- receipt_named_list(tolerance$tables, "result$tolerance$tables")
  for (nm in names(tables)) tables[[nm]] <- norm(tables[[nm]], paste0("result$tolerance$tables$", nm))
  list(tables = tables, summary = norm(tolerance$summary, "result$tolerance$summary"))
}

receipt_summary <- function(summary) {
  summary <- receipt_named_list(summary, "result$summary")
  for (nm in names(summary)) {
    v <- summary[[nm]]
    if (!(is.null(v) || (is.numeric(v) && length(v) == 1L)) || (is.numeric(v) && is.nan(v))) {
      cli::cli_abort("{.arg result$summary${nm}} must be one number, NA or NULL.")
    }
    if (is.numeric(v) && is.infinite(v)) {
      cli::cli_abort("{.arg result$summary${nm}} is infinite, which JSON cannot hold.")
    }
  }
  summary
}

receipt_parts <- function(dir, parts) {
  parts <- parts %||% character()
  if (!is.character(parts) || anyNA(parts)) {
    cli::cli_abort("{.arg result$parts} must be a character vector of paths relative to {.arg dir}.")
  }
  rel <- gsub("\\\\", "/", parts)
  bad <- rel[grepl("^/|^[A-Za-z]:|(^|/)\\.\\.(/|$)", rel) | !nzchar(rel)]
  if (length(bad)) {
    cli::cli_abort(c(
      "Parts must be paths relative to {.arg dir}, inside it.",
      "x" = "Not: {.val {bad}}."
    ))
  }
  if (anyDuplicated(rel)) {
    cli::cli_abort("{.arg result$parts} repeats {.val {unique(rel[duplicated(rel)])}}.")
  }
  full <- file.path(dir, rel)
  missing_parts <- rel[!file.exists(full) | dir.exists(full)]
  if (length(missing_parts)) {
    cli::cli_abort(c(
      "{cli::qty(missing_parts)}Part{?s} not found: {.val {missing_parts}}.",
      "i" = "Parts are files under {.path {dir}}."
    ))
  }
  out <- lapply(full, function(f) list(bytes = file.size(f), sha256 = receipt_file_sha256(f)))
  names(out) <- rel
  receipt_object(out)
}

receipt_file_sha256 <- function(path) {
  digest::digest(path, algo = "sha256", file = TRUE)
}

receipt_context <- function(context, lockfile, publish) {
  time <- context$time %||% format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (!is.character(time) || length(time) != 1L ||
      !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$", time)) {
    cli::cli_abort("{.arg context$time} must be UTC in ISO 8601 with a trailing {.val Z}.")
  }
  toolchain <- utils::modifyList(receipt_toolchain(),
                                 receipt_named_list(context$toolchain, "context$toolchain"))
  ok <- vapply(toolchain, function(v) is.character(v) && length(v) == 1L && nzchar(v), TRUE)
  if (!all(ok)) {
    cli::cli_abort("Every {.arg context$toolchain} entry must be a version string: {.val {names(toolchain)[!ok]}}.")
  }
  lock <- NULL
  if (!is.null(lockfile)) {
    chk::chk_file(lockfile)
    lock <- receipt_file_sha256(lockfile)
  }
  host <- if (publish) NULL else context$host %||% Sys.info()[["nodename"]]
  ctx <- list(
    time = time,
    host = host,
    run = receipt_named_list(context$run, "context$run"),
    session = context$session,
    toolchain = receipt_object(toolchain[order(names(toolchain), method = "radix")]),
    lockfile_sha256 = lock,
    inputs = receipt_named_list(context$inputs, "context$inputs")
  )
  # host is the one optional member; NULL elsewhere is written as null.
  if (is.null(ctx$host)) ctx["host"] <- NULL
  if (!is.null(ctx$session)) chk::chk_string(ctx$session, x_name = "context$session")
  ctx
}

# Third-party versions of what is loaded. Recorded, never part of an identity.
receipt_toolchain <- function() {
  out <- list(R = paste(R.version$major, R.version$minor, sep = "."))
  for (pkg in c("arrow", "sf", "terra")) {
    if (isNamespaceLoaded(pkg)) out[[pkg]] <- as.character(utils::packageVersion(pkg))
  }
  gdal <- tryCatch(
    if (isNamespaceLoaded("terra")) {
      terra::gdal()
    } else if (isNamespaceLoaded("sf")) {
      unname(sf::sf_extSoftVersion()[["GDAL"]])
    },
    error = function(e) NULL
  )
  if (is.character(gdal) && length(gdal) == 1L && nzchar(gdal)) out$GDAL <- gdal
  out
}

# Canonical JSON, pretty-printed: keys sorted and numbers spelled as the ids hash them,
# so the file diffs cleanly and reads back to the same canonical bytes. Written to a
# temporary file beside the target and renamed over it, so a failed write leaves the
# previous receipt rather than half of one.
receipt_write_file <- function(receipt, path) {
  txt <- as.character(jsonlite::prettify(crt_receipt_jcs(receipt), indent = 2))
  txt <- gsub("\\{\n\\s*\n\\s*\\}", "{}", txt)
  txt <- gsub("\\[\n\\s*\n\\s*\\]", "[]", txt)
  tmp <- tempfile("receipt", tmpdir = dirname(path), fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(enc2utf8(sub("\n+$", "", txt)), tmp, useBytes = TRUE)
  if (!file.rename(tmp, path)) {
    cli::cli_abort("Could not write {.path {path}}.")
  }
  invisible(path)
}
