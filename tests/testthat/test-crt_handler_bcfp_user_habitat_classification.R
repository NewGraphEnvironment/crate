# Direct tests for crt_handler_bcfp_user_habitat_classification and its
# file-local helpers (crt_handler_bcfp_uhc_identity,
# crt_handler_bcfp_uhc_pivot_long_to_wide).
#
# These functions are normally called via the registry-driven dispatcher
# in crt_ingest(). Direct tests give us coverage of edge cases (variant_id
# branching, required-col validation in each helper) that end-to-end tests
# through crt_ingest don't easily exercise.

read_wide_fixture <- function() {
  readr::read_csv(
    system.file(
      "extdata/examples/bcfp/user_habitat_classification_wide.csv",
      package = "crate"
    ),
    show_col_types = FALSE
  )
}

read_long_fixture <- function() {
  readr::read_csv(
    system.file(
      "extdata/examples/bcfp/user_habitat_classification_long.csv",
      package = "crate"
    ),
    show_col_types = FALSE
  )
}

test_that("dispatcher returns canonical-shape tibble for wide variant_id", {
  raw <- read_wide_fixture()
  out <- crt_handler_bcfp_user_habitat_classification(raw, "2026-04-26-wide")
  expect_s3_class(out, "tbl_df")
  expect_true(all(c("blue_line_key", "spawning", "rearing") %in% names(out)))
  expect_equal(nrow(out), 6L)
})

test_that("dispatcher returns canonical-shape tibble for long variant_id", {
  raw <- read_long_fixture()
  out <- crt_handler_bcfp_user_habitat_classification(raw, "pre-2026-04-26-long")
  expect_s3_class(out, "tbl_df")
  expect_true(all(c("blue_line_key", "spawning", "rearing") %in% names(out)))
  # Long fixture has 7 rows covering 5 unique (segment x species) tuples
  expect_equal(nrow(out), 5L)
})

test_that("dispatcher throws on unknown variant_id", {
  raw <- read_wide_fixture()
  expect_error(
    crt_handler_bcfp_user_habitat_classification(raw, "bogus_variant"),
    "Unknown variant_id"
  )
})

test_that("crt_handler_bcfp_uhc_identity validates required cols (wide variant)", {
  bad <- data.frame(blue_line_key = 1L, watershed_group_code = "ELKR")  # missing many required
  expect_error(
    crt_handler_bcfp_uhc_identity(bad),
    "Wide-variant input missing required cols"
  )
})

test_that("crt_handler_bcfp_uhc_pivot_long_to_wide validates required cols (long variant)", {
  bad <- data.frame(blue_line_key = 1L, habitat_type = "spawning")  # missing many required
  expect_error(
    crt_handler_bcfp_uhc_pivot_long_to_wide(bad),
    "Long-variant input missing required cols"
  )
})

test_that("crt_handler_bcfp_uhc_identity preserves -4 excluded value (wide passthrough)", {
  raw <- read_wide_fixture()
  out <- crt_handler_bcfp_uhc_identity(raw)
  excluded <- out[out$blue_line_key == 356600333, ]
  expect_equal(nrow(excluded), 1L)
  expect_equal(excluded$spawning, -4)
  expect_equal(excluded$rearing, -4)
})

test_that("crt_handler_bcfp_uhc_pivot_long_to_wide produces both spawning + rearing cols", {
  raw <- read_long_fixture()
  out <- crt_handler_bcfp_uhc_pivot_long_to_wide(raw)
  expect_true("spawning" %in% names(out))
  expect_true("rearing" %in% names(out))
})

test_that("crt_handler_bcfp_uhc_identity returns cols in canonical order", {
  raw <- read_wide_fixture()
  out <- crt_handler_bcfp_uhc_identity(raw)
  required_in_order <- c(
    "blue_line_key", "downstream_route_measure", "upstream_route_measure",
    "watershed_group_code", "species_code", "spawning", "rearing"
  )
  expect_equal(names(out)[seq_along(required_in_order)], required_in_order)
})
