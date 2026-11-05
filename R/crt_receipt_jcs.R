# RFC 8785 (JSON Canonicalization Scheme) and the recipe_id built on it (#43).
#
# A receipt's ids must come out byte for byte the same from any language, so they hash
# canonical JSON, never R's serialization or jsonlite's formatting. JCS fixes the three
# things JSON leaves open: object key order (UTF-16 code units), string escaping (only
# what JSON requires), and number spelling (ECMAScript's shortest round-trip form).
# Python's `rfc8785` and every other JCS serializer give the same bytes, which the test
# vectors in inst/extdata/receipt/vectors/ hold them to.
#
# R values map to JSON as jsonlite's auto_unbox does: a named list is an object, an
# unnamed list an array, a length-one atomic a scalar and any other atomic an array.
# Wrap a length-one vector in I() to keep it an array. NULL and a scalar NA are null.

#' Serialize a value to RFC 8785 canonical JSON
#'
#' @param x An R value, read as jsonlite's `auto_unbox = TRUE` reads it.
#' @return A single UTF-8 string.
#' @noRd
crt_receipt_jcs <- function(x) {
  enc2utf8(jcs_value(x, "x"))
}

#' Compute a recipe's recipe_id
#'
#' SHA-256, lowercase hex, of the UTF-8 bytes of the RFC 8785 serialization of the
#' recipe block with its own `recipe_id` removed.
#'
#' @param recipe The recipe block, as a named list.
#' @return A 64-character string.
#' @noRd
crt_receipt_recipe_id <- function(recipe) {
  if (!is.list(recipe) || is.null(names(recipe))) {
    cli::cli_abort("{.arg recipe} must be a named list, the receipt's {.field recipe} block.")
  }
  recipe[["recipe_id"]] <- NULL
  receipt_sha256(crt_receipt_jcs(recipe))
}

# SHA-256 of a string's UTF-8 bytes. Over raw bytes, so digest sees no R object and
# no serialization header.
receipt_sha256 <- function(txt) {
  digest::digest(charToRaw(enc2utf8(txt)), algo = "sha256", serialize = FALSE)
}

jcs_value <- function(x, path) {
  if (is.null(x)) return("null")
  # A whitelist, applied before any generic can dispatch on a class: plain lists and
  # atomic vectors, factors, and I(). Anything else is refused rather than written
  # through its methods, which print octmode 493 as "755", drop a ts() start, a units
  # attribute (5 km as 5 m), an S4 slot or a data frame's shape, or recurse on
  # POSIXlt. A Python writer holds none of these, so no spelling of them is shared.
  cls <- oldClass(x)
  asis <- identical(cls, "AsIs")
  if (asis) x <- unclass(x)
  if (!is.null(cls) && !asis && !identical(cls, "factor")) jcs_refuse_class(x, path)
  extra <- setdiff(names(attributes(x)), c("names", if (identical(cls, "factor")) c("levels", "class")))
  if (length(extra) || isS4(x)) {
    cli::cli_abort(c(
      "Value at {.code {path}} carries {.field {extra}}, which JSON would drop.",
      "i" = "Pass the plain values, with {.fn as.vector} or {.fn unclass}."
    ))
  }
  if (is.list(x)) {
    if (!is.null(names(x))) return(jcs_object(x, path))
    return(paste0("[", paste(vapply(seq_along(x), function(i) {
      jcs_value(x[[i]], sprintf("%s[[%d]]", path, i))
    }, ""), collapse = ","), "]"))
  }
  # Names on an atomic vector, a factor's included, which as.character() would drop:
  # c(CO = 0.05, CH = 0.07) and c(CH = 0.05, CO = 0.07) would hash alike.
  if (!is.null(names(x))) {
    cli::cli_abort(c(
      "Value at {.code {path}} is a named vector, whose names JSON would drop.",
      "i" = "Use {.fn as.list} for an object keyed by its names, or {.fn unname} for an array."
    ))
  }
  if (is.factor(x)) x <- as.character(x)
  if (!(is.character(x) || is.double(x) || is.integer(x) || is.logical(x))) {
    cli::cli_abort(c(
      "Value at {.code {path}} is of type {.cls {typeof(x)}}, which has no JSON form.",
      "i" = "Use a string, number, logical, list or NULL."
    ))
  }
  vals <- jcs_atomic(x, path)
  if (length(x) == 1L && !asis) return(vals)
  paste0("[", paste(vals, collapse = ","), "]")
}

jcs_refuse_class <- function(x, path) {
  # is.numeric() is TRUE for an integer64, whose storage is the int64's bits read as a
  # double: 42 would be written 2.0750757125332355e-322. RPostgres returns counts so.
  if (inherits(x, "integer64")) {
    cli::cli_abort(c(
      "Value at {.code {path}} is a {.cls integer64}, which has no JSON number of its own here.",
      "i" = "Convert it with {.fn as.numeric} (exact below 2^53) or {.fn as.character}."
    ))
  }
  if (inherits(x, c("Date", "POSIXt", "difftime"))) {
    cli::cli_abort(c(
      "Value at {.code {path}} is a {.cls {class(x)[1]}}.",
      "i" = "Format it as an ISO 8601 string first, so its spelling is not R's."
    ))
  }
  if (is.data.frame(x)) {
    cli::cli_abort(c(
      "Value at {.code {path}} is a data frame, which has no single JSON shape.",
      "i" = "Pass a list of columns ({.fn as.list}) or of rows, whichever you mean."
    ))
  }
  cli::cli_abort(c(
    "Value at {.code {path}} has class {.cls {class(x)}}, which has no JSON form here.",
    "i" = "Pass its plain value: a string, number, logical, list or NULL ({.fn unclass}, {.fn format})."
  ))
}

jcs_object <- function(x, path) {
  keys <- names(x)
  if (anyNA(keys)) {
    cli::cli_abort("An object at {.code {path}} has a missing key.")
  }
  # A duplicate key serializes as the key twice, and readers keep whichever they meet
  # first or last: two languages would read two objects from one receipt.
  if (anyDuplicated(keys)) {
    cli::cli_abort(c(
      "An object at {.code {path}} has a repeated key.",
      "x" = "Repeated: {.val {unique(keys[duplicated(keys)])}}."
    ))
  }
  keys <- jcs_utf8(keys, path)
  ord <- order(jcs_utf16_key(keys), method = "radix")
  members <- vapply(ord, function(i) {
    paste0(jcs_string(keys[i]), ":", jcs_value(x[[i]], paste0(path, "$", keys[i])))
  }, "")
  paste0("{", paste(members, collapse = ","), "}")
}

jcs_atomic <- function(x, path) {
  # Before the NA test, which NaN also passes: NaN is not a missing value, and JSON has
  # no spelling for it.
  if (is.double(x) && any(is.nan(x) | is.infinite(x))) {
    cli::cli_abort("A number at {.code {path}} is NaN or infinite, which JSON cannot hold.")
  }
  out <- character(length(x))
  na <- is.na(x)
  out[na] <- "null"
  # paste0() recycles a zero-length argument to "", so an empty vector would come back
  # as one empty string rather than no elements.
  if (all(na)) return(out)
  if (is.character(x)) {
    out[!na] <- jcs_string(jcs_utf8(x[!na], path))
  } else if (is.logical(x)) {
    out[!na] <- ifelse(x[!na], "true", "false")
  } else if (is.integer(x)) {
    out[!na] <- as.character(x[!na])
  } else {
    out[!na] <- jcs_numbers(x[!na])
  }
  out
}

# Decide validity before converting, whatever the locale. enc2utf8() reads an unmarked
# string in the session's locale: under C it escapes a bad byte to the text "<e9>",
# which is valid UTF-8, so one input would abort in one session and hash as
# "caf<e9>" or "café" in others. So an unmarked string must already be UTF-8 (it is
# marked as such), and only a string marked latin1 is converted.
jcs_utf8 <- function(x, path) {
  if (!length(x)) return(x)
  enc <- Encoding(x)
  if (any(enc == "bytes")) {
    cli::cli_abort("A string at {.code {path}} is marked as bytes, which have no text form.")
  }
  unmarked <- enc == "unknown"
  if (any(unmarked & !validUTF8(x))) {
    cli::cli_abort(c(
      "A string at {.code {path}} is not valid UTF-8.",
      "i" = "Mark latin1 text with {.code Encoding(x) <- \"latin1\"} so it can be converted."
    ))
  }
  if (any(unmarked)) Encoding(x)[unmarked] <- "UTF-8"
  enc2utf8(x)
}

# JSON.stringify's escaping, which RFC 8785 adopts: the quote, the backslash and the
# five short forms, other control characters as \u00xx in lower-case hex, and every
# other character, U+007F and U+2028 included, as itself.
jcs_string <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  short <- c("\b" = "\\b", "\t" = "\\t", "\n" = "\\n", "\f" = "\\f", "\r" = "\\r")
  for (ch in names(short)) x <- gsub(ch, short[[ch]], x, fixed = TRUE)
  ctl <- grepl("[\001-\037]", x, useBytes = TRUE)
  if (any(ctl)) {
    for (cp in setdiff(1:31, c(8L, 9L, 10L, 12L, 13L))) {
      x[ctl] <- gsub(intToUtf8(cp), sprintf("\\u%04x", cp), x[ctl], fixed = TRUE)
    }
  }
  paste0("\"", x, "\"")
}

# A sort key giving UTF-16 code-unit order under a byte-wise radix sort: each unit as
# four hex digits. Code-point order (which a plain UTF-8 byte sort gives) differs from
# it only above U+FFFF, where a surrogate pair (D800-DBFF) sorts below U+E000-U+FFFF.
jcs_utf16_key <- function(keys) {
  vapply(keys, function(k) {
    cp <- utf8ToInt(k)
    big <- cp > 0xFFFF
    if (any(big)) {
      v <- cp[big] - 0x10000
      units <- as.list(cp)
      units[big] <- Map(c, 0xD800 + v %/% 0x400, 0xDC00 + v %% 0x400)
      cp <- unlist(units)
    }
    paste(sprintf("%04X", cp), collapse = "")
  }, "", USE.NAMES = FALSE)
}

# ECMAScript Number::toString (ECMA-262 7.1.12.1), which RFC 8785 adopts: the fewest
# significant digits that read back as the same double, laid out in plain decimal
# from 1e-7 up to 1e21 and in exponent form outside it. Vectorized over finite x.
jcs_numbers <- function(x) {
  out <- character(length(x))
  out[x == 0] <- "0"
  nz <- which(x != 0)
  if (!length(nz)) return(out)
  ax <- abs(x[nz])
  # printf rounds each candidate correctly from the exact binary value. The read-back
  # goes through jsonlite (the C library's strtod), not as.numeric(): R's own parser
  # is not correctly rounded where long double is double, and on arm64 macOS it misread
  # 84% of 200,000 random 17-digit spellings (findings.md). No shortcut for whole
  # numbers either: above 2^53 ECMAScript writes the shortest digits padded with zeros
  # (2^60 is 1152921504606847000), not the exact integer.
  #
  # At p digits the candidates are the correctly rounded spelling and the decimals one
  # step either side of it. ECMAScript takes any p-digit decimal that reads back, and
  # where the exact value is a tie at p digits (2^-24 is 5.9604644775390625e-8) printf
  # rounds to the neighbour that does not read back, while the one beside it does:
  # Python and Node write 5.960464477539063e-8. That happens only at a power of two,
  # where the interval of decimals that read back is twice as wide above the double as
  # below it; elsewhere it is symmetric and the rounded spelling, the nearest, reads
  # back whenever a neighbour would. So neighbours are tried for powers of two only.
  #
  # If p digits read back, so do p + 1, so the fewest is found by bisection over 1-17:
  # five parses per value rather than seventeen.
  pow2 <- ax == 2^round(log2(ax))
  cands <- function(p, idx) {
    s0 <- sprintf(paste0("%.", p - 1L, "e"), ax[idx])
    d0 <- gsub(".", "", sub("e.*$", "", s0), fixed = TRUE)
    q <- as.integer(sub("^.*e", "", s0)) - (p - 1L)
    up <- down <- rep(NA_character_, length(idx))
    two <- pow2[idx]
    up[two] <- jcs_digit_step(d0[two], 1L)
    down[two] <- jcs_digit_step(d0[two], -1L)
    list(digits = cbind(d0, up, down), q = q)
  }
  reads_back <- function(cd, idx) {
    hit <- matrix(FALSE, nrow = length(idx), ncol = 3L)
    have <- !is.na(cd$digits)
    txt <- paste0(cd$digits[have], "e", rep(cd$q, 3L)[have])
    back <- jsonlite::parse_json(paste0("[", paste(txt, collapse = ","), "]"), simplifyVector = TRUE)
    hit[have] <- back == rep(ax[idx], 3L)[have]
    hit
  }
  lo <- rep(1L, length(ax))
  hi <- rep(17L, length(ax))
  repeat {
    i <- which(lo < hi)
    if (!length(i)) break
    mid <- (lo[i] + hi[i]) %/% 2L
    ok <- rowSums(reads_back(cands(mid, i), i)) > 0
    hi[i[ok]] <- mid[ok]
    lo[i[!ok]] <- mid[!ok] + 1L
  }
  i <- seq_along(ax)
  cd <- cands(lo, i)
  hit <- reads_back(cd, i)
  pick <- ifelse(hit[, 1L], 1L, ifelse(hit[, 2L], 2L, 3L))
  raw <- cd$digits[cbind(i, pick)]
  # Strip trailing zeros into the exponent: value = digits x 10^q.
  tz <- nchar(raw) - nchar(sub("0+$", "", raw))
  digits <- sub("0+$", "", raw)
  digits[!nzchar(digits)] <- "0"
  q <- cd$q + tz
  e <- nchar(digits) + q - 1L
  k <- nchar(digits)
  n <- e + 1L
  first <- substr(digits, 1L, 1L)
  rest <- substr(digits, 2L, k)
  sign <- ifelse(n - 1L >= 0L, "+", "-")
  txt <- ifelse(
    k <= n & n <= 21L, paste0(digits, strrep("0", pmax(n - k, 0L))),
    ifelse(
      0L < n & n <= 21L, paste0(substr(digits, 1L, pmax(n, 0L)), ".", substr(digits, pmax(n, 0L) + 1L, k)),
      ifelse(
        -6L < n & n <= 0L, paste0("0.", strrep("0", pmax(-n, 0L)), digits),
        paste0(first, ifelse(k == 1L, "", paste0(".", rest)), "e", sign, abs(n - 1L))
      )
    )
  )
  out[nz] <- paste0(ifelse(x[nz] < 0, "-", ""), txt)
  out
}

# A decimal digit string one step up or down in its last place, without going through
# a double (17 digits exceed 2^53). A carry out lengthens it ("999" up is "1000"); a
# borrow out shortens it ("1000" down is "999").
jcs_digit_step <- function(d, delta) {
  n <- nchar(d)
  last <- as.integer(substring(d, n))
  out <- character(length(d))
  # No carry: replace the last digit, vectorized; carries and borrows go below.
  easy <- if (delta > 0L) last < 9L else last > 0L & n > 1L
  out[easy] <- paste0(substr(d[easy], 1L, n[easy] - 1L), last[easy] + delta)
  out[!easy] <- jcs_digit_step_carry(d[!easy], delta)
  out
}

jcs_digit_step_carry <- function(d, delta) {
  vapply(d, function(s) {
    v <- as.integer(strsplit(s, "", fixed = TRUE)[[1]])
    j <- length(v)
    v[j] <- v[j] + delta
    while (j > 1L && (v[j] > 9L || v[j] < 0L)) {
      carry <- if (v[j] > 9L) 1L else -1L
      v[j] <- v[j] - 10L * carry
      j <- j - 1L
      v[j] <- v[j] + carry
    }
    if (v[1] > 9L) v <- c(1L, v[1] - 10L, v[-1])
    out <- sub("^0+(?=.)", "", paste(v, collapse = ""), perl = TRUE)
    if (v[1] < 0L) "0" else out
  }, "", USE.NAMES = FALSE)
}
