# Package setup tracking
# Run these interactively — they are NOT idempotent

# 1. Package scaffold
usethis::create_package(".")
usethis::use_mit_license("Allan Irvine")

# 2. Testing
usethis::use_testthat(edition = 3)

# 3. Documentation site
usethis::use_pkgdown()
usethis::use_github_action("pkgdown")

# 4. Dev directory (self-referential) + content directories
usethis::use_directory("dev")
usethis::use_directory("data-raw")

# 5. Hex sticker (reads package name from DESCRIPTION — zero edits needed)
source("data-raw/make_hexsticker.R")

# 6. Dependencies — Imports
usethis::use_package("chk")
usethis::use_package("cli")
usethis::use_package("dplyr")
usethis::use_package("fs")
usethis::use_package("readr")
usethis::use_package("tibble")
usethis::use_package("tidyr")
usethis::use_package("yaml")

# 7. Dependencies — Suggests
usethis::use_package("testthat", type = "Suggests", min_version = "3.0.0")
usethis::use_package("knitr", type = "Suggests")
usethis::use_package("rmarkdown", type = "Suggests")
usethis::use_package("lintr", type = "Suggests")
usethis::use_package("hexSticker", type = "Suggests")

# 8. Build
devtools::document()
devtools::test()
devtools::check()
