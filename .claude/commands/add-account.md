---
description: Add an account: code, name, type, an optional tag, the budget holder and the Adaptive Planning account code.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- add-account --code=6460 --name="Bad debts" --type=expense --actor="Your name"`.

Ask which tag applies if the account is cash, debt, interest, depreciation, tax or wages.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
