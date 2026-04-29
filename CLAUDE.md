# crate

## Purpose

Data governance repo for New Graph Environment — canonical schemas, data
dictionary, QC rules, cross-domain normalization for 8 years of
heterogeneous NGE data (fish passage, eDNA, benthic, restoration
monitoring, gps tracks, forms across Peace / Skeena / Fraser regions).

## Ecosystem placement

- **Consumer of** `rtj` (S3 storage, postgres instances)
- **Publisher for** reporting repos (via snapshot-parquet pattern — see
  db_newgraph#stamps umbrella)
- **Cross-references** `db_newgraph` (schema contract), `link` / `fresh`
  (custom model producers), `compass` (values), `soul` (conventions)

## Boundary with rfp (load-bearing)

**rfp = tool plumbing. crate = declarative schemas + canonical data ops
across all NGE domains.**

- rfp owns QGIS / Mergin / GPKG / GDAL / photo-file ops — gets field
  data INTO a canonical-shaped GPKG file in a staging area, then stops.
- crate owns the schemas, dictionary, QC rules, normalization, dedup,
  cross-reference, canonical PostGIS load, export contracts, lookup
  tables, and lineage. Applies to ALL domains, not just field forms (lab
  returns, benthic, historical pre-Mergin data also flow through crate).
- fpr stays as the fish-passage domain compute called by
  `crt_normalize()` / `crt_validate()` dispatch.
- Dependency direction: `rfp → crate ← fpr ← link/fresh ← reporting`. No
  cycles.
- Concretely: `rfp_form_wrangle/validate/export/db_load` (rfp \#30,
  \#33, \#34, \#35) move to `crt_normalize/validate/export/load`. rfp
  keeps `_source_*`, `_mergin_*`, `_qgs_*`, `_project_*`,
  `_form_create`, `_form_backup`, `_gpx_import`, `_photo_*`. Form
  templates: schema source-of-truth lives in crate; rfp’s QML overlays
  decorate that schema for QGIS rendering.

## Status

Early. File structure not yet committed — umbrella issue frames the
problem space before opinionated layout is adopted.

## Bootstrap note

This CLAUDE.md is a minimal placeholder. Run `/claude-md-init` to inject
the standard soul conventions block (newgraph, karpathy, planning,
code-check, sred, comms, etc.).

# Code Check Conventions

Structured checklist for reviewing diffs before commit. Used by
`/code-check`. Add new checks here when a bug class is discovered — they
compound over time.

## Shell Scripts

### Quoting

- Variables in double-quoted strings containing single quotes break if
  value has `'`
- `"echo '${VAR}'"` — if VAR contains `'`, shell syntax breaks
- Use `printf '%s\n' "$VAR" | command` to pipe values safely
- Heredocs: unquoted `<<EOF` expands variables locally, `<<'EOF'` does
  not — know which you need

### Paths

- Hardcoded absolute paths (`/Users/airvine/...`) break for other users
- Use `REPO_ROOT="$(cd "$(dirname "$0")/<relative>" && pwd)"`
- After moving scripts, verify `../` depth still resolves correctly
- Usage comments should match actual script location

### Silent Failures

- `|| true` hides real errors — is the failure actually safe to ignore?
- Empty variable before destructive operation (rm, destroy) — add guard:
  `[ -n "$VAR" ] || exit 1`
- `grep` returning empty silently — downstream commands get empty input

### Process Visibility

- Secrets passed as command-line args are visible in `ps aux`
- Use env files, stdin pipes, or temp files with `chmod 600` instead

## Cloud-Init (YAML)

### ASCII

- Must be pure ASCII — em dashes, curly quotes, arrows cause silent
  parse failure
- Check with: `perl -ne 'print "$.: $_" if /[^\x00-\x7F]/' file.yaml`

### State

- `cloud-init clean` causes full re-provisioning on next boot — almost
  never what you want before snapshot
- Use `tailscale logout` not `tailscale down` before snapshot
  (deregister vs disconnect)

### Template Variables

- Secrets rendered via `templatefile()` are readable at
  `169.254.169.254` metadata endpoint
- Acceptable for ephemeral machines, document the tradeoff

## OpenTofu / Terraform

### State

- Parsing `tofu state show` text output is fragile — use `tofu output`
  instead
- Missing outputs that scripts need — add them to main.tf
- Snapshot/image IDs in tfvars after deleting the snapshot — stale
  reference

### Destructive Operations

- Validate resource IDs before destroy: `[ -n "$ID" ] || exit 1`
- `tofu destroy` without `-target` destroys everything including
  reserved IPs
- Snapshot ID extraction: use `--resource droplet` and `grep -F` for
  exact match

## Security

### Secrets in Committed Files

- `.tfvars` must be gitignored (contains tokens, passwords)
- `.tfvars.example` should have all variables with empty/placeholder
  values
- Sensitive variables need `sensitive = true` in variables.tf

### Firewall Defaults

- `0.0.0.0/0` for SSH is world-open — document if intentional
- If access is gated by Tailscale, say so explicitly

### Credentials

- Passwords with special chars (`'`, `"`, `$`, `!`) break naive shell
  quoting
- `printf '%q'` escapes values for shell safety
- Temp files for secrets: create with `chmod 600`, delete after use

## R / Package Installation

### pak Behavior

- pak stops on first unresolvable package — all subsequent packages are
  skipped
- Removed CRAN packages (like `leaflet.extras`) must move to GitHub
  source
- PPPM binaries may lag a few hours behind new CRAN releases

### Reproducibility

- Branch pins (`pkg@branch`) are not reproducible — document why used
- Pinned download URLs (RStudio .deb) go stale — document where to
  update

## General

### Adopting Existing Config

When importing config from one location into a canonical one (legacy
`~/.bash_profile` → dotfiles repo, old script’s env → repo, another
project’s `settings.json` → soul):

- **Verify every referenced path/binary exists.** Dead PATH exports,
  missing interpreters, stale env vars should be cut, not codified.
  Shell paths:
  `for p in $(echo "$PATH" | tr ':' ' '); do [ -d "$p" ] || echo "DEAD: $p"; done`
- **Ask before dropping a reference** — it may be something the user
  forgot to reinstall on this machine, not something to delete.
- **Curated subset, not verbatim copy.** The diff should reflect what
  you verified, not the whole source.

### Documentation Staleness

- Moving/renaming scripts: update CLAUDE.md, READMEs, usage comments
- New variables: update .tfvars.example
- New workflows: update relevant README

# Comms Conventions

This repo has a `comms/` directory — you’re in the cross-repo
Claude-to-Claude messaging system. Full protocol in `comms/README.md`.
Peer list (who to scan) in `soul/conventions/comms_peers.md`
(internal-only). Load-bearing behaviors below.

## On Session Start

1.  **Inbound scan.** `<this-repo>/comms/*/` — files with `status: open`
    and mtime newer than your last `comms/` commit are mail for you.
2.  **Outbound scan.** For each peer in `comms_peers.md`, check
    `<peer>/comms/<this-repo>/*.md` — files with
    `from: <this-repo>, status: open` are your un-answered sent mail.

If either surfaces open threads, raise to the user before starting other
work.

## Commit Prefix

- `comms(→peer):` — you committed a file in peer’s repo (outbound)
- `comms(←peer):` — you committed a file in your own repo (inbound
  reply)
- `comms:` — meta (close, reopen, rename, README update)

Arrow points to the repo whose `comms/` contains the file you committed.

## Non-negotiables

- One commit per appended message.
- **Push immediately.** Un-pushed comms is invisible to the other
  Claude.
- Code + comms = separate commits.
- Status flips bundle with the triggering message.
- **Use `git commit --only <file>`** for any commit in a peer’s repo
  (thread files). Immune to index races from parallel sessions.

## Propagation: soul publishes, peers pull

Soul is the source of truth for `comms/README.md`. Peers sync by running
`/comms-init` in their own repo, from their own Claude session. **Do not
push README updates into a peer’s repo from another session** —
cross-session index races can bundle unrelated staged files into
misleading commits.

Within your own session, the only things you commit into a peer’s repo
are **thread files** (hosted in the receiver’s repo per the
receiver-hosts rule). Everything else — README syncs, infra — the
peer-Claude pulls itself.

### Cross-repo thread commits: which branch?

Commit on peer’s **current branch** — whatever they’ve got checked out.
Don’t stash, switch, or force main.

If peer isn’t on main, surface to the user: *“thread landing on
`<peer>`:`<branch>`, won’t hit main until PR merges. Continue or hold?”*
If peer has complicated local state (mid-rebase, partial merge), defer
to the user.

# LLM Behavioral Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with
project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For
trivial tasks, use judgment.

## 1. Think Before Coding

**Don’t assume. Don’t hide confusion. Surface tradeoffs.**

Before implementing: - State your assumptions explicitly. If uncertain,
ask. - If multiple interpretations exist, present them - don’t pick
silently. - If a simpler approach exists, say so. Push back when
warranted. - If something is unclear, stop. Name what’s confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No “flexibility” or “configurability” that wasn’t requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: “Would a senior engineer say this is overcomplicated?” If
yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code: - Don’t “improve” adjacent code, comments,
or formatting. - Don’t refactor things that aren’t broken. - Match
existing style, even if you’d do it differently. - If you notice
unrelated dead code, mention it - don’t delete it.

When your changes create orphans: - Remove imports/variables/functions
that YOUR changes made unused. - Don’t remove pre-existing dead code
unless asked.

The test: Every changed line should trace directly to the user’s
request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals: - “Add validation” → “Write tests
for invalid inputs, then make them pass” - “Fix the bug” → “Write a test
that reproduces it, then make it pass” - “Refactor X” → “Ensure tests
pass before and after”

For multi-step tasks, state a brief plan:

    1. [Step] → verify: [check]
    2. [Step] → verify: [check]
    3. [Step] → verify: [check]

Strong success criteria let you loop independently. Weak criteria (“make
it work”) require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs,
fewer rewrites due to overcomplication, and clarifying questions come
before implementation rather than after mistakes.

# Planning Conventions

How Claude manages structured planning for complex tasks using
planning-with-files (PWF).

## When to Plan

Use PWF when a task has multiple phases, requires research, or involves
more than ~5 tool calls. Triggers: - User says “let’s plan this”, “plan
mode”, “use planning”, or invokes `/planning-init` - Complex issue work
begins (multi-step, uncertain approach) - Claude judges the task
warrants structured tracking

Skip planning for single-file edits, quick fixes, or tasks with obvious
next steps.

## The Workflow

1.  **Explore first** — Enter plan mode (read-only). Read code, trace
    paths, understand the problem before proposing anything.
2.  **Plan to files** — Write the plan into 3 files in
    `planning/active/`:
    - `task_plan.md` — Phases with checkbox tasks
    - `findings.md` — Research, discoveries, technical analysis
    - `progress.md` — Session log with timestamps and commit refs
3.  **Commit the plan** — Commit the planning files before starting
    implementation. This is the baseline.
4.  **Work in atomic commits** — Each commit bundles code changes WITH
    checkbox updates in the planning files. The diff shows both what was
    done and the checkbox marking it done.
5.  **Code check before commit** — Run `/code-check` on staged diffs
    before committing. Don’t mark a task done until the diff passes
    review.
6.  **Archive when complete** — Move `planning/active/` to
    `planning/archive/` via `/planning-archive`. Write a README.md in
    the archive directory with a one-paragraph outcome summary and
    closing commit/PR ref — future sessions scan these to catch up fast.

## Atomic Commits (Critical)

Every commit that completes a planned task MUST include: - The
code/script changes - The checkbox update in `task_plan.md` (`- [ ]` -\>
`- [x]`) - A progress entry in `progress.md` if meaningful

This creates a git audit trail where `git log -- planning/` tells the
full story. Each commit is self-documenting — you can backtrack with git
and understand everything that happened.

## File Formats

### task_plan.md

Phases with checkboxes. This is the core tracking file.

``` markdown
# Task Plan

## Phase 1: [Name]
- [ ] Task description
- [ ] Another task

## Phase 2: [Name]
- [ ] Task description
```

Mark tasks done as they’re completed: `- [x] Task description`

### findings.md

Append-only research log. Discoveries, technical analysis, things
learned.

``` markdown
# Findings

## [Topic]
[What was found, with source/date]
```

### progress.md

Session entries with commit references.

``` markdown
# Progress

## Session YYYY-MM-DD
- Completed: [items]
- Commits: [refs]
- Next: [items]
```

## Directory Structure

    planning/
      active/          <- Current work (3 PWF files)
      archive/         <- Completed issues
        YYYY-MM-issue-N-slug/

If `planning/` doesn’t exist in the repo, run `/planning-init` first.

## Skills

| Skill               | When to use                                        |
|---------------------|----------------------------------------------------|
| `/planning-init`    | First time in a repo — creates directory structure |
| `/planning-update`  | Mid-session — sync checkboxes and progress         |
| `/planning-archive` | Issue complete — archive and create fresh active/  |

# R Package Development Conventions

Standards for R package development across New Graph Environment
repositories. Based on [R Packages (2e)](https://r-pkgs.org/) by Hadley
Wickham and Jenny Bryan.

**Reference packages:** When starting a new package, study these
existing packages for patterns: `flooded`, `gq`. They demonstrate the
conventions below in practice (DESCRIPTION fields, README layout,
NEWS.md style, pkgdown setup, test structure, hex sticker, etc.).

## Style

- tidyverse style guide: snake_case, pipe operators (`|>` or `%>%`)
- Match existing patterns in each codebase
- Use `pak` for package installation (not `install.packages`)
- Prefix column name vectors with `cols_` for discoverability in the
  environment pane: `cols_all`, `cols_carry`, `cols_split`,
  `cols_writable`. Same principle for other grouped vectors (`params_`,
  `tbl_`, etc.)

## Package Structure

Follow R Packages (2e) conventions: - `R/` for functions,
`tests/testthat/` for tests, `man/` for docs - `DESCRIPTION` with proper
fields (Title, Description, <Authors@R>) - `DESCRIPTION` URL field:
include both the GitHub repo and the pkgdown site so pkgdown links
correctly (e.g.,
`URL: https://github.com/OWNER/PKG, https://owner.github.io/PKG/`) -
`NAMESPACE` managed by roxygen2 (`#' @export`, `#' @import`,
`#' @importFrom`) - Never edit `NAMESPACE` or `man/` by hand

## One Function, One File

Each exported function gets its own R file and its own test file: -
`R/fl_mask.R` → `tests/testthat/test-fl_mask.R` - Commit the function
and its tests together - Use `Fixes #N` in the commit message to close
the corresponding issue

## GitHub Issues and SRED Tracking

### Issue-per-function workflow

File a GitHub issue for each function before building it. This creates a
traceable record of what was planned, built, and verified.

### Branching for SRED

For new packages or major features, work on a branch and merge via PR:

    main ← scaffold-branch (PR closes with "Relates to NewGraphEnvironment/sred-2025-2026#N")

This gives one PR that contains all commits — a single SRED
cross-reference covers the entire body of work. Individual commits
within the branch close their respective function issues with
`Fixes #N`.

### Closing issues

Close function issues via commit messages — see Closing Issues in
newgraph conventions.

## Testing

- Use testthat 3e (`Config/testthat/edition: 3` in DESCRIPTION)

- Run `devtools::test()` before committing

- Test files mirror source: `R/utils.R` -\>
  `tests/testthat/test-utils.R`

- Test for edge cases and potential failures, not just happy paths

- Tests must pass before closing the function’s issue

- Always grep for errors in the same command as the test run to avoid
  running twice:

  ``` bash
  Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5
  ```

  For error context: `grep -E "(ERROR:|FAIL )" -A 10 | head -25`

## Examples and Vignettes

### Runnable examples on every exported function

Examples are how users discover what a function does. They must: -
**Actually run** — no `\dontrun{}` unless external resources are
required - **Use bundled test data** via
[`system.file()`](https://rdrr.io/r/base/system.file.html) so they work
for anyone - **Show why the function is useful** — not just that it
runs, but what it produces and why you’d use it - **Use qualified
names** for non-exported dependencies (`terra::rast()`, `sf::st_read()`)
since examples run in the user’s environment

### Vignettes

At least one vignette showing the full pipeline on real data: -
Demonstrates the package solving an actual problem end-to-end - Uses
bundled test data (committed to `inst/testdata/`) - Hosted on pkgdown so
users can read it without installing

**Output format:** Use `bookdown::html_vignette2` (not
[`rmarkdown::html_vignette`](https://pkgs.rstudio.com/rmarkdown/reference/html_vignette.html))
for figure numbering and cross-references. Requires `bookdown` in
Suggests and chunks must have `fig.cap` for numbered figures.
Cross-reference with `Figure \@ref(fig:chunk-name)`.

**Vignettes that need external resources (DB, API, STAC):** Do NOT use
the `.Rmd.orig` pre-knit pattern — it breaks `bookdown` figure numbering
because knitr evaluates chunks during pre-knit and emits `![](path)`
markdown that bookdown can’t number.

Instead, separate data generation from presentation: 1.
`data-raw/vignette_data.R` — runs the queries, saves results as `.rds`
to `inst/testdata/` (or `inst/vignette-data/`) 2. Vignette loads `.rds`
files, all chunks run live during pkgdown build 3. Note at top of
vignette: “Data generated by `data-raw/script.R`” 4. bookdown controls
all chunks — figure numbers, cross-refs work

This is the same pattern as test data: `data-raw/` documents how the
data was produced, committed artifacts make vignettes reproducible
without the external resource.

### Test data

- Created via a script in `data-raw/` that documents exactly how the
  data was produced (database queries, spatial crops, etc.)
- Committed to `inst/testdata/` — small enough to ship with the package
- Used by tests, examples, and vignettes — one dataset, three purposes

## Documentation

- roxygen2 for all exported functions
- `@import` or `@importFrom` in the package-level doc
  (`R/<pkg>-package.R`) to populate NAMESPACE — don’t rely on `::`
  everywhere in function bodies
- pkgdown site for public packages with `_pkgdown.yml` (bootstrap 5)
- GitHub Action for pkgdown (`usethis::use_github_action("pkgdown")`)

## lintr

Run
[`lintr::lint_package()`](https://lintr.r-lib.org/reference/lint.html)
before committing R package code. Fix all warnings — every lint should
be worth fixing.

### Recommended .lintr config

``` r
linters: linters_with_defaults(
    line_length_linter(120),
    object_name_linter(styles = c("snake_case", "dotted.case")),
    commented_code_linter = NULL
  )
exclusions: list(
    "renv" = list(linters = "all")
  )
```

- 120 char line length (default 80 is too strict for data pipelines)
- Allow dotted.case (common in base R and legacy code)
- Suppress commented code lints (exploratory R scripts often have
  commented alternatives)
- Exclude renv directory entirely

## Dependencies

- Minimize Imports — use `Suggests` for packages only needed in
  tests/vignettes
- Pin versions only when breaking changes are known
- Prefer packages already in the tidyverse ecosystem

## Releasing

1.  Update `NEWS.md` — keep it concise:
    - First release: one line (e.g., “Initial release. Brief
      description.”)
    - Later releases: describe what changed and why, not
      function-by-function. Link to the pkgdown reference page for
      details — don’t duplicate it.
    - Don’t list every function; the pkgdown reference page is the
      single source of truth for what’s in the package.
2.  Bump version in `DESCRIPTION` (e.g., `0.0.0.9000` → `0.1.0`) — as
    the **final** commit of the branch, after verification numbers/tests
    are final. Mid-branch bumps are premature and churn: additional code
    changes end up bundled inside a “release” that already claimed the
    version.
3.  Commit as “Release vX.Y.Z”
4.  Tag: `git tag vX.Y.Z && git push && git push --tags`

## Repository Setup

### Branch protection

Protect main from deletion and force pushes:

``` bash
gh api repos/OWNER/REPO/rulesets --method POST --input - <<'EOF'
{
  "name": "Protect main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
  ],
  "conditions": { "ref_name": { "include": ["refs/heads/main"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" } ]
}
EOF
```

### Scaffold checklist

- `usethis::create_package(".")`
- `usethis::use_mit_license("New Graph Environment Ltd.")`
- `usethis::use_testthat(edition = 3)`
- `usethis::use_pkgdown()`
- `usethis::use_github_action("pkgdown")`
- `usethis::use_directory("dev")` — reproducible setup script
- `usethis::use_directory("data-raw")` — data generation scripts
- Hex sticker via `hexSticker` (see `data-raw/make_hexsticker.R`)
- Set GitHub Pages to serve from `gh-pages` branch

### dev/dev.R

Keep a `dev/dev.R` file that documents every setup step. Not idempotent
— run interactively. This is the reproducible recipe for the package
scaffold.

## README

Keep the README lean: - Hex sticker, one-line description, install,
example showing *why* it’s useful - Link to pkgdown vignette and
function reference — don’t duplicate them - Don’t maintain a function
table — it’s just another thing to keep updated and pkgdown’s reference
page is the single source of truth

## LLM Workflow

When an LLM assistant modifies R package code: 1. Run
[`lintr::lint_package()`](https://lintr.r-lib.org/reference/lint.html) —
fix issues before committing 2. Run `devtools::test()` with error grep —
ensure tests pass in one call:
`bash Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5`
3. Run `devtools::document()` and grep for results:
`bash Rscript -e 'devtools::document()' 2>&1 | grep -E "(Writing|Updating|warning)" | tail -10`
4. Check `devtools::check()` passes for releases — capture results in
one call:
`bash Rscript -e 'devtools::check()' 2>&1 | grep -E "(ERROR|WARNING|NOTE|errors|warnings|notes)" | tail -10`
