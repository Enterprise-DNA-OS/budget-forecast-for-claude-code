---
description: Draft the covenant compliance certificate for an entity's lender into drafts/.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- draft-lender-certificate --entity="..."`.

Remind the operator to check the facility agreement's definitions before a director signs.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
