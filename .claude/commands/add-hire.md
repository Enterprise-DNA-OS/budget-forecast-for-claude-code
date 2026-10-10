---
description: Add a role to the hiring plan. The employer contribution rate defaults to the statutory rate for the country and start date.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- add-hire --entity="..." --role="..." --starts=YYYY-MM-DD --salary=90000 --actor="Your name"`.

Then show /headcount and the cost inside the current forecast.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
