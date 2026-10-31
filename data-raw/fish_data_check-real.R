# data-raw/fish_data_check-real.R
#
# Reads every real fish data file nge/fish_data has a variant for, through
# crt_ingest(), and checks the result against the counts measured for #6.
# Not run in CI: it fetches from GitHub. Run from the package root:
#   Rscript data-raw/fish_data_check-real.R
#
# The files sit in the public fish passage reporting repos, pinned to the
# commit each was last changed in. The 2024 file is byte-identical in the Peace
# and Skeena 2024 repos; one copy is read.

pkgload::load_all(quiet = TRUE)

raw_url <- function(repo, sha, path) {
  paste("https://raw.githubusercontent.com/NewGraphEnvironment", repo, sha, path, sep = "/")
}
files <- tibble::tribble(
  ~season, ~repo, ~sha, ~path, ~rows,
  "2023", "fish_passage_peace_2023_reporting", "92d50f7f7254268826fe41357040e0f274e217a2",
  "data/inputs_raw/fish_data.csv", 171L,
  "2023", "fish_passage_skeena_2023_reporting", "de684436fc6185bbb696d33c2347dc328358e9f8",
  "data/inputs_raw/fish_data.csv", 417L,
  "2024", "fish_passage_skeena_2024_reporting", "f990ad20f4e9e1674a124ae76b1264ca14b982bf",
  "data/fish_data_tags_joined.csv", 674L,
  "2025", "fish_passage_peace_2025_reporting", "e1ab377460b085e126add7d347dc28644a70a299",
  "data/fish_data_tags_joined_2025.csv", 97L
)

read_one <- function(i) {
  dest <- tempfile(fileext = ".csv")
  res <- curl::curl_fetch_disk(raw_url(files$repo[[i]], files$sha[[i]], files$path[[i]]), dest)
  if (res$status_code != 200L) stop(files$repo[[i]], ": HTTP ", res$status_code)
  out <- crt_ingest("nge", "fish_data", dest)
  stopifnot(nrow(out) == files$rows[[i]])
  out$season <- files$season[[i]]
  out
}
seasons <- lapply(seq_len(nrow(files)), read_one)

# One column set and one set of types for every file.
classes <- lapply(seasons, function(x) vapply(x, function(col) class(col)[[1]], character(1)))
stopifnot(all(vapply(classes, identical, logical(1), classes[[1]])))
fish <- dplyr::bind_rows(seasons)
stopifnot(nrow(fish) == 1359L)

# Every time of day is HH:MM:SS: a column readr could not read as a time would
# pass through as text in whatever form it was typed.
time_cols <- c("site_start_time", "site_end_time", "segment_start_time",
               "segment_end_time", "photo_time_start", "photo_time_end")
for (col in time_cols) {
  v <- fish[[col]]
  stopifnot(all(is.na(v) | grepl("^[0-9]{2}:[0-9]{2}:[0-9]{2}$", v)))
}

# PIT tags by season.
tagged <- dplyr::filter(fish, !is.na(pit_tag_id))
per_season <- dplyr::summarise(
  tagged,
  rows = dplyr::n(), tags = dplyr::n_distinct(pit_tag_id),
  .by = season
)
print(per_season)
stopifnot(
  identical(per_season$rows[per_season$season == "2023"], 228L),
  identical(per_season$tags[per_season$season == "2023"], 211L)
)

# Recaptures: a tag seen in more than one season.
recaptures <- tagged |>
  dplyr::filter(dplyr::n_distinct(season) > 1L, .by = pit_tag_id) |>
  dplyr::arrange(pit_tag_id, season) |>
  dplyr::select(pit_tag_id, season, local_name, length_mm, weight_g)
print(recaptures, n = Inf)
stopifnot(
  setequal(
    unique(recaptures$pit_tag_id),
    c("3DD.003E192A2C", "3DD.003E192AD3", "3DD.003E192A33", "3DD.003E192ACB")
  ),
  !"2023" %in% recaptures$season
)

# Species names: the same vocabulary in both shapes, or a split by species
# silently separates the seasons.
sp <- split(fish$species, fish$season == "2023")
message("Species only in 2023: ", paste(setdiff(sp[["TRUE"]], sp[["FALSE"]]), collapse = "; "))
message("Species only in 2024-25: ", paste(setdiff(sp[["FALSE"]], sp[["TRUE"]]), collapse = "; "))

# 2023 comments that mention a tag the extraction could not read in full.
partial <- fish$comments[fish$season == "2023" & is.na(fish$pit_tag_id) &
                           grepl("3DD", fish$comments, ignore.case = TRUE)]
message("2023 comments naming a partial tag: ", paste(partial, collapse = " | "))
