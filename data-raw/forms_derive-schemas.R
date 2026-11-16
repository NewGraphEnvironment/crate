# data-raw/forms_derive-schemas.R
#
# Derives the five fish passage form schemas (inst/extdata/schemas/nge/form_*.yaml)
# from the field definitions rfp builds those forms from, so what a column means
# is taken from where it is already written rather than restated beside it (#13).
#
# Usage (from repo root):
#   Rscript data-raw/forms_derive-schemas.R
#
# Needs `gh` authenticated with read access to NewGraphEnvironment/rfp, and the
# R packages RSQLite and xml2, which crate itself does not import.
#
# ---------------------------------------------------------------------------
# A one-off bootstrap, not a sync.
#
# Each rfp CSV row mixes two kinds of fact. What the column means -- its name,
# type, units, allowed values, range and help -- comes here. How the form shows
# it -- widget, tab, order, label, default and constraint expressions -- stays
# with the form builder. Once rfp reads meaning from crate (an open rfp issue), its CSVs
# stop carrying the meaning columns, this script has nothing to read, and the
# YAML written here is the source of truth. Until then, re-running it at a newer
# rfp_sha is how a form change reaches crate.
#
# Re-running at the same rfp_sha rewrites every file byte-identically.
#
# ---------------------------------------------------------------------------
# What it writes
#
#   inst/extdata/schemas/nge/form_<form>.yaml          one per form
#   tests/testthat/fixtures/forms/form_<form>__<variant>.csv
#       (a variant's full column set lives here, not in the YAML's
#       `upstream_variants[].cols`, which elsewhere in crate means the whole
#       set a reader matches against; the fingerprint identifies the shape)
#       name,type of the rfp build's capture columns, as the GeoPackage declares
#       them. test-crt_form_schemas.R recomputes each listed fingerprint from it.
#
# It reads, and does not write, the versions crews captured into, which
# forms_read-history.R measured off the sync service's history (#36):
# data-raw/forms_variants-measured.csv and each one's fixture. Their column sets
# come from field captures, which have no public source, so they are committed
# as measured. Each is listed after the build, with a description written from
# its columns against the build's, and any column only they have is declared.
#
# ---------------------------------------------------------------------------
# Rules, each one a measured fact about the rfp files at rfp_sha (2026-10-30)
#
# - Type: rfp's `text`, `integer`, `real`, `datetime`, `boolean` map to crate's
#   string, integer, double, datetime, logical. Except a dropdown whose choices
#   are not numbers is `string` whatever rfp declares: fiss_site declares seven
#   `real` method columns whose choices are text, and typing them as double
#   would turn every value into NA. Filed against rfp.
# - Units: the label's trailing parentheses only when they hold a unit on
#   `unit_tokens` -- 12 of the 23 trailing parentheses in these labels are
#   scales or examples, e.g. "(scale 1 low - 5 high)". Otherwise the name's
#   suffix (`_m`, `_meters`, `_cm`, `_c`, `_percent`, `_m_s_cm`), which is where
#   rfp's README says a field-local unit lives; fiss_site has 143 of 149 labels
#   blank. Where the label and the name disagree the label wins, being what the
#   crew reads beside the box: pscis `outlet_pool_depth_0_01m` is labelled
#   "(m)".
# - Values: a dropdown's choices, `Label=code` split on the last `=`; a
#   checkbox's two stored values. QGIS's `<NULL>` placeholder and blank
#   choices are dropped.
# - Range: a spin box's `min|max`, unless it is what QGIS writes when no range
#   was set (the 32-bit integer limits, or the largest double).
# - A blank checkbox state is dropped, while rfp's builder would store "" for
#   it. None occurs at rfp_sha; if one does, declare "" deliberately.
# - A field with no form tab (blank `group`, or absent from the QML's tab
#   layout) is not on the form a crew fills in, and is null until filled after
#   the visit.
# - monitoring has no CSV. Its QML carries widgets and choices but no labels
#   or help, so its columns carry types, vocabularies and ranges only.

pkgload::load_all(quiet = TRUE)

# Text is written as the session reads it, so a non-UTF-8 session escapes any
# non-ASCII help or column name in what it writes. Refuse rather than write it.
if (!isTRUE(l10n_info()[["UTF-8"]])) {
  stop("Run in a UTF-8 locale (e.g. LC_ALL=en_US.UTF-8); this session is ",
       Sys.getlocale("LC_CTYPE"), ".", call. = FALSE)
}

rfp_sha <- "a901caaab7b27670ea33a64228e7904c045e995e"
rfp_repo <- "NewGraphEnvironment/rfp"

forms <- c("pscis", "fiss_site", "monitoring_fish_passage", "monitoring_general",
           "monitoring")

unit_tokens <- c("m", "cm", "mm", "km", "%", "m/m", "s", "epoch s")
# Name patterns, tried in order. `_m_s_cm` comes first because it is
# conductivity in mS/cm and would otherwise read as centimetres; `_m_2` is the
# second of a repeated measurement in metres. `_m_time` is not a length and
# matches none of them.
unit_suffix <- c(`_m_s_cm$` = "mS/cm", `_(meters|metres)$` = "m",
                 `_m(_[0-9]+)?$` = "m", `_cm$` = "cm", `_mm$` = "mm",
                 `_c$` = "degrees C", `_percent$` = "%")
# What QGIS writes for a spin box with no range set: the 32-bit integer limits
# on an integer field, the largest double on a real one.
unset_range <- function(b) {
  identical(b, c(-2147483648, 2147483647)) || any(abs(b) >= .Machine$double.xmax / 2)
}

photo_note <- c(
  rfp = "Path of a photo taken in the form, relative to the project root, under `ignore_mobile/photos/`.",
  qml = "Path of a photo taken in the form, relative to the project root, under `photos/`."
)
null_offform <- paste(
  "Not on the form a crew fills in: an office or computed field, null until",
  "filled after the visit."
)

# Where a form stands relative to the others, for a form that has been
# superseded. Appended to its description.
form_status <- list(
  monitoring = paste(
    "`form_monitoring` is the earlier monitoring form, one form for crossing",
    "assessment, effectiveness monitoring rated 1 to 5, and restoration sites.",
    "It is retired for new work: fish passage effectiveness monitoring uses",
    "`form_monitoring_fish_passage`, which records one written statement per",
    "metric in place of the ratings, and restoration-site monitoring uses",
    "`form_monitoring_general`. This schema is kept so that records from earlier",
    "seasons, and from projects that still deploy the form, can be read."
  )
)

# The versions of each form crews captured records into, read off the sync
# service's history by forms_read-history.R (#36): one row per version, its
# column set in tests/testthat/fixtures/forms/form_<form>__<id>.csv.
measured <- utils::read.csv("data-raw/forms_variants-measured.csv",
                            colClasses = "character", na.strings = character())

# What a column only an earlier version had means, where that is known. The
# rest carry their type and which versions have them, which is all the history
# says about them.
earlier_meaning <- list(
  rowid = list(notes = "A row number."),
  utm_zone = list(notes = "UTM zone of `easting` and `northing`."),
  easting = list(units = "m", notes = "UTM easting."),
  northing = list(units = "m", notes = "UTM northing.")
)

month_name <- function(ym) {
  if (grepl("^[0-9]{4}$", ym)) return(ym)
  # month.name, not format("%B"), which follows the session's locale.
  paste(month.name[as.integer(substr(ym, 6, 7))], substr(ym, 1, 4))
}

code_list <- function(x, max = 10) {
  if (length(x) > max) return(paste(length(x), "columns"))
  x <- paste0("`", x, "`")
  if (length(x) < 2) return(x)
  paste(paste(utils::head(x, -1), collapse = ", "), "and", x[length(x)])
}

# A variant's entry, its description written from its columns against the
# build's, so it says whether the two nest or rename.
measured_variant <- function(form, row, build_types) {
  build <- names(build_types)
  fx <- sprintf("tests/testthat/fixtures/forms/form_%s__%s.csv", form, row$id)
  t <- utils::read.csv(fx, colClasses = "character")
  decl <- stats::setNames(t$type, t$name)
  fp <- crt_schema_fingerprint(decl)
  if (!identical(fp, row$fingerprint)) {
    stop(fx, " fingerprints to ", fp, ", not ", row$fingerprint, call. = FALSE)
  }
  lacks <- setdiff(build, names(decl))
  carries <- setdiff(names(decl), build)
  where <- paste0(
    "A version records went into, first in ", month_name(row$first_seen),
    " (", length(decl), " columns; records were added to it in ", row$n_versions,
    " version", if (row$n_versions != "1") "s", " of the form across ",
    row$n_projects, " project", if (row$n_projects != "1") "s", ", from ",
    row$grew_from, ", read from the sync service's history)."
  )
  # "rename" only where each side has columns the other lacks; the tests hold
  # the description to that.
  shape <- if (length(carries) && length(lacks)) {
    paste0(
      " It lacks ", code_list(lacks), " and carries ", code_list(carries, max = Inf),
      ", which the build does not. The two therefore rename rather than nest: a ",
      "null in either set of columns means the form did not have it."
    )
  } else if (length(carries)) {
    paste0(" The build is nested in it: it has every build column and also ",
           code_list(carries, max = Inf), ".")
  } else if (length(lacks)) {
    paste0(" It is nested in the build, lacking ", code_list(lacks), ".")
  } else {
    differ <- names(decl)[decl != build_types[names(decl)]]
    paste0(" It has the build's columns, declaring ", code_list(differ),
           " with another type.")
  }
  list(id = row$id, description = paste0(where, shape), fingerprint = fp,
       normalize_fn = "reader-supplied", first_seen = row$first_seen)
}

# Columns earlier versions have and the build does not, declared so a record
# from one conforms with them typed (gate decision, #36). Typed from the
# versions' declarations; where they disagree, a string holds both.
earlier_cols <- function(form, rows, build) {
  decls <- lapply(rows$id, function(id) {
    t <- utils::read.csv(sprintf("tests/testthat/fixtures/forms/form_%s__%s.csv", form, id),
                         colClasses = "character")
    stats::setNames(t$type, t$name)
  })
  names(decls) <- rows$id
  extra <- unique(unlist(lapply(decls, function(d) setdiff(names(d), build))))
  lapply(extra, function(nm) {
    has <- names(decls)[vapply(decls, function(d) nm %in% names(d), logical(1))]
    types <- unique(type_of(vapply(decls[has], function(d) d[[nm]], "")))
    m <- earlier_meaning[[nm]]
    # `variants` says which versions carry it, so a reader of crt_schema_cols()
    # (a form builder) can leave it out of a new form (gate decision, #36).
    out <- list(name = nm, type = if (length(types) == 1) types else "string",
                required = FALSE, units = m$units,
                notes = paste(c(m$notes, "Only in earlier versions, not in the build."),
                              collapse = " "),
                variants = as.list(has))
    out[!vapply(out, is.null, logical(1))]
  })
}

# A column an earlier version shares with the build but declares as another
# type. The build's type stands where the earlier declaration converts to it
# without loss, or the build's type is a string; otherwise the column's type is
# decided here, on the values those versions hold, and the derive stops on any
# conflict not decided.
#   monitoring `site_id`: REAL in the build, TEXT in `capture-2024-09-b`, where
#   17 of 18 distinct values are site names that a double would turn into NA.
#   A string (gate decision, 2026-11-16), as monitoring_general declares it.
shared_type <- list(monitoring = c(site_id = "string"))
# Measured: a DATE conforms to a datetime at midnight UTC that day.
lossless <- c("DATE>datetime")

shared_conflicts <- function(form, rows, cols) {
  canon <- stats::setNames(vapply(cols, `[[`, "", "type"), vapply(cols, `[[`, "", "name"))
  out <- character(0)
  for (id in rows$id) {
    t <- utils::read.csv(sprintf("tests/testthat/fixtures/forms/form_%s__%s.csv", form, id),
                         colClasses = "character")
    shared <- t$name %in% names(canon)
    for (i in which(shared)) {
      nm <- t$name[i]
      if (type_of(t$type[i]) == canon[[nm]] || canon[[nm]] == "string") next
      if (paste0(sub("[(].*$", "", t$type[i]), ">", canon[[nm]]) %in% lossless) next
      if (nm %in% names(shared_type[[form]])) next
      out <- c(out, sprintf("`%s` is %s in `%s` and %s in the build", nm, t$type[i], id,
                            canon[[nm]]))
    }
  }
  out
}

grades_extra <- list(
  monitoring = list(list(
    name = "crew_attributed",
    requires = list("project", "form", "record_id", "x", "y", "surveyor_1")
  ))
)

# ---- fetching ---------------------------------------------------------------

tmp <- tempfile("rfp_forms_")
dir.create(tmp)

rfp_fetch <- function(path) {
  out <- file.path(tmp, basename(path))
  st <- system2(
    "gh",
    c("api", "-H", shQuote("Accept: application/vnd.github.raw"),
      shQuote(sprintf("repos/%s/contents/%s?ref=%s", rfp_repo, path, rfp_sha))),
    stdout = out
  )
  if (!identical(st, 0L) || file.size(out) == 0) {
    stop("Could not fetch ", path, " at rfp@", rfp_sha, call. = FALSE)
  }
  out
}

# Month the file last changed at rfp_sha: names the build's variant.
rfp_month <- function(path) {
  d <- system2(
    "gh",
    c("api", shQuote(sprintf("repos/%s/commits?path=%s&sha=%s&per_page=1",
                             rfp_repo, path, rfp_sha)),
      "--jq", shQuote(".[0].commit.committer.date")),
    stdout = TRUE
  )
  if (!length(d) || !grepl("^[0-9]{4}-[0-9]{2}", d[[1]])) {
    stop("No commit date for ", path, call. = FALSE)
  }
  substr(d[[1]], 1, 7)
}

source("data-raw/forms_gpkg-decl.R")

# ---- one column's meaning ---------------------------------------------------

type_map <- c(text = "string", integer = "integer", real = "double",
              datetime = "datetime", boolean = "logical")
decl_map <- c(TEXT = "string", INTEGER = "integer", MEDIUMINT = "integer",
              REAL = "double", DATETIME = "datetime", BOOLEAN = "logical",
              DATE = "string")
# A declared length (`TEXT(300)`) does not change the type; the fingerprint
# keeps the declaration as written.
type_of <- function(decl) {
  out <- unname(decl_map[sub("[(].*$", "", decl)])
  if (anyNA(out)) stop("no mapping for declared type ", decl[is.na(out)][1], call. = FALSE)
  out
}

split_options <- function(x) {
  parts <- trimws(strsplit(x, "|", fixed = TRUE)[[1]])
  parts[nzchar(parts) & parts != "<NULL>"]
}

vocab <- function(parts) {
  lapply(parts, function(p) {
    if (grepl("=", p, fixed = TRUE)) {
      at <- regexpr("=[^=]*$", p)
      # Trimmed both sides, as rfp's builder reads them.
      label <- trimws(substr(p, 1, at - 1))
      value <- trimws(substr(p, at + 1, nchar(p)))
      if (!identical(label, value)) return(list(value = value, label = label))
      return(value)
    }
    p
  })
}

values_numeric <- function(v) {
  stored <- vapply(v, function(e) if (is.list(e)) e$value else e, character(1))
  length(stored) > 0 && !anyNA(suppressWarnings(as.numeric(stored)))
}

units_of <- function(field, label) {
  m <- regmatches(label, regexpr("\\(([^()]*)\\)\\s*$", label))
  if (length(m)) {
    tok <- trimws(gsub("^\\(|\\)\\s*$", "", m))
    if (tok %in% unit_tokens) return(if (tok == "epoch s") "s" else tok)
  }
  for (pat in names(unit_suffix)) {
    if (grepl(pat, field)) return(unname(unit_suffix[[pat]]))
  }
  NULL
}

clean <- function(x) {
  x <- trimws(gsub("[[:space:]]+", " ", x))
  if (length(x) && nzchar(x)) x else NULL
}

col_from_csv <- function(r) {
  type <- unname(type_map[[r$type]])
  out <- list(name = r$field, type = type, required = FALSE)
  if (r$widget == "valuemap") {
    v <- vocab(split_options(r$options))
    if (length(v)) {
      if (!values_numeric(v)) out$type <- "string"
      out$values <- v
    }
  } else if (r$widget == "checkbox") {
    v <- split_options(r$options)
    if (length(v)) out$values <- as.list(v)
  } else if (r$widget == "range" && nzchar(r$options)) {
    b <- as.numeric(strsplit(r$options, "|", fixed = TRUE)[[1]][1:2])
    if (!anyNA(b) && !unset_range(b)) out$range <- b
  } else if (r$widget == "photo") {
    out$relative_to <- "project root"
  }
  out["units"] <- list(units_of(r$field, r$label))
  if (!nzchar(r$group)) out$null <- null_offform
  notes <- clean(r$help)
  if (is.null(notes)) notes <- clean(r$label)
  if (r$widget == "photo") {
    if (!is.null(notes) && !grepl("[.?!]$", notes)) notes <- paste0(notes, ".")
    notes <- paste(c(notes, photo_note[["rfp"]]), collapse = " ")
  }
  out["notes"] <- list(notes)
  out[!vapply(out, is.null, logical(1))]
}

cols_from_csv <- function(path) {
  x <- utils::read.csv(path, colClasses = "character", na.strings = character())
  for (c in c("group", "options", "help", "label")) if (is.null(x[[c]])) x[[c]] <- ""
  lapply(seq_len(nrow(x)), function(i) col_from_csv(x[i, ]))
}

cols_from_qml <- function(path, decl) {
  q <- xml2::read_xml(path)
  placed <- xml2::xml_attr(xml2::xml_find_all(q, "//attributeEditorField"), "name")
  fields <- xml2::xml_find_all(q, "//fieldConfiguration/field")
  # The QML also configures `fid`, which is not a capture column.
  fields <- fields[xml2::xml_attr(fields, "name") %in% names(decl)]
  opt <- function(node, name) {
    xml2::xml_attr(xml2::xml_find_first(node, sprintf(".//Option[@name='%s']", name)), "value")
  }
  lapply(fields, function(f) {
    name <- xml2::xml_attr(f, "name")
    widget <- xml2::xml_attr(xml2::xml_find_first(f, "editWidget"), "type")
    out <- list(name = name, type = type_of(decl[[name]]), required = FALSE)
    if (widget == "ValueMap") {
      # QGIS nests each choice, as name (label) and value (code), under a list
      # Option named `map`; the wrapper has a name and no value, so take only
      # options that carry both.
      o <- xml2::xml_find_all(f, ".//Option[@name='map']//Option[@name and @value]")
      # QGIS's empty-choice placeholder, as the CSV branch drops it. What marks
      # it is its value, a fixed GUID; its label is editable text that only
      # defaults to <NULL>. Kept, it would make a coded vocabulary read as text.
      o <- o[xml2::xml_attr(o, "value") != "{2839923C-8B7D-419E-B84B-CA2FE9B80EC7}"]
      v <- lapply(seq_along(o), function(i) {
        label <- xml2::xml_attr(o[i], "name")
        value <- xml2::xml_attr(o[i], "value")
        if (identical(label, value)) value else list(value = value, label = label)
      })
      if (length(v)) {
        if (!values_numeric(v)) out$type <- "string"
        out$values <- v
      }
    } else if (widget == "CheckBox") {
      v <- c(opt(f, "CheckedState"), opt(f, "UncheckedState"))
      v <- v[!is.na(v) & nzchar(v)]
      if (length(v)) out$values <- as.list(v)
    } else if (widget == "Range") {
      b <- as.numeric(c(opt(f, "Min"), opt(f, "Max")))
      if (!anyNA(b) && !unset_range(b)) out$range <- b
    } else if (widget == "ExternalResource") {
      out$relative_to <- "project root"
      out$notes <- photo_note[["qml"]]
    }
    out["units"] <- list(units_of(name, ""))
    if (!name %in% placed) out$null <- null_offform
    out[!vapply(out, is.null, logical(1))]
  })
}

# ---- the schema around them -------------------------------------------------

envelope <- yaml::read_yaml("inst/extdata/schemas/nge/form_capture.yaml")$canonical$cols
position <- list(
  list(name = "x", type = "double", required = TRUE,
       notes = "Easting of the record's point, in `source_epsg`. NA for a record with no fix."),
  list(name = "y", type = "double", required = TRUE,
       notes = "Northing of the record's point, in `source_epsg`. NA for a record with no fix."),
  list(name = "source_epsg", type = "integer", required = TRUE,
       notes = "EPSG code of the capture's coordinate reference system.")
)

describe <- function(form, n_build) {
  paste0(
    "What each column of the `form_", form, "` field form means. One row per ",
    "record: the `nge/form_capture` envelope, the record's position, then the ",
    "form's own ", n_build, " columns as rfp builds it.\n\n",
    "Derived by `data-raw/forms_derive-schemas.R` from the field definitions ",
    "rfp builds the form from, so the meaning is taken from where it is written ",
    "rather than restated. How the form shows a column is rfp's, not this ",
    "schema's.\n\n",
    "Every form column is optional, so a record from an earlier vintage that ",
    "lacks one still conforms. A null then means one of two things, and ",
    "`schema_version` says which: the observer left it blank, or the form did ",
    "not have that column yet. `crt_schema_variant()` names the version a ",
    "record's `schema_version` belongs to. Whether a record can answer a given ",
    "question is a grade (`crt_schema_grade()`), not a property of the schema.\n\n",
    "Allowed values (`values`) and ranges are what a QC rule flags against; ",
    "`crt_schema_conform()` does not refuse a value outside them.",
    if (!is.null(form_status[[form]])) paste0("\n\n", form_status[[form]])
  )
}

write_schema <- function(form) {
  csv <- form != "monitoring"
  gpkg_path <- sprintf("inst/extdata/forms/form_%s.gpkg", form)
  gpkg <- rfp_fetch(gpkg_path)
  decl <- gpkg_decl(gpkg, paste0("form_", form))

  if (csv) {
    src <- sprintf("inst/extdata/forms/schema/%s.csv", form)
    cols <- cols_from_csv(rfp_fetch(src))
  } else {
    src <- sprintf("inst/extdata/forms/form_%s.qml", form)
    cols <- cols_from_qml(rfp_fetch(src), decl)
  }
  names_form <- vapply(cols, function(col) col$name, character(1))
  if (!setequal(names_form, names(decl))) {
    stop("form_", form, ": ", basename(src), " and the GeoPackage disagree on columns: ",
         paste(c(setdiff(names_form, names(decl)), setdiff(names(decl), names_form)),
               collapse = ", "), call. = FALSE)
  }
  # GeoPackage column order, which is the order the form's file stores.
  cols <- cols[match(names(decl), names_form)]
  clash <- intersect(names(decl), c(vapply(envelope, `[[`, "", "name"), "x", "y", "source_epsg"))
  if (length(clash)) stop("form_", form, " has a column named like the envelope: ", clash)

  month <- rfp_month(gpkg_path)
  build_id <- paste0("rfp-build-", month)
  fixture <- sprintf("tests/testthat/fixtures/forms/form_%s__%s.csv", form, build_id)
  utils::write.csv(data.frame(name = names(decl), type = unname(decl)), fixture,
                   row.names = FALSE, quote = FALSE)

  # Measured versions after the build, oldest first.
  rows <- measured[measured$form == paste0("form_", form), ]
  rows <- rows[order(rows$first_seen, rows$id, method = "radix"), ]
  variants <- c(
    list(list(
      id = build_id,
      description = paste0(
        "The form as rfp builds it (", length(decl), " columns; the GeoPackage at ",
        "rfp@", substr(rfp_sha, 1, 7), ", last changed ", month, "). Every ",
        "2026 capture of this form measured in the four fish passage projects ",
        "on 2026-10-30 carried this column set",
        if (form == "monitoring") ", except `capture-utm-columns-2025`" else "",
        "."
      ),
      fingerprint = crt_schema_fingerprint(decl),
      normalize_fn = "reader-supplied",
      first_seen = month
    )),
    lapply(seq_len(nrow(rows)), function(i) measured_variant(form, rows[i, ], decl))
  )
  conflicts <- shared_conflicts(form, rows, cols)
  if (length(conflicts)) {
    stop("form_", form, ": decide these in `shared_type`: ", paste(conflicts, collapse = "; "),
         call. = FALSE)
  }
  for (nm in names(shared_type[[form]])) {
    cols[[match(nm, names(decl))]]$type <- shared_type[[form]][[nm]]
  }
  later <- earlier_cols(form, rows, names(decl))
  clash <- intersect(vapply(later, `[[`, "", "name"),
                     c(vapply(envelope, `[[`, "", "name"), "x", "y", "source_epsg"))
  if (length(clash)) {
    stop("form_", form, ": an earlier version has a column named like the envelope: ", clash)
  }

  schema <- list(
    file = paste0("form_", form),
    description = describe(form, length(decl)),
    canonical = list(
      shape = "long",
      cols = c(envelope, position, cols, later)
    ),
    grades = c(
      list(list(name = "harvestable",
                requires = list("project", "form", "record_id", "x", "y"))),
      grades_extra[[form]]
    ),
    upstream_variants = variants,
    decisions = list("decisions/nge/20261030_form_schemas_fish_passage.md")
  )

  out <- sprintf("inst/extdata/schemas/nge/form_%s.yaml", form)
  header <- c(
    "# Generated by data-raw/forms_derive-schemas.R from",
    sprintf("# the form builder's field definitions at commit %s, and the versions measured in", substr(rfp_sha, 1, 7)),
    "# data-raw/forms_variants-measured.csv. Edit the script or its rules, not this file,",
    "# until the form builder reads meaning from crate; then this file is the source."
  )
  # true/false rather than yaml's default yes/no: a YAML 1.2 reader takes `yes`
  # for a string, and these schemas are published.
  body <- yaml::as.yaml(
    schema, indent.mapping.sequence = TRUE, line.sep = "\n",
    # Fixed, not getOption("digits"): a session's digits option would
    # otherwise decide how a range bound is written (9999999 as 1.0e+07).
    precision = 15,
    handlers = list(logical = function(x) {
      structure(ifelse(x, "true", "false"), class = "verbatim")
    })
  )
  con <- file(out, open = "wb")
  writeLines(header, con, sep = "\n")
  writeChar(enc2utf8(body), con, eos = NULL)
  close(con)
  message("wrote ", out, " (", length(decl), " form columns, ", schema$upstream_variants[[1]]$fingerprint, ")")
  invisible(out)
}

invisible(lapply(forms, write_schema))
