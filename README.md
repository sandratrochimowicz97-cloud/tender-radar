# Tender radar for design practices

> **Status: in progress (v1, Oct-Nov 2026).** Sections marked *pending* are filled in from real runs, never estimates.

Every morning it pulls new public architecture tenders and design competitions from the EU's TED database, keeps each one exactly once in Postgres, and asks one question per tender: *can this practice qualify, and with which of its past projects?* A partner approves what to pursue. Nothing happens without that click.

## The problem
Design practices bid on public tenders and competitions to win work. Finding the right ones is slow: notices are scattered, written in many languages, and most don't fit. The ones that do fit often ask for comparable reference projects, so the real question isn't "is this relevant?" but "do we qualify, and with what?"

## How it works
```
TED Search API (pre-filtered: architecture CPV codes, chosen countries, open deadlines)
   -> Postgres: insert once (idempotency key = source + notice ID + content hash), status = new
   -> rule step (plain code): deadline, value, procedure type -> filtered_out + reason
   -> relevance judge (model, structured JSON, validated) -> shortlisted / not_relevant
   -> explain (model, shortlist only): reasons + 2-3 closest reference projects
   -> digest -> partner approves or rejects -> Postgres records who and when
   -> MCP server (read-only): "which school competitions in Scandinavia close this month?"
```
Only 2 of the steps call a model. Everything else is deterministic code, because ten chained steps that are each 95% reliable succeed together only about 60% of the time.

## How it fails safely
| Risk | What the system does |
|---|---|
| Same notice fetched twice | Unique key on source + notice ID + content hash; the insert does nothing |
| Laptop off for days | Each run reads the last successful run from the `runs` table and fetches from there |
| Model returns invalid output | Validated against a schema; repaired up to 2 times; then the tender is marked `failed` and an alert goes out |
| Model calls cost too much | Every call is logged in `model_calls` with tokens and cost |
| Something gets acted on by mistake | Only a person can set `approved`; the system never contacts anyone |

## Measured benefit
*Pending, filled from real runs only:*
- **Time:** minutes a person spends screening a week of notices by hand vs. reviewing the radar's shortlist.
- **Accuracy:** agreement between the relevance judge and hand labels on 30 tenders.
- **Cost:** model cost per daily run, from `model_calls`.

## What broke and how I fixed it
*Pending:* taken from [docs/failure-log.md](docs/failure-log.md) once the radar runs daily.

## Run it yourself
Requirements: Docker Desktop, n8n (self-hosted), an Anthropic API key.
For permission to run this in a practice, get in touch.
```bash
cp .env.example .env          # fill in your own values; .env is never committed
docker compose up -d          # starts Postgres and creates the tables from db/schema.sql
```
*Pending:* importing the n8n workflow, and the MCP server.

## Handover
- **Change what the practice looks for:** edit [data/sample/firm_profile.md](data/sample/firm_profile.md) and [data/sample/reference_projects.csv](data/sample/reference_projects.csv). No code changes.
- **The practice owns the context** (profile, references, labels, logs). The model is swappable.
- Decisions and the reasons for them: [docs/decisions.md](docs/decisions.md).

## Data
Tender data comes from [TED](https://ted.europa.eu) (Tenders Electronic Daily), the EU's public procurement journal, through its open Search API. Under the [TED legal notice](https://ted.europa.eu/en/legal-notice), procurement notices can be freely reused. Source: TED, Publications Office of the European Union. This project is independent and not endorsed by the EU.

Notices can contain contact persons' names and emails. These stay in the local database only and are never committed or shown in examples.

The practice, its profile and its reference projects are **invented** for this demo. Any resemblance to a real firm or project is unintended.

## License
Copyright © 2026 Sandra Trochimowicz. All rights reserved. You may read the code here; using, copying, modifying or selling it needs written permission. See [LICENSE](LICENSE).
