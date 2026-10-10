---
description: Mark a close task done, with the evidence.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- done --task="Accruals" --evidence="..." --actor="Your name"`.

If more than one open task matches, add --entity or use the id.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
