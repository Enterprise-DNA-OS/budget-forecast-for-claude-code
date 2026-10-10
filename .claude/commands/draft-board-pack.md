---
description: Draft the monthly board pack for one entity into drafts/.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- draft-board-pack --entity="..."`.

Open it, check the figures read sensibly, and tell the operator what a director will ask about first.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
