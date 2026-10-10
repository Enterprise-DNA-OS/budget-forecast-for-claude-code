---
description: Approve and lock a version so nobody can change it.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- lock --version="..." --approved-by="Board of directors" --evidence="Board minutes" --actor="Your name"`.

Locking is permanent. Confirm with the operator first; a change after that is a new version.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
