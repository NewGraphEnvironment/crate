# Field forms get an envelope now and their meaning later

**Date:** 2026-09-01
**Schema:** `schemas/nge/form_capture.yaml`

## Decision

Field-form records conform to `nge/form_capture`, which declares **five**
columns — `project`, `form`, `record_id`, `schema_version`, `captured_at` — and
nothing about what any observation means. A form's own columns pass through
`crt_schema_conform()` untouched, on the documented rule that the schema is a
floor rather than a ceiling.

Vintage is a column (`schema_version`), not a filename. Two shapes of one form
are one logical table.

`harvested_at` is **not** a column, and is recorded in `forward_compat` with the
reason so it is not re-proposed.

## Trigger

trap is harvesting five field forms off Mergin
(NewGraphEnvironment/trap#2), and it has a date on it: a July 2026 capture of 49
records sits in live forms that have to be rebuilt to a wider schema before a
field session running Sept 21–29. Until those records are harvested, the rebuild
that fixes the form is the operation that erases them (NewGraphEnvironment/rfp#218).

#13 is the real answer — canonical schemas for the whole form family, five forms
of roughly thirty columns each, plus a predicate for whether a record can answer
a given question. It will not land in three weeks.

The alternative was to let trap define the columns itself and reconcile later.
That is the thing the split between these repos exists to prevent: a reader that
knows what a column means is a schema nobody registered, and the last time it
happened the definitions had to be extracted back out (see
`20260824_track_canonical_two_tables.md`, same failure).

An envelope is the smallest thing that is *not* that. It records where a record
came from and what shape it arrived in — facts about provenance, which is
already crate's business — and refuses to say more.

## Why these five and not more

Each earns its place by being needed to identify a record without knowing
anything about the form:

- `project` + `form` + `record_id` is identity. Three parts because neither the
  project nor the form alone namespaces a GeoPackage `fid`.
- `schema_version` is what makes a null interpretable. Without it, a column that
  is absent in the older vintage and blank in the newer one reads the same way,
  and the difference between "not asked" and "not answered" is exactly what a
  QA form is for.
- `captured_at` is what makes a record joinable to anything else, and it is the
  fingerprint that makes a `record_id` reassignment detectable.

`captured_by` was considered and declined. Forms carry both a capturing account
and a free-text crew list; they are different claims and the second is
unstructured, so declaring one canonical column would be choosing between them
without evidence. Recorded in `forward_compat` for #13.

## Two measurements

Both taken on `form_vri_qa` at `newgraph/restoration_wedzin_kwa` v112,
2026-09-01, and both bear on #13 rather than only on this entry.

**A narrower vintage is a strict subset.** 28 non-geometry columns captured, 52
in the then-current repo schema, and **zero** captured columns absent from the
repo set. #13's "permissive schema, strict question" model assumes this holds;
it had been assumed rather than measured. It holds here. It is not guaranteed to
hold for a form whose columns were ever *renamed*, which is why the assumption is
worth naming rather than relying on.

**`harvested_at` would break byte-identical snapshots.** #13 proposes it as a
per-record column. It moves on every run, so every harvest rewrites a snapshot's
bytes with nothing behind the diff — precisely the failure the consumer's
manifest no-op guard exists to prevent, and the same call already made there for
the upstream source version. Harvest time is a property of the harvest, not of
the observation. #13's body is corrected.

## What this does not decide

What any form column means, what units it is in, what its vocabulary is, and
whether a given record can answer a given question. All of that is #13.

This entry is deliberately cheap to supersede: when #13 registers `nge/form_*`
schemas, they declare these five columns too and a conformed record satisfies
both. Nothing has to be un-decided.

## Related

- #14 — this entry
- #13 — canonical schemas for field forms
- NewGraphEnvironment/trap#2 — the harvest that needs it
- NewGraphEnvironment/rfp#218 — why the harvest is time-boxed
