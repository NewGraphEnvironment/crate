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
Load-bearing behaviors below.

## On Session Start

1.  **Inbound scan.** `<this-repo>/comms/*/` — files with `status: open`
    and mtime newer than your last `comms/` commit are mail for you.
2.  **Outbound scan.** For each peer below, check
    `<peer>/comms/<this-repo>/*.md` — files with
    `from: <this-repo>, status: open` are your un-answered sent mail.

If either surfaces open threads, raise to the user before starting other
work.

## Peers

Recurring cross-repo conversation partners — every peer auto-scans this
list on session start. Not every repo with `comms/` belongs here;
ephemeral or single-use adopters stay out (e.g. regional/annual
reporting repos consume infra rather than shape it — their template repo
is peered, they aren’t).

- rtj
- kdot
- soul
- crate
- fresh
- link
- rfp
- fish_passage_template_reporting

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
  (thread files). Immune to index races from parallel sessions — commits
  only the named path regardless of what else is staged.

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

# New Graph Environment Conventions

Core patterns for professional, efficient workflows across New Graph
Environment repositories.

## Ecosystem Overview

Five repos form the governance and operations layer across all New Graph
Environment work:

| Repo                                                                | Purpose                                                       | Analogy     |
|---------------------------------------------------------------------|---------------------------------------------------------------|-------------|
| [compass](https://github.com/NewGraphEnvironment/compass)           | Ethics, values, guiding principles                            | The “why”   |
| [soul](https://github.com/NewGraphEnvironment/soul)                 | Standards, skills, conventions for LLM agents                 | The “how”   |
| [compost](https://github.com/NewGraphEnvironment/compost)           | Communications templates, email workflows, contact management | The “who”   |
| [rtj](https://github.com/NewGraphEnvironment/rtj) (formerly awshak) | Infrastructure as Code, deployment                            | The “where” |
| [gq](https://github.com/NewGraphEnvironment/gq)                     | Cartographic style management across QGIS, tmap, leaflet, web | The “look”  |

**Adaptive management:** Conventions evolve from real project work, not
theory. When a pattern is learned or refined during project work,
propagate it back to soul so all projects benefit. The `/claude-md-init`
skill builds each project’s `CLAUDE.md` from soul conventions.

**Cross-references:**
[sred-2025-2026](https://github.com/NewGraphEnvironment/sred-2025-2026)
tracks R&D activities across repos. Compost is the centralized
communications workflow — all email drafts, contact registry, and
external outreach are authored there, not in individual project repos.

## Issue Workflow

### Before Creating an Issue (non-negotiable)

1.  **Check for duplicates:**
    `gh issue list --state open --search "<keywords>"` – search before
    creating
2.  **Link to SRED:** If work involves infrastructure, R&D, tooling, or
    performance benchmarking, add
    `Relates to NewGraphEnvironment/sred-2025-2026#N` (match by repo
    name in SRED issue title)
3.  **One issue, one concern.** Keep focused.

### Professional Issue Writing

Write issues with clear technical focus:

- **Use normal technical language** in titles and descriptions
- **Focus on the problem and solution** approach
- **Add tracking links at the end** (e.g., `Relates to Owner/repo#N`)

#### Client-aware tone

Issues, PR descriptions, and commit messages are client-visible
deliverables, not internal notes.

Avoid in these artifacts: - Framing work as unsolicited or unpaid (“not
assigned by a client”) - Self-justifying adjectives (“defensible”,
“rigorous”) — show, don’t claim - Internal workflow meta (PWF refs, SRED
xrefs, planning context) - Performative effort language (“attempts were
unsuccessful”) — state factual current state

**Integrity-preserving ≠ self-effacing.** Factual, not performatively
humble.

**Scope:** repo artifacts (issues, PRs, commits, reports). Does not
apply to internal planning docs, CLAUDE.md, or chat.

**Issue body structure:**

``` markdown
## Problem
<what's wrong or missing>

## Proposed Solution
<approach>

Relates to #<local>
Relates to NewGraphEnvironment/sred-2025-2026#<N>
```

### GitHub Issue Creation - Always Use Files

The `gh issue create` command with heredoc syntax fails repeatedly with
EOF errors. ALWAYS use `--body-file`:

``` bash
cat > /tmp/issue_body.md << 'EOF'
## Problem
...

## Proposed Solution
...
EOF

gh issue create --title "Brief technical title" --body-file /tmp/issue_body.md
```

## Closing Issues

**DO:** Close issues via commit messages. The commit IS the closure and
the documentation.

    Fix broken DEM path in loading pipeline

    Update hardcoded path to use config-driven resolution.

    Fixes #20
    Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>

**DON’T:** Close issues with `gh issue close`. This breaks the audit
trail — there’s no linked diff showing what changed.

- `Fixes #N` or `Closes #N` — auto-closes and links the commit to the
  issue
- `Relates to #N` — partial progress, does not close
- Always close issues when work is complete. Don’t leave stale open
  issues.

## Commit Quality

Write clear, informative commit messages:

    Brief description (50 chars or less)

    Detailed explanation of changes and impact.

    Fixes #<issue> (or Relates to #<issue>)
    Relates to NewGraphEnvironment/sred-2025-2026#<N>

    Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>

**When to commit:** - Logical, atomic units of work - Working state
(tests pass) - Clear description of changes

**What to avoid:** - “WIP” or “temp” commits in main branch - Combining
unrelated changes - Vague messages like “fixes” or “updates”

## LLM Agent Conventions

Rules learned from real project sessions. These apply across all repos.

- **Install missing packages, don’t workaround** — if a package is
  needed, ask the user to install it (e.g. `pak::pak("pkg")`). Don’t
  write degraded fallback code to avoid the dependency.
- **Never hardcode extractable data** — if coordinates, station names,
  or metadata can be pulled from an API or database at runtime, do that.
  Don’t hardcode values that have a programmatic source.
- **Close issues via commits, not `gh issue close`** — see Closing
  Issues above.
- **Cite primary sources** — see references conventions.

## Naming Conventions

**Pattern: `noun_verb-detail`** – noun first, verb second across all
naming:

| What       | Example                                                  |
|------------|----------------------------------------------------------|
| Skills     | `claude-md-init`, `gh-issue-create`, `planning-update`   |
| Scripts    | `stac_register-baseline.sh`, `stac_register-pypgstac.sh` |
| Logs       | `20260209_stac_register-baseline_stac-dem-bc.txt`        |
| Log format | `yyyymmdd_noun_verb-detail_target.ext`                   |

Scripts and logs live together: `scripts/<module>/logs/`

## Projects vs Milestones

- **Projects** = daily cross-repo tracking (always add to relevant
  project)
- **Milestones** = iteration boundaries (only for release/claim prep)
- Don’t double-track unless there’s a reason

| Content                                   | Project                               |
|-------------------------------------------|---------------------------------------|
| R&D, experiments, SRED-related            | **SRED R&D Tracking (#8)**            |
| Data storage, sqlite, postgres, pipelines | **Data Architecture (#9)**            |
| Fish passage field/reporting              | **Fish Passage 2025 (#6)**            |
| Restoration planning                      | **Aquatic Restoration Planning (#5)** |
| QGIS, Mergin, field forms                 | **Collaborative GIS (#3)**            |

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

# SRED Conventions

How SR&ED tracking integrates with New Graph Environment’s development
workflows.

## The Claim: One Project

All SRED-eligible work across NGE falls under a **single continuous
project**:

> **Dynamic GIS-based Data Processing and Reporting Framework**

- **Field:** Software Engineering (2.02.09)
- **Start date:** May 2022
- **Fiscal year:** May 1 – April 30
- **Consultant:** Boast Capital (prepares final technical report)

**Do not fragment work into separate claims.** Each fiscal year’s work
is structured as iterations within this one project. Internal tracking
(experiment numbers in `sred-2025-2026`) maps to iterations — Boast
assembles the final narrative.

## Tagging Work for SRED

### Commits

Use `Relates to NewGraphEnvironment/sred-2025-2026#N` in commit messages
when work is SRED-eligible.

### Time entries (rolex)

Tag hours with `sred_ref` field linking to the relevant `sred-2025-2026`
issue number.

### GitHub issues

Link SRED-eligible issues to the tracking repo:
`Relates to NewGraphEnvironment/sred-2025-2026#N`

## What Qualifies as SRED

**Eligible (systematic investigation to overcome technological
uncertainty):** - Building tools/functions that don’t exist in standard
practice - Prototyping new integrations between systems (GIS ↔︎ reporting
↔︎ field collection) - Testing whether an approach works and documenting
why it did/didn’t - Iterating on failed approaches with new hypotheses

**Not eligible:** - Standard configuration of known tools - Routine bug
fixes in working systems - Writing reports using the framework (that’s
service delivery)

**The test:** “Did we try something we weren’t sure would work, and did
we learn something from the attempt?” If yes, it’s likely eligible.
