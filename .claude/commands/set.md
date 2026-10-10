---
description: Set one value in one version: entity, account, month, amount.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- set --version="Downside" --entity="..." --account=6200 --month=YYYY-MM --amount=15000 --evidence="..." --actor="Your name"`.

Show the before and after. Locked versions refuse.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
