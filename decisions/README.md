# Decisions

Decision log entries documenting non-obvious calls in crate's canonicalization work. Format: markdown files at `<source>/<YYYYMMDD>_<topic>.md`.

## When to add an entry

Add a decision log entry when:
- Choosing a canonical shape that's not self-evident (e.g. long vs wide)
- Resolving an upstream-shape change that requires a schema bump
- Defining QC rule semantics that codify operator judgment
- Picking between competing data sources for the same canonical type
- Any call that future-Claude or future-collaborators would otherwise wonder about

Don't add an entry for:
- Mechanical work (added a missing column, fixed a typo)
- Choices fully determined by external constraints (e.g. matching a provincial schema verbatim)

## Format

Each entry should include:
- **Decision** (one paragraph stating the call)
- **Trigger** (what forced the decision now)
- **Rationale** (evidence + reasoning)
- **Alternatives considered** (what was rejected and why)
- **Consequences** (what changes downstream)
- **References** (schema YAML, related issues, comms threads)

See `bcfp/20260427_user_habitat_classification_wide_canonical.md` as a template.

## Why decisions live at root, not under inst/

Decisions are authoring/audit artifacts read by humans browsing the repo on GitHub or via `git clone`. They don't need to ship with the installed R package. `.Rbuildignore` excludes `decisions/` from the package build. Schema YAMLs reference decision entries by relative path (e.g. `decisions/bcfp/<file>.md`); the relative path resolves on the GitHub view and via clone, both of which are how humans actually read them.

## Why decisions are first-class (not buried in code comments or schema YAMLs)

- **Searchable evidence trail** for SRED audit
- **Survives schema YAML rewrites** — when a YAML's content changes, the decision history stays intact
- **Human-readable** without code context — onboarding collaborators read `decisions/` to understand "why is the canonical THIS shape"
- **Cross-domain queryable** — `grep -r "long.*canonical" decisions/` surfaces patterns across all source families
