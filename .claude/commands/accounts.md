---
description: The chart of accounts: code, name, type, tag and budget holder.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- accounts`.

Tags drive the maths: cash and debt for covenants, interest, depreciation and tax for EBITDA, wages for people costs. Say if an account the operator mentions has no budget holder.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
