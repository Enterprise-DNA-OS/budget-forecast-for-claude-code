---
description: Add a bank covenant: minimum cash, interest cover or debt to EBITDA, with the threshold and test frequency.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- add-covenant --entity="..." --lender="..." --metric="minimum cash" --threshold=250000 --frequency=monthly --evidence="Facility agreement clause" --actor="Your name"`.

Ask for the clause number as evidence.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
