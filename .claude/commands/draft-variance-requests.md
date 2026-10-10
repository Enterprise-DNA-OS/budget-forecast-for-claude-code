---
description: Draft one email per budget holder asking them to explain last month's unexplained variances, into drafts/.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- draft-variance-requests`.

Drafts only. A person sends them.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
