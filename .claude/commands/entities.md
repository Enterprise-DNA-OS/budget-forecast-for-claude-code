---
description: Every company in the group with its country, currency, GST or BAS period and last closed month.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- entities`.

Point out any entity whose last closed month is behind the others.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
