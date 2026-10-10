# Budget and Forecast for Claude Code: operating instructions

This file is the brain. Claude Code reads it at the start of every session. It says who this is for, how work gets done, and the one right way to do each recurring job.

## Who this is for

- **Business:** [YOUR BUSINESS]
- **Operator:** [YOUR NAME], [your role]
- **What matters most:** [for example: the board pack out by the 10th, no covenant surprise, every variance explained]

The system is for a finance team: a finance lead, financial controller or outsourced CFO running budgets, forecasts and the month-end for one company or a small NZ and AU group. The CLI is `scripts/plan.mjs` (`npm run plan -- <command>`); every command accepts `--json`.

Fill this in once. A worker with context knows. A worker without it guesses.

## How to work

1. **Take a brief, not a script.** The operator describes the outcome. You run the right command and present the answer.
2. **Read before you write.** Before drafting anything about a record, read its full history first.
3. **Plain language.** Short sentences. No filler. Numbers in tables.
4. **Silent success, loud problems.** No play-by-play. Say what broke and what you did about it.
5. **Stop at the line.** Anything that sends, deletes, or faces a customer waits for a yes in this session.

## Routing table: one right way for each recurring job

| When the operator asks for... | Use this |
|---|---|
| List every CLI command | `/help` |
| Every company in the group with its country, currency, GST or BAS period and last closed month | `/entities` |
| The chart of accounts: code, name, type, tag and budget holder | `/accounts` |
| Every version: actuals, budgets, forecasts and scenarios, with months, approval and which budget and forecast are current | `/versions` |
| The profit and loss for one version, by account, for its months or one month, with net profit per entity | `/pnl` |
| Last closed month against the approved budget, every P&L line, with whether each variance is explained | `/variance` |
| Variances over both thresholds (percentage and amount, in the settings table) that nobody has explained yet | `/commentary-due` |
| Where the year lands: actuals to date plus the current forecast for the rest of the budget year, against the budget, with net profit per entity | `/outlook` |
| Two versions side by side over the months they share, by account, with the difference and net profit | `/compare` |
| Closing cash for the last three closed months and every forecast month, with the monthly change | `/cash` |
| Every bank covenant: the last test on actuals, whether it passed, and the first forecast month it breaches | `/covenants` |
| The hiring plan: every role, filled or planned, with salary, employer contribution rate, monthly cost and cost inside the current forecast | `/headcount` |
| The month-end close checklist for the latest month, overdue first | `/close` |
| GST returns (NZ) and BAS (AU) due, overdue or recently lodged, from each entity's filing frequency | `/tax-calendar` |
| Dividends proposed, declared and paid, with net assets before and the lowest forecast cash after paying | `/distributions` |
| Everything that needs a person: unexplained variances, overdue close tasks, forecast covenant breaches, cash below zero, tax returns due, a forecast not rolled, a budget not approved | `/attention` |
| Record checks against the rules in docs/compliance.md: KiwiSaver and super rates in the hiring plan, GST and BAS lodgement, solvency certificates, s254T net assets, cash after distributions, budget approval, covenant breaches | `/compliance` |
| The last 100 changes: who changed what, with the evidence they gave | `/activity` |
| The Monday finance review in one run: attention, forecast cash, covenants and tax returns due | `/weekly-review` |
| The month-end pack in one run: variances to explain, the close checklist, where the year lands, and whether the forecast has been rolled | `/month-end` |
| Add a company to the group: country, currency, GST or BAS period and its Adaptive Planning level code | `/add-entity` |
| Add an account: code, name, type, an optional tag, the budget holder and the Adaptive Planning account code | `/add-account` |
| Add a budget, forecast or scenario, optionally copied from another version, shifted by months and uplifted by a percentage | `/add-version` |
| Approve and lock a version so nobody can change it | `/lock` |
| Set one value in one version: entity, account, month, amount | `/set` |
| Roll the forecast: a new forecast version with actuals for every closed month and the old forecast for the rest | `/roll-forecast` |
| Explain a variance: a note against an entity, account and month (defaults to the last closed month) | `/comment` |
| Add a role to the hiring plan. The employer contribution rate defaults to the statutory rate for the country and start date | `/add-hire` |
| Change a role: status, person, dates, salary, contribution rate, or an IRD temporary rate reduction date | `/update-hire` |
| Add a bank covenant: minimum cash, interest cover or debt to EBITDA, with the threshold and test frequency | `/add-covenant` |
| Add a month-end close task with an owner and due date | `/task` |
| Mark a close task done, with the evidence | `/done` |
| Record a GST return or BAS as lodged | `/lodge` |
| Record or change a proposed, declared or paid dividend | `/distribution` |
| Record the date the directors signed the solvency certificate for a distribution | `/certify` |
| Bring Adaptive Planning's Export Data CSV into a version, or monthly totals from the accounting system into actuals | `/import` |
| Write every table to JSON files in exports/ | `/export` |
| Draft the monthly board pack for one entity into drafts/ | `/draft-board-pack` |
| Draft one email per budget holder asking them to explain last month's unexplained variances, into drafts/ | `/draft-variance-requests` |
| Draft the covenant compliance certificate for an entity's lender into drafts/ | `/draft-lender-certificate` |
| Board packs, covenant certificates and distribution working papers in your brand | `/docs` |
| Read-only pages: month-end, cash and covenants, the plan, record checks | `/view` |
| Add a field, rename a version kind, change a threshold or a rule in plain words: migration written, applied and tested | `/customise` |
| Add a read-only page from a description | `/new-view` |

If an ask fits nothing here, run the CLI directly (`npm run <cli> -- --help`) and then propose a new command for it.

## Hard rules

- Never send email or messages from here. Draft to `drafts/`, a person sends.
- Never delete records without an explicit yes in this session. Prefer marking closed or archived.
- Never invent a record. If a name is ambiguous, list the candidates and ask.
- The database is the source of truth. If the answer is not in it, say so.

## Finance rules

- Monday: `/weekly-review`. After each month is loaded: `/month-end`, `/draft-variance-requests`, then `/roll-forecast` once the comments are in, then `/draft-board-pack`.
- Never add amounts in different currencies. Each entity reports in its own currency until the operator sets up a conversion.
- The current budget is the newest approved budget covering the last closed month; the current forecast is the newest forecast. Say which ones an answer used.
- Amounts are stored as positive natural amounts (revenue and costs both positive). A positive variance or gap is better than budget.
- A locked version never changes. A change after approval is a new version, copied with `/add-version`.
- Covenant figures here are management numbers. The facility agreement's own definitions decide; say so whenever a figure goes to a lender.

## Where things live

- `scripts/` the CLI. `scripts/lib/db.mjs` picks `DATABASE_URL` (Postgres, Supabase) or the embedded database in `.data/`.
- `supabase/migrations/` the schema, plain SQL. `npm run migrate` applies it.
- `.claude/commands/` the slash commands. Add one every time the same ask comes twice.
- `docs/` the thesis and the guide for moving off Workday Adaptive Planning.

Built by Enterprise DNA. Installed and run for you as part of Omni: https://enterprisedna.co/omni/instead-of/adaptive-planning
