# data-raw/receipt_examples.R
#
# Writes the worked case to inst/extdata/receipt/examples/worked_case/ (#43): one
# output built twice from the same recipe, with a receipt beside each build.
#
# It mirrors knowledge#145 (2026-11-04), where a link build's evidence was rebuilt and
# three tables came out byte-identical while the fourth differed by up to 9.5e-11 km,
# because Postgres summed in another order. The tables here are synthetic, shaped like
# that evidence; the vignette, the examples and the comparison tests run on them.
#
#   worked_case/
#     settings.csv             the config file both builds hash
#     build_1/                 the reference build
#       access_check.csv  visits_link.csv  visits_species.csv  walks.csv
#       receipt.json
#     build_2/                 the rebuild: access_check's km moved in the 11th decimal
#
# Times and toolchain are fixed so the files do not change on every run.
#
# Run from the package root: Rscript data-raw/receipt_examples.R

devtools::load_all(quiet = TRUE)

root <- file.path("inst", "extdata", "receipt", "examples", "worked_case")
dir.create(root, recursive = TRUE, showWarnings = FALSE)
keys <- crt_receipt_keys(file.path("inst", "extdata", "receipt", "examples", "receipt_keys.yaml"))

settings_csv <- file.path(root, "settings.csv")
writeLines(c("setting,value", "species,CO;CH;ST", "watershed_group,BULK", "min_gradient,0.02"),
           settings_csv)

visits_link <- data.frame(link_id = c("L001", "L002", "L003", "L004"),
                          visits = c(14L, 3L, 0L, 22L))
visits_species <- data.frame(link_id = c("L001", "L001", "L002", "L004", "L004"),
                             species = c("CO", "ST", "CO", "CH", "CO"),
                             visits = c(9L, 5L, 3L, 7L, 15L))
walks <- data.frame(walk_id = c("W01", "W02", "W03"), segments = c(12L, 4L, 9L))
access_1 <- data.frame(
  segment = c("S010", "S011", "S012", "S013"),
  accessible = c(TRUE, TRUE, FALSE, TRUE),
  km = c(12.3456789012, 3.1400000004, 0.875, 31.0161003581)
)
# The rebuild: the same rows and counts, with km summed in another order.
access_2 <- access_1
access_2$km <- access_2$km + c(9.5e-11, -3e-11, 0, 4e-11)

write_build <- function(name, access, time, run_id) {
  dir <- file.path(root, name)
  dir.create(dir, showWarnings = FALSE)
  tables <- list(access_check = access, visits_link = visits_link,
                 visits_species = visits_species, walks = walks)
  for (nm in names(tables)) {
    utils::write.csv(tables[[nm]], file.path(dir, paste0(nm, ".csv")), row.names = FALSE)
  }
  crt_receipt_write(
    dir,
    output = list(name = "link_evidence", scope = "BULK"),
    recipe = list(
      code = list(
        knowledge = list(commit = "3f1c2a9e8b7d6c5f4e3d2c1b0a9f8e7d6c5b4a39", version = "0.14.0",
                         dirty = FALSE),
        link = list(commit = "a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1b0", version = "0.31.2",
                    dirty = FALSE)
      ),
      config = list(files = c("settings.csv" = settings_csv),
                    settings = list(species = c("CO", "CH", "ST"), watershed_group = "BULK")),
      inputs = list(
        flow = list(recipe_id = "0d6f1c9a8e7b5d4c3a2f1e0d9c8b7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e2d1c0b"),
        fwa_stream_networks = list(version_id = "3HL4kqtJlcpXroDTDmJ.rmSpXd3dIbrHY")
      )
    ),
    result = list(
      tables = tables,
      parts = stats::setNames(paste0(names(tables), ".csv"), names(tables)),
      summary = list(rows = nrow(access), km_total = sum(access$km))
    ),
    context = list(time = time, run = list(link_run_id = run_id),
                   toolchain = list(R = "4.5.2")),
    keys = keys,
    lockfile = NULL,
    publish = TRUE
  )
}

write_build("build_1", access_1, "2026-11-04T18:22:05Z", "20261104T181900Z-bulk")
write_build("build_2", access_2, "2026-11-04T21:47:31Z", "20261104T214400Z-bulk")
r1 <- crt_receipt_read(file.path(root, "build_1"))
r2 <- crt_receipt_read(file.path(root, "build_2"))
message("recipe_id: ", r1$recipe$recipe_id, if (identical(r1$recipe$recipe_id, r2$recipe$recipe_id)) " (both builds)")
