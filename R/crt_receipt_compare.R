#' Compare two provenance receipts
#'
#' Judges a rebuild against its reference copy and answers with one of three
#' verdicts, naming every field that differed (crate#43):
#'
#' * `identical`: the same recipe and the same result.
#' * `equivalent`: the same recipe, and every result value that differs is within
#'   the tolerance the output declares.
#' * `different`: another recipe, or a result value past its tolerance.
#'
#' What a difference in each field does comes from the receipt register
#' (`inst/extdata/receipt/register/v1.0.0/register.csv`, published at
#' `https://newgraphenvironment.github.io/crate/receipt/register/v1.0.0/register.csv`),
#' one row per field: `refuse` makes the
#' verdict `different`, `warn` is reported without changing it, and `record` is
#' listed only. Every recipe field refuses, because `recipe_id` covers it; every
#' context field is recorded, because the machine and the toolchain are never part
#' of an identity.
#'
#' A verdict is a function of the register's rows, so the register is versioned on its
#' own (crate#58) and every comparison names the version it was judged under. A row
#' change is a new register version; it never moves the version a receipt carries, which
#' is its form's.
#'
#' @section Receipts or bytes:
#' A comparison of receipts alone compares what the writers claimed. A table whose
#' fingerprints differ is then `different`, even when the difference is a value that
#' rounded the other way at the edge of its tolerance (0.0000000014 and 0.0000000016
#' under 1e-9). Supply both builds' tables and the comparison re-reads them: it checks
#' each against its own receipt's fingerprint, then compares their cells, and a table
#' whose cells all agree within tolerance is `equivalent`. The result's `mode` says
#' which was done.
#'
#' A file whose bytes differ is `equivalent` only when its receipt names the table it
#' holds (`parts`, named, in [crt_receipt_write()]) and that table agrees; a file that
#' names no table, such as a raster nobody fingerprinted, is `different`.
#'
#' @param a,b Receipts, as lists from [crt_receipt_read()], or paths to them. `a` is
#'   the reference copy.
#' @param tables Optional: `list(a = list(<table> = <data frame>), b = list(...))`,
#'   the two builds' tables to re-read.
#' @param keys Optional: the package's declaration, from [crt_receipt_keys()], whose
#'   `register` overrides the default action for fields outside the recipe.
#'
#' @return A list of class `crt_receipt_comparison`: `verdict`; `mode`, `"receipts"`
#'   or `"bytes"`; and `differences`, a tibble with one row per field that differed:
#'   `side` (`output`, `recipe`, `result` or `context`), `field`, `action` (`refuse`,
#'   `warn`, `record`, or `within` for a difference inside its tolerance), and
#'   `detail`; `register`, the version of the register the verdict was judged under;
#'   and `overrides`, the action the declaration in `keys` gave each field whose action
#'   it changed, named by field (empty when it changed none). It lists every such field,
#'   whether or not that field differed in this comparison.
#'
#' @examples
#' wc <- system.file("extdata", "receipt", "examples", "worked_case", package = "crate")
#' crt_receipt_compare(file.path(wc, "build_1"), file.path(wc, "build_2"))
#'
#' @export
crt_receipt_compare <- function(a, b, tables = NULL, keys = NULL) {
  if (is.character(a)) a <- crt_receipt_read(a)
  if (is.character(b)) b <- crt_receipt_read(b)
  for (x in list(a, b)) {
    if (!is.list(x) || !all(c("output", "recipe", "result", "context") %in% names(x))) {
      cli::cli_abort("{.arg a} and {.arg b} must be receipts or paths to them.")
    }
  }
  if (!is.null(keys) && !inherits(keys, "crt_receipt_keys")) {
    cli::cli_abort("{.arg keys} must come from {.fn crt_receipt_keys}.")
  }
  if (!is.null(tables)) {
    if (!is.list(tables) || !setequal(names(tables), c("a", "b"))) {
      cli::cli_abort("{.arg tables} must be {.code list(a = list(...), b = list(...))}.")
    }
  }
  register <- receipt_register(keys)

  d <- receipt_diff(a, b, register)
  d$action <- register$action[match(d$pattern, register$field)]
  d$action[is.na(d$action)] <- "refuse"
  # Fingerprint differences are settled below, from the tables when they are supplied.
  d$action[d$pattern == "result.fingerprint.*.sha256"] <- NA_character_

  # Neither side can vouch for a recipe it does not have.
  if (is.null(a$recipe$recipe_id) || is.null(b$recipe$recipe_id)) {
    side <- c("a", "b")[c(is.null(a$recipe$recipe_id), is.null(b$recipe$recipe_id))]
    d <- d[d$pattern != "recipe.recipe_id", ]
    d <- rbind(d, receipt_diff_row(
      "recipe.recipe_id", "recipe.recipe_id", "refuse",
      paste0("recipe unknown: ", paste(side, collapse = " and "),
             " holds no recipe identity (a migrated receipt)")
    ))
  }

  used_bytes <- FALSE
  # Every table supplied is checked against its own receipt, whether or not the two
  # receipts' fingerprints differ: that is what re-reading certifies.
  for (side in intersect(c("a", "b"), names(tables))) {
    r <- if (side == "a") a else b
    for (tbl in names(tables[[side]])) {
      used_bytes <- TRUE
      want <- r$result$fingerprint[[tbl]]$sha256
      got <- if (!is.null(want)) {
        tol <- r$result$tolerance$tables[[tbl]]
        receipt_reread_fingerprint(tables[[side]][[tbl]], tol)
      }
      if (is.null(want) || !identical(got, want)) {
        d <- rbind(d, receipt_diff_row(
          paste0("result.fingerprint[", tbl, "].sha256"), "result.fingerprint.*.sha256", "refuse",
          paste0("re-read: the table supplied for ", side, " is not the one its receipt fingerprinted"),
          key = tbl
        ))
      }
    }
  }
  # Tables first: the parts' verdicts depend on them.
  fp <- which(d$pattern == "result.fingerprint.*.sha256" & is.na(d$action))
  for (i in fp) {
    tbl <- d$key[i]
    da <- tables$a[[tbl]]
    db <- tables$b[[tbl]]
    if (is.null(da) || is.null(db)) {
      d$action[i] <- register$action[register$field == "result.fingerprint.*.sha256"]
      d$detail[i] <- paste0("fingerprints differ (receipts only): ", d$detail[i])
      next
    }
    verdict <- receipt_tables_within(tbl, da, db, a, b)
    d$action[i] <- if (verdict$ok) "within" else "refuse"
    d$detail[i] <- verdict$detail
  }
  agreed <- function(tbl) {
    in_both <- !is.null(tbl) && tbl %in% names(a$result$fingerprint) &&
      tbl %in% names(b$result$fingerprint)
    if (!in_both) return(FALSE)
    rows <- d$key %in% tbl & startsWith(d$pattern, "result.fingerprint.*.")
    all(d$action[rows] == "within")
  }
  for (i in which(d$pattern %in% c("result.parts.*.bytes", "result.parts.*.sha256"))) {
    part <- d$key[i]
    ta <- a$result$parts[[part]]$table
    tb <- b$result$parts[[part]]$table
    if (!is.null(ta) && identical(ta, tb) && agreed(ta)) {
      d$action[i] <- "within"
      d$detail[i] <- paste0(d$detail[i], "; table ", ta, " agrees")
    } else {
      d$detail[i] <- paste0(d$detail[i], if (is.null(ta) || !identical(ta, tb)) {
        "; the file names no table that could vouch for it"
      } else {
        paste0("; table ", ta, " does not agree")
      })
    }
  }
  for (i in which(d$pattern == "result.summary.*")) {
    nm <- d$key[i]
    tol <- receipt_summary_tolerance(a, b, nm)
    va <- a$result$summary[[nm]]
    vb <- b$result$summary[[nm]]
    # A receipt list from crt_receipt_write() holds NA where one read from disk holds
    # NULL; both are null, and a null has no distance from anything.
    num <- function(v) is.numeric(v) && length(v) == 1L && !is.na(v)
    if (!is.null(tol) && num(va) && num(vb) && abs(va - vb) <= tol) {
      d$action[i] <- "within"
      d$detail[i] <- paste0(d$detail[i], "; within ", format(tol))
    }
  }

  verdict <- if (any(d$action == "refuse")) {
    "different"
  } else if (any(d$action == "within")) {
    "equivalent"
  } else {
    "identical"
  }
  differences <- tibble::tibble(
    side = sub("\\..*$", "", d$pattern),
    field = d$field,
    action = d$action,
    detail = d$detail
  )
  structure(
    list(verdict = verdict, mode = if (used_bytes) "bytes" else "receipts",
         differences = differences, register = receipt_register_version(),
         overrides = attr(register, "overrides")),
    class = "crt_receipt_comparison"
  )
}

#' @export
print.crt_receipt_comparison <- function(x, ...) {
  n <- length(x$overrides)
  over <- if (n) paste0(", ", n, if (n == 1L) " field" else " fields",
                        " overridden by the package's declaration") else ""
  cat(x$verdict, " (", if (x$mode == "bytes") "receipts and re-read tables" else "receipts only",
      "; register v", x$register, over, ")\n", sep = "")
  d <- x$differences
  for (i in seq_len(nrow(d))) {
    cat("  ", formatC(d$action[i], width = -6), " ", d$field[i], ": ", d$detail[i], "\n", sep = "")
  }
  invisible(x)
}

# The register, with a package's overrides applied.
# `overrides` is the declared action of each field whose action the declaration changed,
# named by field; restating the register's own action is not an override.
receipt_register <- function(keys = NULL) {
  path <- receipt_contract_file("register", receipt_register_version(), "register.csv")
  r <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
  overrides <- stats::setNames(character(), character())
  if (!is.null(keys) && nrow(keys$register)) {
    unknown <- setdiff(keys$register$field, r$field)
    if (length(unknown)) {
      cli::cli_abort("The declaration's {.field register} names fields the receipt does not have: {.val {unknown}}.")
    }
    i <- match(keys$register$field, r$field)
    changed <- r$action[i] != keys$register$action
    overrides <- stats::setNames(keys$register$action[changed], r$field[i][changed])
    r$action[i] <- keys$register$action
  }
  attr(r, "overrides") <- overrides[order(names(overrides), method = "radix")]
  r
}

receipt_diff_row <- function(field, pattern, action = NA_character_, detail = "", key = NA_character_) {
  data.frame(field = field, pattern = pattern, key = key, action = action, detail = detail,
             stringsAsFactors = FALSE)
}

# Every field whose value differs between two receipts, walked against the register:
# a pattern with `.*` children is a collection keyed by name (a key on one side only
# is a difference at the collection), any other a fixed object or a leaf.
receipt_diff <- function(a, b, register) {
  fields <- register$field
  collections <- unique(unlist(lapply(fields[grepl(".*", fields, fixed = TRUE)], function(f) {
    parts <- strsplit(f, ".", fixed = TRUE)[[1]]
    star <- which(parts == "*")
    vapply(star, function(s) paste(parts[seq_len(s - 1L)], collapse = "."), "")
  })))
  prefixes <- unique(unlist(lapply(fields, function(f) {
    parts <- strsplit(f, ".", fixed = TRUE)[[1]]
    vapply(seq_along(parts), function(s) paste(parts[seq_len(s)], collapse = "."), "")
  })))
  rows <- list()
  add <- function(field, pattern, detail, key) {
    rows[[length(rows) + 1L]] <<- receipt_diff_row(field, pattern, detail = detail, key = key)
  }
  show <- function(v) {
    s <- if (is.null(v)) "absent" else crt_receipt_jcs(v)
    if (nchar(s) > 80) paste0(substr(s, 1, 77), "...") else s
  }
  walk <- function(x, y, field, pattern, key) {
    if (pattern %in% collections) {
      kx <- names(x) %||% character()
      ky <- names(y) %||% character()
      for (k in setdiff(kx, ky)) add(field, pattern, paste0(k, " only in a"), k)
      for (k in setdiff(ky, kx)) add(field, pattern, paste0(k, " only in b"), k)
      for (k in intersect(kx, ky)) walk(x[[k]], y[[k]], paste0(field, "[", k, "]"), paste0(pattern, ".*"), k)
    } else if (pattern %in% fields || !pattern %in% prefixes) {
      if (!identical(show_full(x), show_full(y))) {
        add(field, pattern, paste0(show(x), " vs ", show(y)), key)
      }
    } else {
      for (nm in union(names(x), names(y))) {
        walk(x[[nm]], y[[nm]], paste0(field, ".", nm), paste0(pattern, ".", nm), key)
      }
    }
  }
  # An absent member and a null are one value, as JSON reads them: a written receipt
  # holds NA (null) where its file reads back as NULL.
  show_full <- function(v) crt_receipt_jcs(v)
  for (block in c("output", "recipe", "result", "context")) {
    walk(a[[block]], b[[block]], block, block, NA_character_)
  }
  if (!length(rows)) return(receipt_diff_row(character(), character(), character(), character(), character()))
  do.call(rbind, rows)
}

# The tolerance both receipts declare for a summary value, or NULL when they differ
# (a tolerance difference is its own refusal).
receipt_summary_tolerance <- function(a, b, nm) {
  ta <- a$result$tolerance$summary[[nm]]
  tb <- b$result$tolerance$summary[[nm]]
  if (is.null(ta) || !receipt_same(ta, tb)) return(NULL)
  ta
}

# Two builds' copies of one table: each must be what its own receipt fingerprinted,
# and their cells must agree within the declared tolerances.
receipt_tables_within <- function(tbl, da, db, a, b) {
  tol_a <- a$result$tolerance$tables[[tbl]]
  tol_b <- b$result$tolerance$tables[[tbl]]
  if (!receipt_same(tol_a, tol_b)) {
    return(list(ok = FALSE, detail = "the builds declare different tolerances for it"))
  }
  da <- receipt_reread_numeric(da, tol_a)
  db <- receipt_reread_numeric(db, tol_a)
  for (side in c("a", "b")) {
    df <- if (side == "a") da else db
    r <- if (side == "a") a else b
    if (!identical(receipt_reread_fingerprint(df, tol_a), r$result$fingerprint[[tbl]]$sha256)) {
      return(list(ok = FALSE, detail = paste0("re-read: the table supplied for ", side,
                                              " is not the one its receipt fingerprinted")))
    }
  }
  if (!setequal(names(da), names(db))) {
    return(list(ok = FALSE, detail = "re-read: the columns differ"))
  }
  if (nrow(da) != nrow(db)) {
    return(list(ok = FALSE, detail = paste0("re-read: ", nrow(da), " rows vs ", nrow(db))))
  }
  tol_cols <- names(tol_a)
  keys <- setdiff(sort(names(da), method = "radix"), tol_cols)
  # Pair rows by the exact canonical spelling of every other column, then by the
  # tolerance columns' values, so ties on the key pair up in value order.
  key_of <- function(df) {
    if (!length(keys)) return(rep("", nrow(df)))
    cells <- lapply(keys, function(nm) table_cells(df[[nm]], nm, NA_integer_))
    do.call(paste, c(cells, sep = ","))
  }
  ord <- function(df, k) {
    do.call(order, c(list(k), lapply(tol_cols, function(nm) df[[nm]]), list(method = "radix")))
  }
  ka <- key_of(da)
  kb <- key_of(db)
  oa <- ord(da, ka)
  ob <- ord(db, kb)
  if (!identical(ka[oa], kb[ob])) {
    return(list(ok = FALSE, detail = "re-read: rows differ outside the tolerance columns"))
  }
  past <- character()
  for (nm in tol_cols) {
    x <- da[[nm]][oa]
    y <- db[[nm]][ob]
    bad <- xor(is.na(x), is.na(y)) | (!is.na(x) & !is.na(y) & abs(x - y) > tol_a[[nm]])
    if (any(bad)) {
      past <- c(past, paste0("column ", nm, ", ", sum(bad), " row", if (sum(bad) > 1) "s",
                             " past ", format(tol_a[[nm]])))
    }
  }
  if (length(past)) return(list(ok = FALSE, detail = paste0("re-read: ", paste(past, collapse = "; "))))
  list(ok = TRUE, detail = paste0("fingerprints differ; re-read, every cell within tolerance"))
}

# A table read back from a file can bring a tolerance column back as another type:
# read.csv() gives integer when every value is whole (write.csv() writes 12.0 as 12)
# and logical when every value is NA. Read as double they spell as the writer's
# doubles did, so the re-read can still be fingerprinted.
receipt_reread_numeric <- function(df, tolerance) {
  for (nm in intersect(names(tolerance), names(df))) {
    v <- df[[nm]]
    plain_int <- is.integer(v) && is.null(oldClass(v))
    if (plain_int || (is.logical(v) && all(is.na(v)))) df[[nm]] <- as.double(v)
  }
  df
}

# One value in two receipts, compared as the receipts hash it: a receipt returned by
# crt_receipt_write() holds a tolerance of 1 as a double in the caller's order, the
# same receipt read from disk as 1L in key order.
receipt_same <- function(x, y) {
  identical(crt_receipt_jcs(x), crt_receipt_jcs(y))
}

# A re-read table's fingerprint, or NA when it cannot be fingerprinted at all (a
# tolerance column missing or read back as text): that is a table that is not the one
# its receipt fingerprinted, a finding, not a reason to abort the comparison.
receipt_reread_fingerprint <- function(df, tolerance) {
  tryCatch(
    crt_table_fingerprint(receipt_reread_numeric(df, tolerance), tolerance),
    error = function(e) NA_character_
  )
}
