---
description: The profit and loss for one version, by account, for its months or one month, with net profit per entity.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- pnl --version="Board budget" --entity="Harbourline NZ Ltd"`.

Add --month=YYYY-MM for a single month. Keep currencies apart: never add NZD and AUD.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
