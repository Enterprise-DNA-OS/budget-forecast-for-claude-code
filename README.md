<h1 align="center">Budget and Forecast for Claude Code</h1>

<p align="center">
  <strong>The open-source budgeting and forecasting system that is just a database and Claude Code.</strong>
</p>

<p align="center">
  Created by <a href="https://www.enterprisedna.co"><strong>Enterprise DNA</strong></a>. Free and open source. Works with Claude Code, Codex, OpenCode or Cursor.
</p>

<!-- three-doors -->
<table align="center">
  <tr>
    <td align="center"><strong>Do it yourself</strong><br/>Clone it, run it, own it. Free, MIT.<br/><a href="#quick-start">Quick start</a></td>
    <td align="center"><strong>We customise it</strong><br/>Your fields, your rules, your Workday Adaptive Planning data brought across.<br/><a href="https://enterprisedna.co/omni/book/?utm_source=github&utm_medium=readme&utm_campaign=adaptive-planning">Book a call</a></td>
    <td align="center"><strong>We run it for you</strong><br/>Installed, connected and operated inside Omni. Setup fee, then a retainer.<br/><a href="https://enterprisedna.co/omni/instead-of/adaptive-planning?utm_source=github&utm_medium=readme&utm_campaign=adaptive-planning">How it works</a></td>
  </tr>
</table>

<p align="center">
  <a href="#what-is-this">What is this</a> &bull;
  <a href="#why-no-front-end">Why no front end</a> &bull;
  <a href="#quick-start">Quick start</a> &bull;
  <a href="#the-commands">Commands</a> &bull;
  <a href="#instead-of-adaptive-planning">Instead of Workday Adaptive Planning</a> &bull;
  <a href="#want-it-installed-and-run-for-you">Installed for you</a> &bull;
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Node-20+-339933?style=flat-square" alt="Node 20+" />
  <img src="https://img.shields.io/badge/PostgreSQL-any-336791?style=flat-square" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/PGlite-embedded-3ecf8e?style=flat-square" alt="PGlite" />
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="MIT License" />
</p>

---

## What is this

Budget and Forecast for Claude Code does the job you pay Workday Adaptive Planning for, as a Postgres database and a set of agent commands. There is no web front end. You open the folder in [Claude Code](https://claude.com/claude-code) (or Codex, OpenCode, Cursor: see `AGENTS.md`) and ask for what you want in plain language. It runs the right query, and it can answer questions the Workday Adaptive Planning dashboard cannot.

Workday publishes no price for Adaptive Planning; every plan is quoted. Vendr's [Workday buyer guide](https://www.vendr.com/buyer-guides/workday) puts Adaptive Planning on its own at roughly $5,900 to $25,100 a year, and as an add-on for an organisation of about 200 people at $18,000 to $31,200 (checked 10 October 2026). That is the licence, before an implementation partner builds the model, and before every budget holder who needs to type into a sheet becomes another seat.

Want the same thing with a web front end, or built on a different stack? That is a customisation, and it is exactly what Enterprise DNA does: [book a call](https://enterprisedna.co/omni/book/?utm_source=github&utm_medium=readme&utm_campaign=adaptive-planning).

It is for the finance lead, financial controller or outsourced CFO of a New Zealand or Australian business with 20 to 500 staff, often a group with an NZ company and an Australian one. It holds the chart of accounts, every entity, actuals by month, budgets, forecasts and scenarios as versions, the hiring plan, bank covenants, variance commentary, the month-end close checklist, GST and BAS lodgements, and dividends. On top sit the jobs a finance team does every month: close the month, explain the variances, roll the forecast, test the covenants, write the board pack, and check a dividend before the directors sign.

### Ten questions this answers today

1. Which lines came in well away from budget last month and still have no explanation? `/commentary-due`
2. Where will we land for the year against the board budget, line by line? `/outlook`
3. In which month does cash drop below the bank's minimum on the current forecast? `/covenants`
4. What changed between the board budget and the latest reforecast? `/compare`
5. What is our lowest cash point over the forecast, and when? `/cash`
6. Is every planned hire costed at the KiwiSaver or super guarantee rate that applies when they start? `/compliance`
7. Which GST returns or BAS are due or overdue? `/tax-calendar`
8. Can we pay the proposed dividend and still have cash for the next twelve months? `/distributions`
9. Which month-end close tasks are late, and who owns them? `/close`
10. Is the forecast still carrying forecast figures for months we have already closed? `/attention`

These are working commands on the demo data, not claims about what Workday Adaptive Planning can or cannot report.

## Why no front end

- The front end was only ever there because the database was hard to talk to. That is no longer true.
- Your data sits in plain Postgres tables you own. Any tool can read them. No export, no lock-in.
- No seats, no tiers, no add-ons. Read [docs/why-no-front-end.md](docs/why-no-front-end.md) for the honest trade-offs too.

## Quick start

Sixty seconds, no database install (an embedded Postgres runs inside Node):

```bash
git clone https://github.com/Enterprise-DNA-OS/budget-forecast-for-claude-code.git
cd budget-forecast-for-claude-code
npm install
npm run demo
```

Then open the folder in Claude Code and type `/month-end`: last month against budget, what still needs a comment, the close checklist and where the year lands. Or ask in plain words: "will we breach the bank's minimum cash this year?"

The demo is Harbourline Group, a fictional NZ wholesaler with an Australian subsidiary: eighteen months of actuals, an approved board budget, a reforecast and a downside scenario. It is deliberately untidy: two marketing overspends nobody has explained, overdue close tasks, a forecast not rolled since the last two closes, cash forecast to fall under the bank's minimum, an overdue GST return, a hire planned below the KiwiSaver minimum and one below the super guarantee, a paid dividend with no solvency certificate, and a proposed dividend the forecast cannot carry. Dates move with today.

`npm test` runs every command against a temporary database and must print PASS. `npm run view` writes the read-only pages to `views/`; `npm run docs` writes board packs, covenant certificates and distribution working papers to `docs-out/`.

### Use it with your own Postgres or Supabase

Copy `.env.example` to `.env`, set `DATABASE_URL`, then `npm run migrate`. Same commands, shared data, no per-seat fee.

## The commands

Every command runs `npm run plan -- <command>`, takes `--json`, and matches entities, accounts and versions by full name, code, part of a name or the start of an id. An ambiguous name lists the candidates and stops. Every change needs `--actor` and lands in the activity log with what it was before. A locked version cannot change at all: the database refuses.

| Command | What it does |
|---|---|
| `/help` | List every CLI command. |
| `/entities` | Every company in the group with its country, currency, GST or BAS period and last closed month. |
| `/accounts` | The chart of accounts: code, name, type, tag and budget holder. |
| `/versions` | Every version: actuals, budgets, forecasts and scenarios, with months, approval and which budget and forecast are current. |
| `/pnl` | The profit and loss for one version, by account, for its months or one month, with net profit per entity. |
| `/variance` | Last closed month against the approved budget, every P&L line, with whether each variance is explained. |
| `/commentary-due` | Variances over both thresholds (percentage and amount, in the settings table) that nobody has explained yet. |
| `/outlook` | Where the year lands: actuals to date plus the current forecast for the rest of the budget year, against the budget, with net profit per entity. |
| `/compare` | Two versions side by side over the months they share, by account, with the difference and net profit. |
| `/cash` | Closing cash for the last three closed months and every forecast month, with the monthly change. |
| `/covenants` | Every bank covenant: the last test on actuals, whether it passed, and the first forecast month it breaches. |
| `/headcount` | The hiring plan: every role, filled or planned, with salary, employer contribution rate, monthly cost and cost inside the current forecast. |
| `/close` | The month-end close checklist for the latest month, overdue first. |
| `/tax-calendar` | GST returns (NZ) and BAS (AU) due, overdue or recently lodged, from each entity's filing frequency. |
| `/distributions` | Dividends proposed, declared and paid, with net assets before and the lowest forecast cash after paying. |
| `/attention` | Everything that needs a person: unexplained variances, overdue close tasks, forecast covenant breaches, cash below zero, tax returns due, a forecast not rolled, a budget not approved. |
| `/compliance` | Record checks against the rules in docs/compliance.md: KiwiSaver and super rates in the hiring plan, GST and BAS lodgement, solvency certificates, s254T net assets, cash after distributions, budget approval, covenant breaches. |
| `/activity` | The last 100 changes: who changed what, with the evidence they gave. |
| `/weekly-review` | The Monday finance review in one run: attention, forecast cash, covenants and tax returns due. |
| `/month-end` | The month-end pack in one run: variances to explain, the close checklist, where the year lands, and whether the forecast has been rolled. |
| `/add-entity` | Add a company to the group: country, currency, GST or BAS period and its Adaptive Planning level code. |
| `/add-account` | Add an account: code, name, type, an optional tag, the budget holder and the Adaptive Planning account code. |
| `/add-version` | Add a budget, forecast or scenario, optionally copied from another version, shifted by months and uplifted by a percentage. |
| `/lock` | Approve and lock a version so nobody can change it. |
| `/set` | Set one value in one version: entity, account, month, amount. |
| `/roll-forecast` | Roll the forecast: a new forecast version with actuals for every closed month and the old forecast for the rest. |
| `/comment` | Explain a variance: a note against an entity, account and month (defaults to the last closed month). |
| `/add-hire` | Add a role to the hiring plan. The employer contribution rate defaults to the statutory rate for the country and start date. |
| `/update-hire` | Change a role: status, person, dates, salary, contribution rate, or an IRD temporary rate reduction date. |
| `/add-covenant` | Add a bank covenant: minimum cash, interest cover or debt to EBITDA, with the threshold and test frequency. |
| `/task` | Add a month-end close task with an owner and due date. |
| `/done` | Mark a close task done, with the evidence. |
| `/lodge` | Record a GST return or BAS as lodged. |
| `/distribution` | Record or change a proposed, declared or paid dividend. |
| `/certify` | Record the date the directors signed the solvency certificate for a distribution. |
| `/import` | Bring Adaptive Planning's Export Data CSV into a version, or monthly totals from the accounting system into actuals. |
| `/export` | Write every table to JSON files in exports/. |
| `/draft-board-pack` | Draft the monthly board pack for one entity into drafts/. |
| `/draft-variance-requests` | Draft one email per budget holder asking them to explain last month's unexplained variances, into drafts/. |
| `/draft-lender-certificate` | Draft the covenant compliance certificate for an entity's lender into drafts/. |
| `/docs` | Board packs, covenant certificates and distribution working papers in your brand. |
| `/view` | Read-only pages: month-end, cash and covenants, the plan, record checks. |
| `/customise` | Add a field, rename a version kind, change a threshold or a rule in plain words: migration written, applied and tested. |
| `/new-view` | Add a read-only page from a description. |

### Your first hour: ten things to ask for

1. "Put our company name and logo on the board pack." (brand.json)
2. "Do a test import of our Adaptive Planning export into a new version called FY27 Budget, without saving it."
3. "Our Adaptive levels are called NZ Ops and AU Ops. Map them to our two companies."
4. "Load last month's actuals from this Xero export."
5. "Which variances still need a comment, and who owns them?"
6. "Roll the forecast now that September is closed."
7. "Add a covenant: Kauri Bank, interest cover of at least 3 times, tested quarterly." (/add-covenant)
8. "Add a department to every account and show the P&L by department." (/customise)
9. "Can we pay a $200,000 dividend in December?"
10. "Write the board pack for the NZ company and save it to drafts."

## Instead of Workday Adaptive Planning

Adaptive Planning's Integration > Export Data writes the account values for one version to a CSV: one row per account and level, one column per month. Export each version you want to keep (the approved budget, the current forecast) and bring them across:

```bash
npm run plan -- add-version --name="FY27 Budget" --kind=budget --starts=2026-04 --actor="Your name"
npm run plan -- import adaptive --version="FY27 Budget" --file=imports/budget.csv --map=imports/map.json --actor="Your name" --dry-run
npm run plan -- import adaptive --version="FY27 Budget" --file=imports/budget.csv --map=imports/map.json --actor="Your name"
npm run plan -- lock --version="FY27 Budget" --approved-by="Board of directors" --evidence="Board minutes" --actor="Your name"
```

Levels and accounts that do not match by code or name go in a small map file; the import lists every one that does not match and saves nothing until they all do. Rollup columns (quarters, totals) are skipped. The whole file is checked before anything is saved. Running the same file twice changes nothing; a changed value needs `--update`. Formulas, drivers, sheets, workflow and user permissions do not come across in a value export: [what maps and what does not](docs/replace-adaptive-planning.md).

Monthly actuals come from the accounting system as Entity, Account Code, Month, Amount: `npm run plan -- import ledger --file=imports/actuals.csv --actor="Your name"`.

## Compliance, documents and views

`/compliance` checks the records against the rules an NZ or AU finance team works under: the KiwiSaver employer minimum (3.5% from 1 April 2026, 4% from 1 April 2028) and the super guarantee (12% from 1 July 2025) in the hiring plan, GST and BAS due dates, the directors' solvency certificate for an NZ distribution (Companies Act 1993 s52), the net assets test for an Australian dividend (Corporations Act 2001 s254T), forecast cash after a distribution, an approved budget, and covenant breaches on actuals. Each rule and its source: [docs/compliance.md](docs/compliance.md). It is a record check, not legal or tax advice.

Verification: CI runs `npm test` on Node 20 and 22 on Linux and Windows, plus a job against PostgreSQL 17. `TEST_DATABASE_URL` must name an empty, disposable database. [Why this target was chosen](docs/research.md).

## Architecture

```
budget-forecast-for-claude-code/
  CLAUDE.md                 how the operator wants this run (routing table + house rules)
  AGENTS.md                 the same, for Codex / OpenCode / Cursor / Gemini CLI
  .claude/commands/         the slash commands
  scripts/                  the CLI the commands drive
  scripts/lib/db.mjs        one adapter: DATABASE_URL (pg) or embedded PGlite
  supabase/migrations/      plain SQL schema
  supabase/seed.sql         demo data
  docs/                     the thesis and the migration guide
```

## Built for coding agents

The database, CLI and command recipes work with Claude Code, Codex, OpenCode or Cursor. Ask your coding agent for a new command and have it implement and test the change against the same records.

## Contributing

Issues and pull requests are welcome. Keep the shape: plain SQL, a small CLI, a slash command per recurring job, no front end.

## Want it installed and run for you?

Enterprise DNA installs Budget and Forecast for Claude Code for your business, migrates your Workday Adaptive Planning data, connects it to the rest of your tools, and runs it for you as part of **Omni**, our managed Command Center. One setup fee, then a monthly retainer.

- Book a call: [enterprisedna.co/omni/book](https://enterprisedna.co/omni/book/?offer=replace-software&utm_source=github&utm_medium=readme&utm_campaign=adaptive-planning)
- Read more: [enterprisedna.co/omni/instead-of/adaptive-planning](https://enterprisedna.co/omni/instead-of/adaptive-planning?utm_source=github&utm_medium=readme&utm_campaign=adaptive-planning)

## License

MIT. Copyright (c) 2026 Enterprise DNA.
