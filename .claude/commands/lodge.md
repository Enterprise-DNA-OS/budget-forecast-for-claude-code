---
description: Record a GST return or BAS as lodged.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- lodge --entity="..." --month=YYYY-MM --reference="..." --evidence="Filed in myIR" --actor="Your name"`.

--month is the month the period ends. Lodging here records it; it does not file anything with IRD or the ATO.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
