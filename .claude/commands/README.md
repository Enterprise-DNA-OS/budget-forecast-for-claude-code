# Slash commands

One file per recurring job. Each command tells Claude Code exactly which CLI command to run (`npm run plan -- <command>`) and how to present the result, so the operator never re-explains the job.

The monthly routine: load actuals (`/import`), `/month-end`, `/draft-variance-requests`, `/comment` as answers come in, `/roll-forecast`, `/covenants`, `/draft-board-pack`. Every Monday: `/weekly-review`.

Add a command every time the same ask comes twice. Frontmatter needs a `description:` line. The body is the brief.
