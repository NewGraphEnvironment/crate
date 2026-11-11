"""Mutate each guard of crt_receipt_stac() in a worktree and count red expectations."""
import pathlib
import subprocess
import sys

wt = pathlib.Path(sys.argv[1])
src = wt / "R" / "crt_receipt_stac.R"
gen = wt / "data-raw" / "receipt_vectors.R"
stac = wt / "inst/extdata/receipt/mapping/v1.1.0/stac.json"
orig_src, orig_gen = src.read_text(), gen.read_text()

R_MUTANTS = {
    "receipt not an object allowed": ('  if (!stac_is_object(receipt)) {\n    stac_refuse("block_not_object"', '  if (FALSE) {\n    stac_refuse("block_not_object"'),
    "null block read as absent": ('  if (!name %in% names(x)) return(list())', '  if (is.null(x[[name]])) return(list())'),
    "non-object block allowed": ('  if (!stac_is_object(v)) stac_refuse', '  if (FALSE) stac_refuse'),
    "form version unchecked": ('  if (!(is.character(v) && length(v) == 1L && !is.na(v) && v == receipt_version())) {', '  if (FALSE) {'),
    "missing recipe_id allowed": ('    if (!migrated) {', '    if (FALSE) {'),
    "id on migrated allowed": ('    if (migrated) {', '    if (FALSE) {'),
    "recipe_id pattern unchecked": ('props[["receipt:recipe_id"]] <- stac_sha256(id, "recipe.recipe_id", "recipe_id_not_sha256")', 'props[["receipt:recipe_id"]] <- id'),
    "time unchecked": ('  if (!stac_utc(time)) {', '  if (FALSE) {'),
    "time range unchecked": ('  n[2] >= 1 && n[2] <= 12', '  TRUE || n[2] >= 1 && n[2] <= 12'),
    "time pattern with $ only (newline passes)": ('  if (!(is.character(x) && length(x) == 1L && !is.na(x) && grepl(utc, x))) return(FALSE)', '  if (!(is.character(x) && length(x) == 1L && !is.na(x) && grepl(utc, sub("\\n$", "", x)))) return(FALSE)'),
    "empty repo name allowed": ('    if (!nzchar(repo)) stac_refuse', '    if (FALSE) stac_refuse'),
    "version unchecked": ('    if (!(is.character(v) && length(v) == 1L && nzchar(v))) {\n      stac_refuse("version_not_string"', '    if (FALSE) {\n      stac_refuse("version_not_string"'),
    "unmatched asset skipped": ('    if (!href %in% names(parts)) {', '    if (!href %in% names(parts)) next\n    if (FALSE) {'),
    "sha256 unchecked": ('  if (!(is.character(x) && length(x) == 1L && !is.na(x) && grepl("^[0-9a-f]{64}$", x))) {', '  if (FALSE) {'),
    "bytes may be negative": ('is.finite(x) && x >= 0 && x == round(x)', 'is.finite(x) && x == round(x)'),
    "receipt_asset type unchecked": ('    if (!(is.character(receipt_asset) && length(receipt_asset) == 1L && !is.na(receipt_asset))) {', '    if (FALSE) {'),
    "empty receipt_asset allowed": ('    if (!nzchar(receipt_asset)) stac_refuse', '    if (FALSE) stac_refuse'),
    "receipt_asset may shadow an asset": ('    if (receipt_asset %in% names(assets)) {', '    if (FALSE) {'),
    "digest without asset ignored": ('  } else if (!is.null(receipt_sha256)) {', '  } else if (FALSE) {'),
    "receipt asset without digest allowed": ('    if (is.null(receipt_sha256)) {', '    if (FALSE) {'),
}


def run_test():
    out = subprocess.run(
        ["Rscript", "-e",
         'pkgload::load_all(quiet=TRUE); r <- as.data.frame(testthat::test_file("tests/testthat/test-crt_receipt_vectors.R", reporter="silent")); cat("RED", sum(r$failed) + sum(r$error), "\\n")'],
        cwd=wt, capture_output=True, text=True, env={**__import__("os").environ, "NOT_CRAN": "true"})
    for line in out.stdout.splitlines():
        if line.startswith("RED"):
            return line.split()[1]
    return "NO RESULT: " + (out.stderr.strip().splitlines() or ["?"])[-1]


for name, (a, b) in R_MUTANTS.items():
    if orig_src.count(a) != 1:
        print(f"{name}: PATTERN NOT FOUND ({orig_src.count(a)})")
        continue
    src.write_text(orig_src.replace(a, b, 1))
    print(f"{name}: {run_test()} red", flush=True)
src.write_text(orig_src)

# A path dropped from the generator: the coverage test, which derives paths from mapping.csv,
# must go red once the vectors are regenerated without it
a = '  list(c("result", "parts", "walks.csv", "bytes"), "bytes", walks),\n'
assert orig_gen.count(a) == 1
gen.write_text(orig_gen.replace(a, ""))
stac.unlink()
subprocess.run(["Rscript", "data-raw/receipt_vectors.R"], cwd=wt, capture_output=True)
print(f"generator drops result.parts[walks.csv].bytes: {run_test()} red")
