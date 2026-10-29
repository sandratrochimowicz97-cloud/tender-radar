# Tender go/no-go assistant for design practices

> **Status: in progress (v1, Oct-Nov 2026).** Sections marked *pending* are filled in from real runs, never estimates.

An in-house assistant that screens public architecture tenders the way a practice's own partner would, and learns that judgment over time.

Every morning it pulls new tenders and design competitions from the EU's TED database, keeps each one exactly once in Postgres, and answers one question per tender: *can this practice qualify, and with which of its own past projects?* It recommends **go**, **conditional go** or **no-go**, with every claim backed by a quote from the notice. A partner decides, and gives a reason. Nothing happens without that decision.

## The problem
Design practices bid on public tenders and competitions to win work. Finding the right ones is slow: notices are scattered, written in many languages, and most don't fit. The ones that do fit often ask for comparable reference projects, so the real question isn't "is this relevant?" but "do we qualify, and with what?"

## What it does differently
Commercial tender platforms already find tenders and summarise them well (see [docs/decisions.md](docs/decisions.md) for what was studied). This project focuses on three things they don't advertise:

1. **It checks the practice's own references.** It doesn't stop at "the tender requires 3 school references". It answers "you qualify with projects 01 and 05; you're missing a third school over 5,000 m²".
2. **It learns from the partner's decisions.** Every go/no-go is stored with its reason. Agreement between recommendation and decision is measured each week, and reasons that repeat become rules.
3. **It runs in the practice's own setup.** References, decisions and logs stay in the practice's own database, and the model can be swapped.

## How it works
```
TED Search API (architecture and landscape CPV codes, published since the last successful run)
   -> fetch step (plain code): keep the practice's countries, calls for tenders and design contests only
   -> Postgres: insert once (idempotency key = source + notice ID + content hash), status = new
   -> rule step (plain code): deadline, value, procedure type -> filtered_out + reason
   -> relevance judge (model, structured JSON, validated) -> shortlisted / not_relevant
   -> go/no-go assessment (model, shortlist only): requirements with source quotes,
      reference fit against the practice's own projects, recommendation, max 3 open questions
   -> digest -> partner decides go / no-go + reason -> decisions table
   -> weekly: agreement between recommendations and decisions; repeated reasons -> new rules
   -> MCP server (read-only): "which school competitions in Scandinavia close this month?"
```
Only 2 of the steps call a model (relevance, assessment). Everything else is deterministic code, because ten chained steps that are each 95% reliable succeed together only about 60% of the time.

## How it fails safely
| Risk | What the system does |
|---|---|
| Same notice fetched twice | Unique key on source + notice ID + content hash; the insert does nothing |
| Machine off for days | Each run reads the last successful run from the `runs` table and fetches from there |
| Model returns invalid output | Validated against a schema; repaired up to 2 times; then the tender is marked `failed` and an alert goes out |
| Model calls cost too much | Every call is logged in `model_calls` with tokens and cost |
| Something gets acted on by mistake | Only a person can record a decision; the system never contacts anyone |
| Model invents a requirement | Every extracted requirement must carry a quote from the notice; no quote, no claim |

## Measured benefit
*Pending, filled from real runs only:*
- **Time:** minutes a person spends screening a week of notices by hand vs. reviewing the assistant's shortlist.
- **Accuracy:** agreement between the recommendation and a partner's go/no-go on 30 tenders.
- **Cost:** model cost per daily run, from `model_calls`.

## Run it yourself
Requirements: Docker Desktop and an Anthropic API key.
For permission to run this in a practice, get in touch.
```bash
cp .env.example .env          # fill in your own values; .env is never committed
```
Then pick how to run n8n. The workflow is the same in both.

**Option A: everything in Docker (recommended)**
```bash
docker compose up -d          # starts Postgres (creates the tables from db/schema.sql) and n8n
```
n8n runs at http://localhost:5679, on its own port so it never clashes with another n8n. This is the same setup on every machine, and it matches where n8n is heading (version 3.0 is Docker-only).

**Option B: an n8n you already self-host**
```bash
docker compose up -d db       # starts only Postgres
```
In your n8n, add a Postgres credential: host `localhost`, port `5432`, and the database, user and password from your `.env`. Then import the workflow.

Postgres and n8n are reachable only from the same machine.

*n8n Cloud is not supported in v1: the database stays on the practice's own machine, and a cloud n8n can't reach it without exposing it to the internet.*

*Pending:* importing the n8n workflow, and the MCP server.

**Troubleshooting**

| Symptom | Fix |
|---|---|
| n8n can't connect to Postgres: "Connection refused" | Use host `127.0.0.1` instead of `localhost`. On Windows, `localhost` can resolve to IPv6, while the database listens on IPv4 only. |

Incident history: [docs/failure-log.md](docs/failure-log.md).

## Security and data
Built to run on a practice's own machine with real data.
- **Data never leaves the practice's machine except in the 2 judgment AI steps inside the n8n workflow** (relevance and go/no-go). Everything else is plain code.
- **Those 2 steps use the practice's own Anthropic API key.** Under Anthropic's commercial terms, API data is not used for model training and is kept for 30 days by default ([data usage](https://code.claude.com/docs/en/data-usage), [retention](https://platform.claude.com/docs/en/manage-claude/api-and-data-retention)).
- **Postgres and n8n listen on localhost only.** Nothing is reachable from the network.
- **Secrets stay in `.env`,** which is never committed (see `.gitignore`).
- **AI coding assistants can't read secrets.** [.claude/settings.json](.claude/settings.json) denies reading `.env`, `.mcp.json`, key files and n8n's own folder, asks before commands that delete data, and turns off the mode that skips permission prompts. A hook ([protect-secrets.js](.claude/hooks/protect-secrets.js)) blocks any command or search that names a secrets file. Per the [Claude Code docs](https://code.claude.com/docs/en/permissions), these rules cover Claude's own tools, not every program, so the same file also turns on Claude Code's [sandbox](https://code.claude.com/docs/en/sandboxing) for OS-level isolation. The sandbox runs on macOS, Linux and WSL2; on native Windows, run Claude Code inside WSL2 to get it.
- **n8n workflows can't read environment variables** (`N8N_BLOCK_ENV_ACCESS_IN_NODE=true` in the Docker setup), and n8n stores credentials encrypted.
- **Personal data in TED notices** (contact persons) stays in the local database and is never committed.
- **With client data,** a data processing agreement names Anthropic as sub-processor.

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
