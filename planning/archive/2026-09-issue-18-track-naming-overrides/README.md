## Outcome
`nge/track_sessions` gained the four crew-supplied naming columns an rfp-deployed
tracking layer carries (`track_name`, `track_type`, `track_description`,
`named_by`) as optional strings, with a new upstream variant for that layer and a
corrected note on the plugin-only one. `nge/track_annotations` was reshaped into a
table of overrides — the same three names and types as the captured columns,
`notes` dropped — under one rule: a non-key annotation column sharing a captured
column's name overrides it where non-`NA`, `coalesce(annotation, captured)`. The
reshape was chosen over a minimal precedence footnote because measuring the blast
radius (trap's join is generic, the GPX reader never carries names, the one live
annotation table was seeded empty) showed almost nothing to break; that reasoning
became the "reshape, don't accrete" rule in CLAUDE.md. Two things the plan review
caught changed the contract: `crt_schema_conform()` leaves absent optional columns
absent, so the *reader* must always emit all four or stacked snapshots drift; and
trap pins `crate@v0.3.0`, so the consumer change is a follow-up (trap#28) gated on
a crate release. No R code changed — YAML, registry, tests, and prose only.

## Measurement
rfp's shipped lookup carries six `track_type` values with `day log` as default;
its roxygen (and the issue body quoting it) carried five with no default — rfp#255.
Restore-the-bug on both new guards: flipping one naming column to `required: true`
refuses the plugin-shaped frame; renaming `track_type` in one YAML fails the
parity test at the set-equality and type assertions. Suite 228 → 235 passing.
`/code-check` four rounds: clean, one fragile (override rule matched key columns),
one fragile (parity test would fail on the reserved `annotated_by`), three prose
items — all fixed before commit.

Closed by: commits 4f52998, 3f207f1, merged via the PR from branch `18-nge-track-sessions-drops-the-four-crew-s`
