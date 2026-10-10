---
description: Add a budget, forecast or scenario, optionally copied from another version, shifted by months and uplifted by a percentage.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- add-version --name="Budget next year" --kind=budget --starts=YYYY-MM --copy-from=Actuals --shift=12 --uplift=5 --uplift-only=revenue --actor="Your name"`.

Say how many lines were copied and what the new version's net profit is (/pnl).

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
