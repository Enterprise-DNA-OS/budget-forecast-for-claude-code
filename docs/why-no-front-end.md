# Why there is no front end

Workday Adaptive Planning is a database of numbers with a subscription. Underneath the sheets and dashboards sit ordinary tables: entities, accounts, versions, and a value for each account in each month. What you pay for is the layer on top that lets people who do not write queries get at those tables: grids, reports, dashboards, workflow.

That layer used to be the whole product, because talking to a database was hard. It is not hard any more. Open this folder in Claude Code, ask "where will we land against budget, and what is driving the gap?", and it runs the query and explains the answer. Ask a question no report was built for ("which months did marketing run over by more than 20%, and did anyone explain them?") and you still get an answer.

## What you gain

- **Better answers.** A report shows what someone set up last year. Here you ask your own question against your own numbers.
- **No planner seats.** Everyone who needs to look can look. The bill does not grow when another budget holder joins.
- **Your numbers in your Postgres.** Plain tables. Back them up, point Power BI or Excel at them, leave any time. There is no export step because there is nothing to leave.
- **A month-end that matches yours.** When your routine changes, you add a command. You do not wait for a model rebuild.

## What you give up

- **A grid budget holders type into.** Here, budget holders send their numbers or their comments and the finance lead records them, or Claude Code imports their spreadsheet. A shared entry screen is something Enterprise DNA builds into a custom version.
- **Driver-based models out of the box.** Values are stored, not formulas. A driver you rely on becomes a plain-language rule in a command.
- **Consolidation in one currency.** Each entity stays in its own currency until a conversion is set up.
- **A phone app and a vendor help desk.** It runs where Claude Code runs. Enterprise DNA supports the installed version for businesses that want someone to call.

## Who this fits

A finance lead, controller or outsourced CFO who already lives in spreadsheets and would rather ask than click. If dozens of budget holders need to type into the same model at once, keep the grid or have Enterprise DNA build one on top of this database. If you need the answers more than the screens, this is cheaper, faster and yours.

Installed and run for you: https://enterprisedna.co/omni/instead-of/adaptive-planning
