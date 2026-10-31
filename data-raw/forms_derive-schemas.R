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
# It does not write the fixture of the measured 2025 monitoring variant
# (form_monitoring__capture-utm-columns-2025.csv): that column set was read off
# a live field capture, which has no public source, and is committed as
# measured. Its variant entry is in `extra_variants` below.
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

# Forms whose capture shape in the field differs from rfp's build. Listed here,
# not derived, because the evidence is a live capture (see header).
extra_variants <- list(
  monitoring = list(list(
    id = "capture-utm-columns-2025",
    description = paste(
      "A field capture first seen in 2025 and still deployed in one of the four",
      "fish passage projects in 2026 (122 columns, measured 2026-10-30). It is",
      "not a subset of the rfp build: it lacks `surveyor_1`, `surveyor_2`,",
      "`surveyor_3`, `habitat_comment`, `utm_corrected` and",
      "`assessment_comments_og`, and carries `rowid`, `utm_zone`, `easting` and",
      "`northing`, which the build does not. Two vintages of this form therefore",
      "rename rather than nest: a null in either set of columns means the form",
      "did not have it."
    ),
    first_seen = "2025"
  ))
)

# Columns the measured variant carries and the build does not. Declared so a
# record from it conforms with its own columns typed, not passed through. Types
# follow the capture's declarations (all four REAL), as every derived column's
# do.
extra_cols <- list(
  monitoring = list(
    list(name = "rowid", type = "double", required = FALSE,
         notes = "A row number carried by the 2025 capture variant only."),
    list(name = "utm_zone", type = "double", required = FALSE,
         notes = "UTM zone of `easting` and `northing`. 2025 capture variant only."),
    list(name = "easting", type = "double", required = FALSE, units = "m",
         notes = "UTM easting. 2025 capture variant only."),
    list(name = "northing", type = "double", required = FALSE, units = "m",
         notes = "UTM northing. 2025 capture variant only.")
  )
)

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

gpkg_decl <- function(path, layer) {
  con <- DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con))
  geom <- DBI::dbGetQuery(
    con, "SELECT column_name FROM gpkg_geometry_columns WHERE table_name = ?",
    params = list(layer)
  )$column_name
  info <- DBI::dbGetQuery(con, sprintf('PRAGMA table_info("%s")', layer))
  # The surrogate row id is the primary key, whatever it is named; `fid` is
  # only GDAL's default name for it.
  keep <- info$pk == 0 & !info$name %in% geom
  up <- chartr("abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", info$type[keep])
  stats::setNames(up, info$name[keep])
}

# ---- one column's meaning ---------------------------------------------------

type_map <- c(text = "string", integer = "integer", real = "double",
              datetime = "datetime", boolean = "logical")
decl_map <- c(TEXT = "string", INTEGER = "integer", MEDIUMINT = "integer",
              REAL = "double", DATETIME = "datetime", BOOLEAN = "logical",
              DATE = "string")

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
    out <- list(name = name, type = unname(decl_map[[decl[[name]]]]), required = FALSE)
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

  variants <- c(
    list(list(
      id = build_id,
      description = paste0(
        "The form as rfp builds it (", length(decl), " columns; the GeoPackage at ",
        "rfp@", substr(rfp_sha, 1, 7), ", last changed ", month, "). Every ",
        "2026 capture of this form measured in the four fish passage projects ",
        "on 2026-10-30 carried this column set",
        if (form == "monitoring") ", except the variant below" else "",
        "."
      ),
      fingerprint = crt_schema_fingerprint(decl),
      normalize_fn = "reader-supplied",
      first_seen = month
    )),
    lapply(extra_variants[[form]], function(v) {
      fx <- sprintf("tests/testthat/fixtures/forms/form_%s__%s.csv", form, v$id)
      t <- utils::read.csv(fx, colClasses = "character")
      c(v[c("id", "description")],
        list(fingerprint = crt_schema_fingerprint(stats::setNames(t$type, t$name)),
             normalize_fn = "reader-supplied",
             first_seen = v$first_seen))
    })
  )

  schema <- list(
    file = paste0("form_", form),
    description = describe(form, length(decl)),
    canonical = list(
      shape = "long",
      cols = c(envelope, position, cols, extra_cols[[form]])
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
    sprintf("# rfp's field definitions at commit %s. Edit the script or its rules, not", substr(rfp_sha, 1, 7)),
    "# this file, until rfp's form builder reads meaning from crate; then this file is the source."
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
