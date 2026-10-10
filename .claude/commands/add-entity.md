---
description: Add a company to the group: country, currency, GST or BAS period and its Adaptive Planning level code.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- add-entity --name="..." --country=NZ --actor="Your name"`.

NZ defaults to NZD and two-monthly GST; AU to AUD and quarterly BAS. Ask for the real filing frequency.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
