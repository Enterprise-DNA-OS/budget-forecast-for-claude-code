---
description: GST returns (NZ) and BAS (AU) due, overdue or recently lodged, from each entity's filing frequency.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- tax-calendar`.

Due dates follow IRD and ATO standard dates and are not moved for weekends or holidays; docs/compliance.md has the rules.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
