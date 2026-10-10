---
description: Add a month-end close task with an owner and due date.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- task --entity="..." --task="..." --owner="..." --due=YYYY-MM-DD --actor="Your name"`.

Defaults to the last closed month.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
