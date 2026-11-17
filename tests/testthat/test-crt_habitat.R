# The nge/habitat/fwa/v1/segment dataset link publishes (link#333).
#
# The registry-integrity guards already walk every schema; this file covers what
# is specific to it: the types a part is written with, that the Hive keys in the
# path are not columns, and that `access`, added to v1 after its first publish
# (link#423), is optional so a part written before it still conforms.

segment <- function() {
  data.frame(
    blue_line_key = c(359572348, 359572348),
    downstream_route_measure = c(0, 152.4),
    upstream_route_measure = c(152.4, 310),
    linear_feature_id = c(701234, 701235),
    watershed_group_code = c("PARS", "PARS"),
    stream_order = c(5, 5),
    edge_type = c(1000, 1000),
    length_metre = c(152.4, 157.6),
    gradient = c(0.01, 0.02),
    channel_width = c(8.2, NA),
    channel_width_source = c("FIELD", NA),
    mad_m3s = c(3.1, NA),
    mad_m3s_source = c("fwapg", NA),
    accessible = c(TRUE, FALSE),
    spawning = c(TRUE, FALSE),
    rearing = c(TRUE, FALSE),
    lake_rearing = c(FALSE, FALSE),
    wetland_rearing = c(FALSE, FALSE),
    has_barriers_dnstr = c(FALSE, TRUE),
    access = c(2, 0),
    accessible_ratio_gradient = c(0.05, 0.1),
    spawning_ratio_cw = c(4.1, NA),
    spawning_ratio_mad = c(NA, NA),
    spawning_ratio_gradient = c(0.5, 1),
    rearing_ratio_cw = c(5.5, NA),
    rearing_ratio_mad = c(NA, NA),
    rearing_ratio_gradient = c(0.1, 0.2),
    stringsAsFactors = FALSE
  )
}

test_that("a habitat segment part conforms to its declared types", {
  out <- crt_schema_conform(segment(), "nge", "habitat/fwa/v1/segment")
  expect_type(out$blue_line_key, "integer")
  expect_type(out$downstream_route_measure, "double")
  expect_type(out$watershed_group_code, "character")
  expect_type(out$rearing, "logical")
  expect_type(out$access, "integer")
  expect_identical(out$access, c(2L, 0L))
})

test_that("a part written before access was added still conforms", {
  x <- segment()
  x$access <- NULL
  expect_no_error(crt_schema_conform(x, "nge", "habitat/fwa/v1/segment"))
})

test_that("a part missing a habitat flag is refused", {
  x <- segment()
  x$rearing <- NULL
  expect_error(crt_schema_conform(x, "nge", "habitat/fwa/v1/segment"), "rearing")
})

test_that("the Hive keys are not declared as columns", {
  cols <- crt_schema_read("schemas/nge/habitat/fwa/v1/segment.yaml")$canonical$cols
  nm <- vapply(cols, function(c) c$name, character(1))
  expect_false(any(c("config", "species") %in% nm))
})
