---
description: Change a role: status, person, dates, salary, contribution rate, or an IRD temporary rate reduction date.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- update-hire --hire="Sales manager" --status=filled --person="..." --evidence="..." --actor="Your name"`.

A KiwiSaver rate of 3% needs the IRD reduction date (--reduced-rate-until) or /compliance flags it.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
