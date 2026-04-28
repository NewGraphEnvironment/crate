# Planning

Tracks planning-with-files (PWF) artifacts for structured task execution and SRED evidence.

## Structure

```
planning/
  active/           <- Current work-in-progress PWF files
    task_plan.md
    findings.md
    progress.md
  archive/          <- Completed issues
    YYYY-MM-issue-N-slug/
```

## Workflow

See planning conventions in CLAUDE.md for the full workflow: plan mode → write PWF files with checkboxes → commit plan → atomic commits → archive.

## Skills

- `/planning-init` — Create this structure (you already ran it)
- `/planning-update` — Sync checkboxes and progress mid-session
- `/planning-archive` — Archive completed work, create fresh active/
