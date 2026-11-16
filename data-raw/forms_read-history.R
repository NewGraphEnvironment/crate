# data-raw/forms_read-history.R
#
# Reads every version of the fish passage forms the sync service (Mergin Maps)
# holds, and lists each column set a crew captured records into as a variant of
# its form (#36). The variants #13 registered came from the form builder's builds and one
# live 2026 capture; this reaches back through each project's history.
#
# Usage (from repo root, in a UTF-8 locale):
#   Rscript data-raw/forms_read-history.R read    # walk + download; resumable
#   Rscript data-raw/forms_read-history.R write   # fixtures + measured table
#
# Needs the form-tooling package (>= 0.94.0) with Mergin credentials in the environment
# (MERGIN_USERNAME and MERGIN_PASSWORD, or MERGIN_AUTH), and RSQLite.
#
# ---------------------------------------------------------------------------
# What it reads, and where that goes
#
# `read` walks every version of every project the account can see
# (rfp_mergin_history(), rfp_mergin_changeset()), keeps each version of each
# GeoPackage named for one of the five forms, and fetches each distinct file
# once (rfp_mergin_file_get(), checksum-verified). It also reads each such
# version's full record through the form-tooling package's bundled helper script, for two fields
# rfp_mergin_changeset() does not return yet: which client pushed it
# (`user_agent`), and, for a GeoPackage pushed as a geodiff, the diff and the
# rows it inserted and deleted per table (`changesets`). The server rebuilds such
# a version from its base file and diffs, so the bytes it sends never match the
# checksum the pushing client computed, and rfp_mergin_file_get() refuses them
# (an open issue in that package). Those are fetched without the check and accepted only when the
# version's change for that path is a geodiff and SQLite's integrity check
# passes; `write` then checks every geodiff version's record count against the
# rows the server says it inserted and deleted. Everything is cached under
# `cache_dir`, outside the repository, because it names projects: crate is
# public, and nothing that identifies a project is committed. A re-run reads the
# cache and fetches only what is missing.
#
# `write` decides which column sets are form versions and writes, into the
# repository, only what carries no project:
#   tests/testthat/fixtures/forms/form_<form>__<id>.csv   name,type per variant
#   data-raw/forms_variants-measured.csv                  one row per variant
# and, into the cache, the measurement behind them (shapes.csv, seasons.csv,
# stems.txt). forms_derive-schemas.R reads the two committed files to register
# the variants.
#
# ---------------------------------------------------------------------------
# Rules
#
# - A file belongs to the form its name says, longest name first, after an
#   optional leading year (`2022_form_pscis_...`): `form_monitoring_fish_passage`
#   before `form_monitoring`. Archives, backups, `_raw` files, conflicted copies
#   and deployments under another name are all read; the next rule decides.
#   QGIS's `layer_styles` table is not a form table and is skipped.
# - A column set is a form version if records went into it (gate decision 2,
#   2026-11-16): some version of a file in that shape holds more records than
#   the previous version of the same path and table, in the same shape. More
#   records means a record under a key the previous version lacked, holding
#   content none of its records had: a deleted test row and a new record in
#   one sync still count, and a duplicated row or a renumbering re-export does
#   not (a 2025 archive copy's one "new" record was record 35 again). A removal starts a new chain,
#   so a file re-added later is not compared with what it held before. Growth
#   across a shape change is a rebuild carrying records over, so it does not
#   count. A processed copy uploaded once and never captured into does not count.
# - A column set must share at least half its columns with the form's build or
#   with a version already accepted, best of them, or it is not that form
#   whatever the file is called. Rejects are reported for review, not listed.
# - The build's fingerprint (first in each form's list) keeps its entry; it is
#   counted here, not added again. Every other variant is this script's
#   output, measured afresh on each run.
# - A new variant is named for the month it first gained records,
#   `capture-YYYY-MM`, with `-a`, `-b` where two share a month, in fingerprint
#   order, the letters continuing past any already listed. An id a schema
#   already lists is never renamed, because harvested tables carry it
#   (`capture-utm-columns-2025` is #13's); its `first_seen` and counts are
#   measured afresh. A listed variant the rule no longer admits stops `write`.

pkgload::load_all(quiet = TRUE)
source("data-raw/forms_gpkg-decl.R")

if (!isTRUE(l10n_info()[["UTF-8"]])) {
  stop("Run in a UTF-8 locale (e.g. LC_ALL=en_US.UTF-8); this session is ",
       Sys.getlocale("LC_CTYPE"), ".", call. = FALSE)
}

mode <- commandArgs(trailingOnly = TRUE)
if (length(mode) != 1L || !mode %in% c("read", "write")) {
  stop("Usage: Rscript data-raw/forms_read-history.R read|write", call. = FALSE)
}

cache_dir <- Sys.getenv(
  "CRATE_FORMS_HISTORY_CACHE",
  file.path(tools::R_user_dir("crate", "cache"), "forms_history")
)
for (d in c("changesets", "raw", "files", "meta", "agents")) {
  dir.create(file.path(cache_dir, d), recursive = TRUE, showWarnings = FALSE)
}

forms <- c("monitoring_fish_passage", "monitoring_general", "fiss_site", "pscis",
           "monitoring")
form_re <- sprintf("^(?:[0-9]{4}_)?form_(%s)", paste(forms, collapse = "|"))

py_bin <- rfp:::rfp_mergin_py_bin()
py_script <- rfp:::rfp_mergin_py_script("mergin_history.py")


form_of <- function(path) {
  m <- regmatches(basename(path), regexec(form_re, basename(path), perl = TRUE))
  vapply(m, function(x) if (length(x) == 2) x[[2]] else NA_character_, character(1))
}

# One call, retried once: a long walk meets the odd dropped connection, and a
# failure that stays is recorded, not skipped (`write` refuses while any remain).
retry <- function(expr_fn, what) {
  for (i in 1:2) {
    out <- tryCatch(suppressMessages(expr_fn()), error = function(e) e)
    if (!inherits(out, "error")) return(out)
    if (i == 1) Sys.sleep(5)
  }
  message("FAILED ", what, ": ", conditionMessage(out))
  out
}

safe <- function(x) gsub("[^A-Za-z0-9_.-]", "_", x)

# A version's full record from the server, as the form-tooling package's helper script returns it,
# cached as JSON. NULL when it cannot be read.
raw_changeset <- function(p, v) {
  f <- file.path(cache_dir, "raw", paste0(safe(p), "__", v, ".json"))
  if (!file.exists(f)) {
    out <- retry(function() {
      o <- system2(py_bin, c(shQuote(py_script), "changeset", "--project", shQuote(p),
                             "--version", shQuote(v)),
                   stdout = TRUE, stderr = FALSE)
      if (!is.null(attr(o, "status"))) stop("exit ", attr(o, "status"))
      jsonlite::fromJSON(paste(o, collapse = ""), simplifyDataFrame = FALSE)
      o
    }, paste("raw", p, v))
    if (inherits(out, "error")) return(NULL)
    writeLines(out, f)
  }
  jsonlite::fromJSON(paste(readLines(f), collapse = ""), simplifyDataFrame = FALSE)
}

# The geodiff a version pushed for one path, or NULL when the path was uploaded
# whole: list(summary = per-table insert/update/delete).
diff_of <- function(raw, path) {
  for (e in raw$changes$updated) {
    if (identical(e$path, path) && !is.null(e$diff)) {
      return(list(summary = raw$changesets[[path]]$summary))
    }
  }
  NULL
}

# A file the server rebuilt from geodiffs: fetched without the checksum check,
# kept only if the change was a geodiff and SQLite finds the file intact.
fetch_rebuilt <- function(r, gpkg) {
  raw <- raw_changeset(r$project, r$version)
  if (is.null(raw)) stop("version record unreadable")
  if (is.null(diff_of(raw, r$path))) stop("checksum mismatch on a file pushed whole")
  tmp <- paste0(gpkg, ".part")
  on.exit(unlink(tmp))
  suppressMessages(rfp:::rfp_mergin_download_file(r$project, r$path, r$version, tmp))
  con <- DBI::dbConnect(RSQLite::SQLite(), tmp, flags = RSQLite::SQLITE_RO)
  ok <- DBI::dbGetQuery(con, "PRAGMA integrity_check")[[1]]
  DBI::dbDisconnect(con)
  if (!identical(ok, "ok")) stop("integrity check: ", paste(ok, collapse = "; "))
  if (!file.rename(tmp, gpkg)) stop("could not move into the cache")
  cat(r$checksum, "\n", sep = "", file = file.path(cache_dir, "rebuilt.txt"), append = TRUE)
  invisible(gpkg)
}

# Each record's key and a hash of everything else it holds, geometry included,
# so a later version's new records can be told from copies of old ones.
row_hashes <- function(con, t, pk) {
  d <- DBI::dbGetQuery(con, sprintf('SELECT * FROM "%s"', t))
  if (!nrow(d)) return(data.frame(pk = character(0), h = character(0)))
  as_text <- function(v) {
    if (is.list(v)) {
      vapply(v, function(r) if (is.null(r)) "\001" else paste(as.character(r), collapse = ""), "")
    } else {
      ifelse(is.na(v), "\001", as.character(v))
    }
  }
  txt <- do.call(paste, c(lapply(d[setdiff(names(d), pk)], as_text), sep = "\037"))
  key <- do.call(paste, c(lapply(d[pk], as.character), sep = "\037"))
  data.frame(pk = key,
             h = vapply(txt, digest::digest, "", algo = "xxhash64", serialize = FALSE,
                        USE.NAMES = FALSE),
             stringsAsFactors = FALSE)
}

# What one file holds, per form table: declared types, fingerprint, records,
# largest row id, and whether its primary key is the single INTEGER a harvest
# drops as the row id (if not, a harvester's column set may differ).
file_meta <- function(checksum) {
  gpkg <- file.path(cache_dir, "files", paste0(checksum, ".gpkg"))
  tables <- setdiff(gpkg_tables(gpkg), "layer_styles")
  con <- DBI::dbConnect(RSQLite::SQLite(), gpkg, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con))
  lapply(tables, function(t) {
    info <- DBI::dbGetQuery(con, sprintf('PRAGMA table_info("%s")', t))
    pk <- info$name[info$pk > 0]
    int_pk <- length(pk) == 1 && toupper(info$type[info$pk > 0]) == "INTEGER"
    max_pk <- if (int_pk) {
      DBI::dbGetQuery(con, sprintf('SELECT max("%s") AS m FROM "%s"', pk, t))$m
    } else {
      NA
    }
    decl <- gpkg_decl(gpkg, t)
    list(table = t, decl = decl, fingerprint = crt_schema_fingerprint(decl),
         n = gpkg_nrow(gpkg, t), max_pk = as.numeric(max_pk), int_pk = int_pk,
         rows = row_hashes(con, t, pk))
  })
}

# What a cached record was read with: the code that turns a file into one. A
# record is keyed by the file's checksum, so without this a change to how a
# file is read would leave every cached record as the old code read it.
# The runtime is in it too: a row hash is text R and RSQLite make of a value.
reader_version <- function() {
  digest::digest(c(deparse(gpkg_tables), deparse(gpkg_decl), deparse(gpkg_nrow),
                   deparse(file_meta),
                   deparse(row_hashes), deparse(crt_schema_fingerprint),
                   R.version.string, as.character(utils::packageVersion("RSQLite")),
                   as.character(utils::packageVersion("DBI")),
                   as.character(utils::packageVersion("digest"))),
                 algo = "xxhash64")
}

# A version's server record is cached by project name and version number, and
# a name does not identify a project: one deleted and created again reuses it.
# So each cached record carries the version's creation time, and a record whose
# time is not the history's is fetched again (`read`) or refused (`write`).
same_time <- function(a, b) {
  identical(format(as.POSIXct(a, tz = "UTC"), "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
            format(as.POSIXct(b, tz = "UTC"), "%Y-%m-%dT%H:%M:%S", tz = "UTC"))
}
raw_time <- function(raw) as.POSIXct(raw$created, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")

meta_current <- function(meta_f, reader = reader_version()) {
  file.exists(meta_f) && identical(attr(readRDS(meta_f), "reader"), reader)
}

# ---- one row per (project, path, version, table), with growth ----------------

versions_table <- function(walk) {
  rows <- lapply(seq_len(nrow(walk)), function(i) {
    r <- walk[i, ]
    base <- data.frame(project = r$project, path = r$path, form = r$form,
                       version = r$version, vnum = as.integer(sub("^v", "", r$version)),
                       created = r$created, change = r$change, checksum = r$checksum,
                       stringsAsFactors = FALSE)
    na <- data.frame(table = NA_character_, fingerprint = NA_character_, n = NA_real_,
                     max_pk = NA_real_, int_pk = NA, stringsAsFactors = FALSE)
    na <- cbind(base, na)
    na$rows <- list(NULL)
    if (r$change == "removed") return(na)
    meta_f <- file.path(cache_dir, "meta", paste0(r$checksum, ".rds"))
    if (!file.exists(meta_f)) return(na)
    meta <- readRDS(meta_f)
    if (!length(meta)) return(na)
    do.call(rbind, lapply(meta, function(m) {
      out <- cbind(base, data.frame(table = m$table, fingerprint = m$fingerprint,
                                    n = as.numeric(m$n), max_pk = m$max_pk, int_pk = m$int_pk,
                                    stringsAsFactors = FALSE))
      out$rows <- list(m$rows)
      out
    }))
  })
  vt <- do.call(rbind, rows)

  vt <- vt[order(vt$project, vt$path, vt$vnum, method = "radix"), ]
  vt$seg <- ave(as.integer(vt$change == "removed"), vt$project, vt$path, FUN = cumsum)
  vt <- vt[!is.na(vt$fingerprint), ]
  vt$chain <- paste(vt$project, vt$path, vt$seg, vt$table, sep = "\r")
  vt <- vt[order(vt$chain, vt$vnum, method = "radix"), ]
  # Grew: same chain and shape as the version before, and holding a record
  # with a key that version lacked and content none of its records had. A copy
  # of an old record under a new key (a duplicated row, a re-export that
  # renumbers) is not a record going in.
  prev <- c(NA, utils::head(seq_len(nrow(vt)), -1))
  prev[c(TRUE, vt$chain[-1] != vt$chain[-nrow(vt)])] <- NA
  vt$new_records <- vapply(seq_len(nrow(vt)), function(i) {
    j <- prev[i]
    if (is.na(j) || vt$fingerprint[j] != vt$fingerprint[i]) return(NA_integer_)
    a <- vt$rows[[j]]
    b <- vt$rows[[i]]
    sum(!b$pk %in% a$pk & !b$h %in% a$h)
  }, integer(1))
  vt$grew <- !is.na(vt$new_records) & vt$new_records > 0
  vt$rows <- NULL
  vt
}

# ---- read ---------------------------------------------------------------------

read_history <- function() {
  # Until this run ends, the history is incomplete: `write` must not trust a
  # previous run's empty failure list.
  writeLines("read in progress or interrupted", file.path(cache_dir, "failures.txt"))
  ws <- suppressMessages(rfp::rfp_mergin_workspaces())$name
  projects <- unique(unlist(lapply(ws, function(w) {
    suppressMessages(rfp::rfp_mergin_list(w))$project
  })))
  message(length(projects), " projects")
  failures <- character(0)

  walk <- list()
  for (p in projects) {
    h <- retry(function() rfp::rfp_mergin_history(p), paste("history", p))
    if (inherits(h, "error")) {
      failures <- c(failures, paste("history", p))
      next
    }
    for (v in h$version) {
      f <- file.path(cache_dir, "changesets", paste0(safe(p), "__", v, ".rds"))
      when <- h$created[h$version == v]
      cs <- if (file.exists(f)) readRDS(f)
      # A record cached before it carried a time takes the history's: the 357
      # form-file versions among them were checked against their own server
      # record's time (2026-11-16), and `write` checks those again every run.
      if (!is.null(cs) && is.null(attr(cs, "created"))) {
        attr(cs, "created") <- when
        saveRDS(cs, f)
      }
      if (is.null(cs) || !same_time(attr(cs, "created"), when)) {
        unlink(file.path(cache_dir, "raw", paste0(safe(p), "__", v, ".json")))
        cs <- retry(function() rfp::rfp_mergin_changeset(p, v), paste("changeset", p, v))
        if (inherits(cs, "error")) {
          failures <- c(failures, paste("changeset", p, v))
          next
        }
        attr(cs, "created") <- when
        saveRDS(cs, f)
      }
      cs <- cs[grepl("[.]gpkg$", cs$path) & !is.na(form_of(cs$path)), ]
      if (nrow(cs)) {
        cs$created <- h$created[h$version == v]
        walk[[length(walk) + 1]] <- cs
      }
    }
    message(p, ": ", nrow(h), " versions")
  }
  walk <- do.call(rbind, walk)
  walk$form <- form_of(walk$path)
  saveRDS(walk, file.path(cache_dir, "walk.rds"))

  got <- walk[walk$change != "removed", ]
  got <- got[!duplicated(got$checksum), ]
  message(nrow(got), " distinct form files to read")
  reader <- reader_version()
  for (i in seq_len(nrow(got))) {
    r <- got[i, ]
    meta_f <- file.path(cache_dir, "meta", paste0(r$checksum, ".rds"))
    gpkg <- file.path(cache_dir, "files", paste0(r$checksum, ".gpkg"))
    if (!file.exists(gpkg)) {
      # Fetched beside the cache path and moved in only once checked, so a
      # failed download never leaves a file a later run would take as read.
      fetch <- function() {
        part <- paste0(gpkg, ".part")
        on.exit(unlink(part))
        suppressMessages(rfp::rfp_mergin_file_get(r$project, r$path, part, r$version,
                                                  overwrite = TRUE))
        if (!file.rename(part, gpkg)) stop("could not move into the cache")
        gpkg
      }
      res <- tryCatch(fetch(), error = function(e) e)
      if (inherits(res, "error") && grepl("Checksum mismatch", conditionMessage(res))) {
        res <- retry(function() fetch_rebuilt(r, gpkg),
                     paste("rebuilt", r$project, r$path, r$version))
      } else if (inherits(res, "error")) {
        res <- retry(fetch, paste("file", r$project, r$path, r$version))
      }
      if (inherits(res, "error")) {
        failures <- c(failures, paste("file", r$project, r$path, r$version))
        next
      }
    }
    # Re-read when the cached record was read by other code.
    if (!meta_current(meta_f, reader)) {
      saveRDS(structure(file_meta(r$checksum), reader = reader), meta_f)
    }
    if (i %% 25 == 0) message(i, "/", nrow(got), " read")
  }

  # Every form-file version's full record: which client pushed it, and its
  # geodiffs, which `write` checks the record counts against.
  need <- unique(walk[walk$change != "removed", c("project", "version")])
  message(nrow(need), " versions; reading their records")
  for (i in seq_len(nrow(need))) {
    p <- need$project[i]
    v <- need$version[i]
    raw <- raw_changeset(p, v)
    if (is.null(raw)) {
      failures <- c(failures, paste("raw", p, v))
      next
    }
    writeLines(if (is.null(raw$user_agent)) "" else raw$user_agent,
               file.path(cache_dir, "agents", paste0(safe(p), "__", v, ".txt")))
    if (i %% 50 == 0) message(i, "/", nrow(need), " records")
  }

  writeLines(failures, file.path(cache_dir, "failures.txt"))
  message("done; ", length(failures), " failures (", file.path(cache_dir, "failures.txt"), ")")
}

# ---- write --------------------------------------------------------------------

client_of <- function(ua) {
  out <- rep("other", length(ua))
  out[grepl("Plugin/|QGIS|Python-client|Mergin-SDK", ua, ignore.case = TRUE)] <- "desktop"
  out[grepl("android|ios|iphone|ipad|Input/|MerginMaps", ua, ignore.case = TRUE)] <- "mobile"
  out[is.na(ua)] <- NA_character_
  out
}

fixture_decl <- function(form, id) {
  x <- utils::read.csv(
    sprintf("tests/testthat/fixtures/forms/form_%s__%s.csv", form, id),
    colClasses = "character"
  )
  stats::setNames(x$type, x$name)
}

write_variants <- function() {
  failures <- readLines(file.path(cache_dir, "failures.txt"))
  if (length(failures)) {
    stop(length(failures), " reads failed; re-run `read` until none remain:\n",
         paste(utils::head(failures, 10), collapse = "\n"), call. = FALSE)
  }
  walk <- readRDS(file.path(cache_dir, "walk.rds"))
  # Every form file and every version record must have been read: a version
  # with neither would drop out of the table below without a word.
  got <- walk[walk$change != "removed", ]
  reader <- reader_version()
  no_meta <- !vapply(file.path(cache_dir, "meta", paste0(got$checksum, ".rds")),
                     meta_current, logical(1), reader = reader)
  no_raw <- !file.exists(file.path(cache_dir, "raw",
                                   paste0(safe(got$project), "__", got$version, ".json")))
  # And each version record is the one the history names, by its time.
  stale_raw <- !no_raw & !vapply(seq_len(nrow(got)), function(i) {
    raw <- jsonlite::fromJSON(paste(readLines(file.path(
      cache_dir, "raw", paste0(safe(got$project[i]), "__", got$version[i], ".json"))),
      collapse = ""), simplifyDataFrame = FALSE)
    same_time(raw_time(raw), got$created[i])
  }, logical(1))
  if (any(stale_raw)) {
    stop(sum(stale_raw), " version records are not the versions the history names ",
         "(a project re-created under its name?); delete them and re-run `read`.",
         call. = FALSE)
  }
  if (any(no_meta | no_raw)) {
    stop(sum(no_meta), " form files (unread, or read by other code) and ", sum(no_raw),
         " version records are not read; ",
         "re-run `read`.", call. = FALSE)
  }
  vt <- versions_table(walk)
  af <- file.path(cache_dir, "agents", paste0(safe(vt$project), "__", vt$version, ".txt"))
  vt$agent <- vapply(af, function(f) if (file.exists(f)) readLines(f, n = 1) else NA_character_,
                     character(1), USE.NAMES = FALSE)
  vt$client <- client_of(vt$agent)
  if (any(vt$grew & is.na(vt$client))) stop("A version with growth has no client read; re-run `read`.")

  # A version pushed as a geodiff must hold exactly the records its diff says:
  # the count before it, plus the rows inserted, minus the rows deleted. This is
  # what makes a file the server rebuilt a measurement and not a guess.
  prev_n <- ave(vt$n, vt$chain, FUN = function(y) c(NA, utils::head(y, -1)))
  vt$diff_ok <- NA
  for (i in which(vt$change == "updated" & !is.na(prev_n))) {
    raw <- raw_changeset(vt$project[i], vt$version[i])
    d <- diff_of(raw, vt$path[i])
    if (is.null(d)) next
    s <- Filter(function(x) identical(x$table, vt$table[i]), d$summary)
    delta <- if (length(s)) s[[1]]$insert - s[[1]]$delete else 0
    vt$diff_ok[i] <- vt$n[i] - prev_n[i] == delta
  }
  rb <- file.path(cache_dir, "rebuilt.txt")
  rebuilt <- if (file.exists(rb)) unique(readLines(rb)) else character(0)
  message(sum(!is.na(vt$diff_ok)), " geodiff versions checked against their diff (",
          sum(vt$checksum %in% rebuilt & !is.na(vt$diff_ok)), " rebuilt by the server); ",
          sum(vt$diff_ok %in% FALSE), " disagree")
  if (any(vt$diff_ok %in% FALSE)) {
    bad <- vt[vt$diff_ok %in% FALSE, c("form", "version", "n")]
    stop("Record counts disagree with their geodiff:\n",
         paste(utils::capture.output(print(utils::head(bad, 10))), collapse = "\n"),
         call. = FALSE)
  }
  saveRDS(vt, file.path(cache_dir, "versions.rds"))

  decl_of <- list()
  for (f in list.files(file.path(cache_dir, "meta"), full.names = TRUE)) {
    for (m in readRDS(f)) decl_of[[m$fingerprint]] <- m$decl
  }

  report <- list()
  for (form in forms) {
    schema <- crt_schema_get("nge", paste0("form_", form))
    build <- names(fixture_decl(form, schema$upstream_variants[[1]]$id))
    # The build, first in every form's list; the rest are this script's own
    # output, so a re-run measures them again rather than keeping them.
    listed <- schema$upstream_variants[[1]]$fingerprint
    v <- vt[vt$form == form, ]
    rows <- lapply(unique(v$fingerprint), function(fp) {
      w <- v[v$fingerprint == fp, ]
      g <- w[w$grew, ]
      data.frame(
        form = form, fingerprint = fp, n_cols = length(decl_of[[fp]]),
        listed = fp %in% listed, grew = nrow(g) > 0,
        grew_mobile = sum(g$client == "mobile"), grew_desktop = sum(g$client != "mobile"),
        first_grew = if (nrow(g)) format(min(g$created), "%Y-%m") else NA_character_,
        years_grew = paste(sort(unique(format(g$created, "%Y"))), collapse = " "),
        first_seen = format(min(w$created), "%Y-%m"),
        n_versions = nrow(w), n_versions_grew = nrow(g),
        n_projects = length(unique(w$project)),
        n_projects_grew = length(unique(g$project)),
        non_int_pk = any(!w$int_pk),
        stringsAsFactors = FALSE
      )
    })
    r <- do.call(rbind, rows)
    if (is.null(r)) next
    # Overlap: share of a shape's columns found in the build or in a version
    # already accepted, best of them, accepting until nothing changes.
    refs <- list(build)
    r$overlap <- NA_real_
    r$accepted <- FALSE
    repeat {
      changed <- FALSE
      for (i in which(r$grew & !r$accepted)) {
        cols <- names(decl_of[[r$fingerprint[i]]])
        ov <- max(vapply(refs, function(ref) length(intersect(cols, ref)) / length(cols), 0))
        r$overlap[i] <- round(ov, 2)
        if (ov >= 0.5) {
          r$accepted[i] <- TRUE
          refs[[length(refs) + 1]] <- cols
          changed <- TRUE
        }
      }
      if (!changed) break
    }
    for (i in which(!r$grew)) {
      cols <- names(decl_of[[r$fingerprint[i]]])
      r$overlap[i] <- round(max(vapply(refs, function(ref) {
        length(intersect(cols, ref)) / max(length(cols), 1)
      }, 0)), 2)
    }
    report[[form]] <- r
  }
  report <- do.call(rbind, report)
  utils::write.csv(report, file.path(cache_dir, "shapes.csv"), row.names = FALSE)

  # Per season: how many accepted shapes took records that year.
  acc <- report[report$accepted, ]
  seasons <- do.call(rbind, lapply(forms, function(f) {
    yrs <- unlist(strsplit(acc$years_grew[acc$form == f], " "))
    data.frame(form = f, year = as.character(2023:2026),
               shapes = vapply(as.character(2023:2026), function(y) sum(yrs == y), 0L))
  }))
  utils::write.csv(seasons, file.path(cache_dir, "seasons.csv"), row.names = FALSE)

  # Everything that names a project or a deployment, for the privacy grep.
  stems <- unique(c(sub("^[^/]*/", "", vt$project), vt$project,
                    sub("[.]gpkg$", "", basename(walk$path))))
  writeLines(stems, file.path(cache_dir, "stems.txt"))

  # An id a schema already lists is kept: harvested tables carry it. Only a
  # fingerprint no schema lists is named, and a listed one the rule no longer
  # admits stops the run rather than vanish.
  key <- function(f, fp) paste(f, fp)
  published <- do.call(rbind, lapply(forms, function(form) {
    vs <- crt_schema_get("nge", paste0("form_", form))$upstream_variants[-1]
    if (!length(vs)) return(NULL)
    data.frame(form = form, fingerprint = vapply(vs, `[[`, "", "fingerprint"),
               id = vapply(vs, `[[`, "", "id"), stringsAsFactors = FALSE)
  }))
  if (is.null(published)) {
    published <- data.frame(form = character(0), fingerprint = character(0), id = character(0))
  }
  admitted <- key(report$form, report$fingerprint)[report$accepted]
  gone <- published[!key(published$form, published$fingerprint) %in% admitted, ]
  if (nrow(gone)) {
    stop("Listed variants the history no longer admits: ",
         paste0("form_", gone$form, " ", gone$id, collapse = ", "), call. = FALSE)
  }

  keep <- report[report$accepted, ]
  keep <- keep[order(keep$form, keep$first_grew, keep$fingerprint, method = "radix"), ]
  keep$id <- published$id[match(key(keep$form, keep$fingerprint),
                                key(published$form, published$fingerprint))]
  for (form in unique(keep$form)) {
    k <- which(keep$form == form & !keep$listed & is.na(keep$id))
    used <- keep$id[keep$form == form & !is.na(keep$id)]
    for (i in k) {
      month <- keep$first_grew[i]
      base <- paste0("capture-", month)
      kin <- used[used == base | startsWith(used, paste0(base, "-"))]
      if (!length(kin) && sum(keep$first_grew[k] == month) == 1) {
        id <- base
      } else {
        taken <- sub(paste0("^", base, "-?"), "", kin)
        taken[taken == ""] <- "a"
        id <- paste0(base, "-", setdiff(letters, taken)[1])
      }
      keep$id[i] <- id
      used <- c(used, id)
    }
  }

  # The builds stay as the form builder's derive writes them; the measured table holds the rest.
  out <- keep[!keep$listed, ]
  for (i in seq_len(nrow(out))) {
    decl <- decl_of[[out$fingerprint[i]]]
    bad <- grepl("[,\"\r\n]", names(decl))
    if (any(bad)) stop("A column name a CSV fixture cannot hold: ", names(decl)[bad][1])
    fx <- sprintf("tests/testthat/fixtures/forms/form_%s__%s.csv", out$form[i], out$id[i])
    utils::write.csv(data.frame(name = names(decl), type = unname(decl)), fx,
                     row.names = FALSE, quote = FALSE)
  }
  measured <- data.frame(
    form = paste0("form_", out$form), id = out$id, fingerprint = out$fingerprint,
    first_seen = out$first_grew, n_versions = out$n_versions_grew,
    n_projects = out$n_projects_grew,
    # How records reached it: the field app, or only a desktop client (a
    # processed copy added to by hand).
    grew_from = c("the field app and a desktop client", "the field app",
                  "a desktop client only")[1 + (out$grew_desktop == 0) + 2 * (out$grew_mobile == 0)],
    stringsAsFactors = FALSE
  )
  utils::write.csv(measured, "data-raw/forms_variants-measured.csv", row.names = FALSE)
  message("wrote ", nrow(measured), " measured variants; shapes report at ",
          file.path(cache_dir, "shapes.csv"))
}

if (mode == "read") read_history() else write_variants()
