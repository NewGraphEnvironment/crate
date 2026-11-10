#' A receipt's fields as a STAC item mirrors them
#'
#' Executes the STAC rows of the receipt mapping (`STAC item` in
#' `inst/extdata/receipt/mapping/v1.1.0/mapping.csv`, published at
#' `https://newgraphenvironment.github.io/crate/receipt/mapping/v1.1.0/mapping.csv`)
#' for one receipt: the item properties and asset fields that let a STAC client or a
#' pgstac queryable read a build's identity without fetching its receipt (crate#59).
#' The receipt stays the full record. Every implementation of the mapping runs the
#' vectors in `mapping/v1.1.0/stac.json`, so two of them agree on every item.
#'
#' @section What it mirrors:
#' * `properties`: `receipt:recipe_id` from `recipe.recipe_id`, left out for a migrated
#'   receipt (`output.migrated_from`), which claims no recipe identity, and refused when
#'   missing on any other: the item never publishes a null one; `processing:datetime`
#'   from `context.time`, which is required; `processing:software`, one entry per
#'   repository in `recipe.code` that has a `version`, and left out when none has.
#' * A block or entry present but not an object, `null` included, is refused, never read
#'   as absent.
#'
#' @section Refusals:
#' A receipt or an argument the mapping cannot place is refused with an error of class
#' `crate_stac_refused`, whose `code` field names what was refused: the same codes the
#' `error` field of `stac.json` carries, so an implementation's refusals can be compared
#' by code rather than by message. The receipt must be of the form this mapping reads
#' (`output.receipt_version` 1.0.0), as [crt_receipt_read()] requires of a file; a
#' character `receipt` is read as a path.
#' * `assets`: for each asset in `assets`, the part its href names, as `file:checksum`
#'   (multihash: `1220` and the part's `sha256`) and `file:size` (its `bytes`). A part
#'   no asset names is not mirrored, since an item may publish fewer files than the
#'   build made; two assets may name one part. An asset whose href names no part is an
#'   error: the item would otherwise carry a guessed checksum or none.
#' * The receipt asset, named by `receipt_asset`: `file:checksum` only, the multihash of
#'   `receipt_sha256`, the digest [crt_receipt_write()] returned for the bytes it wrote.
#'   Never from a part, since a receipt is not one of its own parts, and with no
#'   `file:size`, deliberately: the digest identifies the bytes (crate#60).
#' * `stac_extensions`: the file, processing and receipt extension URLs, in that order,
#'   each only when one of its fields is present.
#'
#' Merge the result into the item being built. Nothing else of the item (its id,
#' geometry, other assets' hrefs, types and roles) comes from the receipt.
#'
#' @param receipt A receipt, as a list from [crt_receipt_read()], or a path to one.
#' @param assets A named character vector: each asset's key, and as its value the
#'   asset's href relative to the item, which is the path a part is keyed by. `NULL`
#'   for none.
#' @param receipt_asset The key of the asset that links the receipt, or `NULL`.
#' @param receipt_sha256 With `receipt_asset`: the SHA-256 of the published receipt's
#'   bytes, as [crt_receipt_write()] returns it.
#'
#' @return A list of `stac_extensions` (a character vector marked [I()], so a JSON
#'   writer keeps it an array), `properties` and `assets` (named lists).
#'
#' @seealso [crt_receipt_write()], [crt_receipt_read()].
#'
#' @examples
#' wc <- system.file("extdata", "receipt", "examples", "worked_case", "build_1",
#'                   package = "crate")
#' digest <- digest::digest(file.path(wc, "receipt.json"), algo = "sha256", file = TRUE)
#' s <- crt_receipt_stac(wc, assets = c(access = "access_check.csv"),
#'                       receipt_asset = "receipt", receipt_sha256 = digest)
#' s$properties
#' str(s$assets)
#'
#' @export
crt_receipt_stac <- function(receipt, assets = NULL, receipt_asset = NULL, receipt_sha256 = NULL) {
  if (is.character(receipt)) receipt <- crt_receipt_read(receipt)
  if (!stac_is_object(receipt)) {
    stac_refuse("block_not_object", "{.arg receipt} is not an object: it must be a receipt or a path to one.")
  }
  assets <- stac_assets_arg(assets)
  if (!is.null(receipt_asset)) {
    if (!(is.character(receipt_asset) && length(receipt_asset) == 1L && !is.na(receipt_asset))) {
      stac_refuse("receipt_asset_not_string", "{.arg receipt_asset} must be a string.")
    }
    if (!nzchar(receipt_asset)) {
      stac_refuse("receipt_asset_empty", "{.arg receipt_asset} is empty: an asset needs a key.")
    }
    if (receipt_asset %in% names(assets)) {
      stac_refuse("receipt_asset_in_assets", c(
        "Asset {.val {receipt_asset}} is both in {.arg assets} and the {.arg receipt_asset}.",
        "i" = "The receipt is not one of its own parts: give it a key of its own."
      ))
    }
    if (is.null(receipt_sha256)) {
      stac_refuse("receipt_asset_without_digest", c(
        "{.arg receipt_asset} {.val {receipt_asset}} has no {.arg receipt_sha256}.",
        "i" = "Pass the digest {.fn crt_receipt_write} returned for the bytes it wrote."
      ))
    }
  } else if (!is.null(receipt_sha256)) {
    stac_refuse("digest_without_receipt_asset",
                "{.arg receipt_sha256} is given with no {.arg receipt_asset} to carry it.")
  }
  if (!is.null(receipt_sha256)) stac_sha256(receipt_sha256, "receipt_sha256", "digest_not_sha256")

  output <- stac_block(receipt, "output")
  recipe <- stac_block(receipt, "recipe")
  result <- stac_block(receipt, "result")
  context <- stac_block(receipt, "context")

  # The form decides what every other field means, so it is checked first, on a list as
  # crt_receipt_read() checks it on a file
  v <- output[["receipt_version"]]
  if (!(is.character(v) && length(v) == 1L && !is.na(v) && v == receipt_version())) {
    stac_refuse("receipt_version_unknown", c(
      "{.field output.receipt_version} is {.val {format(v)}}, not a form this mapping reads.",
      "i" = "This mapping reads receipt form {.val {receipt_version()}}."
    ))
  }

  props <- list()
  # Only a migrated receipt has no recipe identity, and it never has one: the form's rule,
  # checked here because an item without the field reads as built from a migrated receipt
  migrated <- "migrated_from" %in% names(output)
  id <- recipe[["recipe_id"]]
  if (stac_absent(id)) {
    if (!migrated) {
      stac_refuse("recipe_id_missing", c(
        "{.field recipe.recipe_id} is missing, and the receipt was not migrated.",
        "i" = "Only a migrated receipt ({.field output.migrated_from}) has no recipe identity."
      ))
    }
  } else {
    if (migrated) {
      stac_refuse("recipe_id_on_migrated",
                  "{.field recipe.recipe_id} is set on a migrated receipt, which claims no recipe identity.")
    }
    props[["receipt:recipe_id"]] <- stac_sha256(id, "recipe.recipe_id", "recipe_id_not_sha256")
  }
  time <- context[["time"]]
  if (!stac_utc(time)) {
    stac_refuse("time_not_utc", "{.field context.time} is not a UTC date-time: {.val {format(time)}}.")
  }
  props[["processing:datetime"]] <- time
  code <- stac_block(recipe, "code", "recipe.code")
  software <- list()
  for (repo in names(code)) {
    # A repository's name is published as a key of processing:software
    if (!nzchar(repo)) stac_refuse("repo_name_empty", "{.field recipe.code} has a repository with an empty name.")
    v <- stac_block(code, repo, paste0("recipe.code[", repo, "]"))[["version"]]
    if (stac_absent(v)) next
    if (!(is.character(v) && length(v) == 1L && nzchar(v))) {
      stac_refuse("version_not_string",
                  "{.field recipe.code[{repo}].version} is not a version string: {.val {format(v)}}.")
    }
    software[[repo]] <- v
  }
  if (length(software)) props[["processing:software"]] <- software

  parts <- stac_block(result, "parts", "result.parts")
  out <- list()
  for (key in names(assets)) {
    href <- assets[[key]]
    if (!href %in% names(parts)) {
      stac_refuse("href_not_a_part", c(
        "Asset {.val {key}} has href {.val {href}}, which is not a part of this receipt.",
        "i" = "Parts are keyed by the href relative to the item: {.val {names(parts)}}."
      ))
    }
    part <- stac_block(parts, href, paste0("result.parts[", href, "]"))
    out[[key]] <- list(
      `file:checksum` = paste0("1220", stac_sha256(part[["sha256"]], paste0("result.parts[", href, "].sha256"),
                                                   "part_sha256_not_sha256")),
      `file:size` = stac_bytes(part[["bytes"]], paste0("result.parts[", href, "].bytes"))
    )
  }
  if (!is.null(receipt_asset)) {
    out[[receipt_asset]] <- list(`file:checksum` = paste0("1220", receipt_sha256))
  }

  urls <- c(
    if (length(out)) "https://stac-extensions.github.io/file/v2.1.0/schema.json",
    "https://stac-extensions.github.io/processing/v1.2.0/schema.json",
    if ("receipt:recipe_id" %in% names(props)) {
      "https://newgraphenvironment.github.io/crate/stac/receipt/v1.0.0/schema.json"
    }
  )
  list(stac_extensions = I(as.character(urls)), properties = receipt_object(props),
       assets = receipt_object(out))
}

# A refusal, classed and carrying the code that stac.json's `error` field names
stac_refuse <- function(code, message, .envir = parent.frame()) {
  cli::cli_abort(message, class = c(paste0("crate_stac_", code), "crate_stac_refused"), code = code,
                 call = NULL, .envir = .envir)
}

# Null in a file is NULL; in a receipt built in memory it is NA.
stac_absent <- function(v) is.null(v) || (is.atomic(v) && length(v) == 1L && is.na(v))

# A JSON object reads as a named list, `{}` as one with no names; an array has none at all.
stac_is_object <- function(x) is.list(x) && !is.null(names(x))

# A block or entry: absent is empty, and anything present must be an object, `null` included.
stac_block <- function(x, name, where = name) {
  if (!name %in% names(x)) return(list())
  v <- x[[name]]
  if (!stac_is_object(v)) stac_refuse("block_not_object", "{.field {where}} is present but not an object.")
  v
}

stac_sha256 <- function(x, where, code) {
  if (!(is.character(x) && length(x) == 1L && !is.na(x) && grepl("^[0-9a-f]{64}$", x))) {
    stac_refuse(code, "{.field {where}} must be a SHA-256, 64 lower-case hex digits: not {.val {format(x)}}.")
  }
  x
}

# The form's pattern, and a real instant: a month, a day that month has, an hour, a minute
# and a second that exist (the processing extension declares `format: date-time`). A leap
# second, 60, is refused, as most readers do.
stac_utc <- function(x) {
  utc <- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$"
  if (!(is.character(x) && length(x) == 1L && !is.na(x) && grepl(utc, x))) return(FALSE)
  n <- as.integer(substring(x, c(1, 6, 9, 12, 15, 18), c(4, 7, 10, 13, 16, 19)))
  leap <- (n[1] %% 4 == 0 && n[1] %% 100 != 0) || n[1] %% 400 == 0
  days <- c(31, if (leap) 29 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  n[2] >= 1 && n[2] <= 12 && n[3] >= 1 && n[3] <= days[n[2]] && n[4] <= 23 && n[5] <= 59 && n[6] <= 59
}

stac_bytes <- function(x, where) {
  if (!(is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0 && x == round(x))) {
    stac_refuse("bytes_not_whole", "{.field {where}} is not a whole number of bytes: {.val {format(x)}}.")
  }
  x
}

stac_assets_arg <- function(assets) {
  if (is.null(assets) || !length(assets)) return(stats::setNames(character(), character()))
  nm <- names(assets)
  if (!is.character(assets) || is.null(nm) || any(is.na(nm) | !nzchar(nm)) || anyDuplicated(nm)) {
    stac_refuse("assets_not_named", c(
      "{.arg assets} must be a character vector named by asset key, each key once.",
      "i" = "For example {.code c(data = \"floodplain.tif\")}."
    ))
  }
  if (anyNA(assets) || !all(nzchar(assets))) {
    stac_refuse("href_empty", "Each of {.arg assets} needs an href, relative to the item.")
  }
  assets
}
