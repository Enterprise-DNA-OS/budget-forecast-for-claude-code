---
description: Record or change a proposed, declared or paid dividend.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- distribution --entity="..." --amount=150000 --pay-on=YYYY-MM-DD --evidence="..." --actor="Your name"`.

Use --ref=<id> with --status, --declared, --pay-on or --in-forecast to change one. Then run /distributions and /compliance.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
