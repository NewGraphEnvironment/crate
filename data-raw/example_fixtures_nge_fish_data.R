# data-raw/example_fixtures_nge_fish_data.R
#
# Documents the example fixture CSVs at:
#   inst/extdata/examples/nge/fish_data_2023_peace.csv   (variant 2023-peace-6col)
#   inst/extdata/examples/nge/fish_data_2023_skeena.csv  (variant 2023-skeena-7col)
#   inst/extdata/examples/nge/fish_data_2024.csv         (variant 2024-field-sheet)
#
# Hand-authored and synthetic: site names, project and tag codes are made up,
# with the column sets copied exactly from the real files the variants name
# (schemas/nge/fish_data.yaml). They cover:
#   - a PIT tag written into a 2023 comment, alone and followed by more text
#   - a malformed 2023 tag (3DD.003E19000I), which must read as NA
#   - a blank comment, and a 2023 weight column with every value missing
#     (readr reads it as logical)
#   - a visual observation with no weight, and an empty pass recorded as NFC
#   - one recapture: 3DD.003E190001 is in a 2023 peace comment and in the 2024
#     pit_tag_id column. It is planted for the test of the recapture query; no
#     real 2023 tag recurs in a later season (data-raw/fish_data_check-real.R).
#
# To regenerate: no script, edit the CSVs. Keep each file's header identical to
# its variant's `cols`, and update tests/testthat/test-crt_ingest.R and
# test-crt_handler_nge_fish_data.R if the cases change.

dir <- "inst/extdata/examples/nge"
schema <- yaml::read_yaml("inst/extdata/schemas/nge/fish_data.yaml")
files <- c(
  "2023-peace-6col" = "fish_data_2023_peace.csv",
  "2023-skeena-7col" = "fish_data_2023_skeena.csv",
  "2024-field-sheet" = "fish_data_2024.csv"
)
for (v in schema$upstream_variants) {
  path <- file.path(dir, files[[v$id]])
  stopifnot(file.exists(path))
  header <- names(readr::read_csv(path, n_max = 0, show_col_types = FALSE))
  stopifnot(identical(header, unlist(v$cols)))
  message(sprintf("%s: %d rows", basename(path), nrow(read.csv(path))))
}
