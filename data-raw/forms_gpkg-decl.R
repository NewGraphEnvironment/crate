# data-raw/forms_gpkg-decl.R
#
# How a form GeoPackage's capture columns are read, shared by
# forms_derive-schemas.R (rfp's builds) and forms_read-history.R (every version
# the sync service holds), so a fingerprint means the same thing in both.
# Sourced, not run. Needs RSQLite, which crate itself does not import.

# The tables a GeoPackage registers as data, in registration order.
gpkg_tables <- function(path) {
  con <- DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con))
  DBI::dbGetQuery(
    con,
    "SELECT table_name FROM gpkg_contents
     WHERE data_type IN ('features', 'attributes') ORDER BY rowid"
  )$table_name
}

# Declared type of each capture column, upper-cased, in the order the table
# stores them. The surrogate row id is the primary key, whatever it is named
# (`fid` is only GDAL's default name for it), and the geometry is the point; a
# harvest reads neither as a capture column, so neither is in the fingerprint.
gpkg_decl <- function(path, layer) {
  con <- DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con))
  geom <- DBI::dbGetQuery(
    con, "SELECT column_name FROM gpkg_geometry_columns WHERE table_name = ?",
    params = list(layer)
  )$column_name
  info <- DBI::dbGetQuery(con, sprintf('PRAGMA table_info("%s")', layer))
  keep <- info$pk == 0 & !info$name %in% geom
  up <- chartr("abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", info$type[keep])
  stats::setNames(up, info$name[keep])
}

# Records in a table.
gpkg_nrow <- function(path, layer) {
  con <- DBI::dbConnect(RSQLite::SQLite(), path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con))
  DBI::dbGetQuery(con, sprintf('SELECT count(*) AS n FROM "%s"', layer))$n
}
