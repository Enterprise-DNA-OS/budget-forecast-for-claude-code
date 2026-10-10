---
description: Bring Adaptive Planning's Export Data CSV into a version, or monthly totals from the accounting system into actuals.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- import adaptive --version="..." --file="imports/adaptive.csv" --map="imports/map.json" --dry-run --actor="Your name"`.

Always run with --dry-run first and show the counts. Unmatched levels or accounts go in the map file (docs/replace-adaptive-planning.md). Monthly actuals from Xero or MYOB: import ledger --file=... with Entity, Account Code, Month, Amount columns. Changed values need --update after the operator has reviewed them.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
