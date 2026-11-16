# Plan review — #67 (Plan agent, 2026-11-16, written here by the parent)

No blockers. Integrity rules, types, grades and the checksum claim all checked against the code.

| Kind | Finding | Disposition |
|---|---|---|
| Ordering | A `decisions:` key in Phase 2 would fail the integrity test until the decision file exists | Taken: the key lands in Phase 3 with the file |
| Gap | Required presence is not non-missing: a row with NA `checksum` conforms | Taken: grade `identified: [checksum, path, size]` on photo_files, tested |
| Gap | The indexer's "row with the reason" for an unreadable file has no column | Declined: the schema is a floor and extra columns pass; the producer carries its own reason column. Recorded in the decision |
| Gap | `relative_to` and `'null'` meaning keys | `'null'` already used; `relative_to` added to `path` |
| Gap | photo_links states no key | Taken: in its description |
| Assumption | `time` given as text with a non-UTC offset is refused | Taken: said in notes (already), and tested |
| Assumption | `time_local` / `time_offset` shapes unspecified | Taken: notes give `YYYY-MM-DDTHH:MM:SS` and `+00:00` for UTC, never `Z` |
| Assumption | Issue says a store key goes "in place of `path`"; plan keeps `path` required | Taken: decision 5 in the decision log |
| Scope | Camtrap DP media needs a zoned timestamp and IDs these tables lack | Taken: mapping worded as partial |
| Acceptance | Nothing checks `time == time_local - time_offset` | Stated as the caller's guarantee; a QC rule is #38's |
| Precision | Receipt digest is `result.parts.<path>.sha256`, and `bytes` matches `size` | Taken |
