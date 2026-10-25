# Decisions

Newest first. Each entry: what was decided, why, and what was rejected.

| Date | Decision | Why | Rejected |
|---|---|---|---|
| 2026-10-25 | Viewing-only licence (all rights reserved) instead of MIT | The code is a demo of a service; others should not reuse or sell it without permission | MIT (allows commercial reuse) |
| 2026-10-25 | Contact persons in TED notices stay local, never committed | Notices can hold personal data; a public repo must not republish it | Committing raw sample notices |
| 2026-10-25 | State lives in Postgres, not in n8n | Idempotency, catch-up after downtime and an audit trail need a real database; the workflow stays simple and replaceable | Keeping state in n8n static data or a spreadsheet |
| 2026-10-25 | Pre-filter in the TED query (CPV codes, countries, deadline) before any model call | Free and deterministic; fewer model calls means lower cost and fewer failure points | Sending every notice to a model |
| 2026-10-25 | Only 2 model steps (relevance, explanation) | Chained probabilistic steps multiply failure; everything predictable is plain code | An agent deciding each step |
| 2026-10-25 | Relevance judge v1 = small Claude model; a cheaper judge is tested later on the same labelled set | Choose by measured agreement and cost per run, not by price per token | Picking the cheapest model untested |
| 2026-10-25 | Synthetic practice, public tender data | No client or employer data in a public repo | Real firm data |
