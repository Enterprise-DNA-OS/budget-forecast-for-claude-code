---
description: Last closed month against the approved budget, every P&L line, with whether each variance is explained.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- variance`.

A positive variance is better than budget, negative is worse, for revenue and costs alike. Lead with the largest.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
