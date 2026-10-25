# Working on this repo

Start every task with four lines:
1. **Done looks like:** ...
2. **Checked by:** ... (a command, a query or a test, not "looks right")
3. **Out of scope:** ...
4. **Don't touch:** ...

## Rules
- State lives in Postgres (`db/schema.sql`). Never keep state only in a workflow.
- Only two steps may call a model: relevance and explanation. Anything else is plain code.
- Never commit `.env`, keys, tokens, credential exports or personal data. The firm in `data/sample/` is invented; keep it that way.
- Every real failure goes into `docs/failure-log.md`; every choice with a trade-off goes into `docs/decisions.md`.

## Corrections (grows from the failure log)
- (none yet)
