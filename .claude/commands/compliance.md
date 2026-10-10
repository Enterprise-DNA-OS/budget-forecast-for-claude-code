---
description: Record checks against the rules in docs/compliance.md: KiwiSaver and super rates in the hiring plan, GST and BAS lodgement, solvency certificates, s254T net assets, cash after distributions, budget approval, covenant breaches.
---

Read CLAUDE.md first. Add `--json` when you need to read the result yourself. Resolve entity, account and version names with `entities`, `accounts` or `versions`; if a name is ambiguous, show the candidates and ask. Never invent an actor, an amount, a date, a reason or evidence.

Run `npm run plan -- compliance`.

Cite the rule name and its source from docs/compliance.md for each finding. Do not guess at law; if a rule looks out of date, say so and stop.

Nothing here sends, deletes or publishes. Drafts go to drafts/ for a person to send.
