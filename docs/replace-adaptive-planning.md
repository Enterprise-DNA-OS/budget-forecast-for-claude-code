# Moving off Workday Adaptive Planning

Adaptive Planning keeps your numbers in versions (actuals, the budget, each reforecast), on accounts, by level (the entities and departments in your organisation structure). That maps straight onto this system: a version here is a version there, an account is an account, a level is an entity.

## 1. Export each version you want to keep

In Adaptive Planning, Integration > Export Data exports the account values from the version you have selected to a CSV file ([Workday documentation: Export Data](https://doc.workday.com/adaptive-planning/en-us/workday-adaptive-planning-documentation/integration/managing-data-integration/import-and-export-data/tfe1623709269415.html)). Set it up like this:

- **Format:** Adaptive Account Names and Codes.
- **Filter:** the accounts and levels you want, and the months. With no filter, everything exports.
- **Rules:** leave Include Rollup Accounts, Include Rollup Levels and Include Time Rollups off. The import skips rollup columns it recognises (quarters, totals), but rollup rows would double count.
- **Currency:** each level's own currency (the default). This system never adds two currencies together.

Export the approved budget and the latest forecast at least. Actuals can come from Adaptive too, but most teams load them straight from the accounting system each month (step 4).

The file has one row per account and level and one column per month. The import reads month headers written as `Apr-2026`, `Apr 2026`, `04/2026` or `2026-04`. If your export's headers or column names differ, name them in the map file.

## 2. Set up entities and accounts once

```bash
npm run plan -- add-entity --name="Your Company Ltd" --country=NZ --gst-period=two-monthly --adaptive-level="NZ Ops" --actor="Your name"
npm run plan -- add-account --code=4000 --name="Sales revenue" --type=revenue --adaptive-code=4000 --actor="Your name"
```

Or ask Claude Code to read the export and create every entity and account it finds. Tag the accounts the maths needs: `cash` and `debt` for covenants, `interest`, `depreciation` and `tax` for EBITDA, `wages` for people costs.

## 3. Import a version

```bash
npm run plan -- add-version --name="FY27 Budget" --kind=budget --starts=2026-04 --actor="Your name"
npm run plan -- import adaptive --version="FY27 Budget" --file=imports/budget.csv --map=imports/map.json --actor="Your name" --dry-run
npm run plan -- import adaptive --version="FY27 Budget" --file=imports/budget.csv --map=imports/map.json --actor="Your name"
npm run plan -- lock --version="FY27 Budget" --approved-by="Board of directors" --evidence="Board minutes" --actor="Your name"
```

Accounts match on the Adaptive code you recorded, then on the account code, then on the name. Levels match on the Adaptive level, then on the entity name. Anything that does not match goes in the map file:

```json
{
  "levels": { "NZ Ops": "Your Company Ltd" },
  "accounts": { "6450": "5000", "Freight outwards": "5000" },
  "columns": { "Account Code": "Code", "Level Name": "Level" }
}
```

The import lists every account and level it cannot match and saves nothing until they all do. The whole file is checked before anything is saved. Running the same file twice changes nothing. A value that differs from what is already on file stops the import until you re-run with `--update`. Amounts in brackets are negative. Every value keeps its source row and column, and every import is logged with the file's fingerprint.

## 4. Actuals each month

Load monthly totals from Xero, MYOB or any ledger as a CSV with Entity, Account Code, Month and Amount:

```bash
npm run plan -- import ledger --file=imports/september.csv --actor="Your name"
```

Then `/month-end`, `/draft-variance-requests`, `/roll-forecast` and `/draft-board-pack`.

## What maps

| Adaptive Planning | Here |
|---|---|
| Version (actuals, plan, forecast, what-if) | `versions` with kind actuals, budget, forecast or scenario |
| Account (GL, standard) | `accounts`, matched on `adaptive_code` |
| Level | `entities`, matched on `adaptive_level` |
| Monthly values | `lines`, one per version, entity, account and month |
| Locked version | `lock`: the database refuses any change |

## What does not carry over

- **Formulas, assumptions and drivers.** Export Data writes values, not the logic behind them. Rebuild the drivers that matter as plain rules, or ask Claude Code to write a forecast method in a new command.
- **Modeled sheets and cube sheets.** Headcount and capital models export differently. The hiring plan here starts fresh with `/add-hire`; Enterprise DNA can bring a modeled sheet across as part of a customisation.
- **Departments and other dimensions under an entity.** Levels below the entity level need a department field (`/customise`) or a map that rolls them up.
- **Splits.** Adaptive adds split values together on export, so the detail behind a split arrives as one number.
- **Workflow, submissions, permissions and the Office add-in.** Budget holders here send their numbers or their comments; the finance lead records them. That is the trade, said plainly in [why-no-front-end.md](why-no-front-end.md).
- **Exchange rates and consolidation.** Each entity stays in its own currency. Group consolidation in one currency is a customisation.
