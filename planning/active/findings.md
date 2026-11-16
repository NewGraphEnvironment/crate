# Findings — List the 2023–2025 versions of the fish passage forms, read from the sync service's history (#36)

## Issue context

## Problem

#13 registered the fish passage form schemas with the versions deployed today: rfp's builds, and one 2025 `form_monitoring` shape still in the field. A record captured with an earlier build of these forms (2023–2025) has a fingerprint none of them lists, so `crt_schema_conform()` reports it as `crate_unknown_fingerprint` and `crt_schema_variant()` returns `NA`.

Local copies of those seasons show about 15 more `form_pscis` and 10 more `form_fiss_site` fingerprints, but many of those files are processed copies — a `_raw` file and its processed twin give different column sets — so a local file's fingerprint is not evidence of a form build.

## Proposed

Read each form's version history from the sync service rather than from local copies: for every version of `form_<name>.gpkg` in each fish passage project, the GeoPackage's declared column types, then `crt_schema_fingerprint()`. Each distinct column set becomes an `upstream_variant` with its fingerprint and a fixture under `tests/testthat/fixtures/forms/`, as the existing variants have. Name variants by when they first appear, not by project.

## Acceptance

- Every column set a fish passage form was captured with since 2023 is listed, each with a fixture that recomputes its fingerprint.
- A variant that renames rather than nests (as `form_monitoring`'s 2025 shape does) says so in its description.

Follows #13.


## Errors Encountered

| Error | Resolution |
|-------|------------|
