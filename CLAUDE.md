# Working on this repo

Start every task with four lines:
1. **Done looks like:** ...
2. **Checked by:** ... (a command, a query or a test, not "looks right")
3. **Out of scope:** ...
4. **Don't touch:** ...

## Rules
- State lives in Postgres (`db/schema.sql`). Never keep state only in a workflow.
- Only two steps may call a model: relevance and the go/no-go assessment. Anything else is plain code.
- Never commit `.env`, keys, tokens, credential exports or personal data. The firm in `data/sample/` is invented; keep it that way.
- Before adding any data source, API, library or tool: check its licence and terms of use, cite the source, and record the result in `docs/decisions.md` (and the README Data section if it is a data source).
- Every real failure goes into `docs/failure-log.md`; every choice with a trade-off goes into `docs/decisions.md`.

## Corrections (grows from the failure log)
- (none yet)
