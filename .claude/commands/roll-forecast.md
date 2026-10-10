---
description: Roll the forecast: a new forecast version with actuals for every closed month and the old forecast for the rest.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- roll-forecast --name="Reforecast 2" --actor="Your name"`.

Run after each month is closed. Then run /outlook and /covenants and say what changed.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
