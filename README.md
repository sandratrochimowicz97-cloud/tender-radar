# Tender go/no-go assistant for design practices

> **Version 1 (November 2026).** Numbers come from real runs, never estimates.

An in-house assistant that screens public architecture tenders the way a practice's own partner would, and keeps the partner's decisions next to its own recommendations, so its rules can be improved from real disagreements.

Every morning it pulls new tenders and design competitions from the EU's TED database, keeps each one exactly once in Postgres, and answers one question per tender: *can this practice qualify, and with which of its own past projects?* It recommends **go**, **conditional go**, **unresolved** or **no-go** (in the Excel file: GO, CONDITIONAL, CHECK YOURSELF, NO-GO), with every claim backed by a quote from the notice. A partner decides, and gives a reason. Nothing happens without that decision.

## The problem
Design practices bid on public tenders and competitions to win work. Finding the right ones is slow: notices are scattered, written in many languages, and most don't fit. The ones that do fit often ask for comparable reference projects, so the real question isn't "is this relevant?" but "do we qualify, and with what?"

## What it focuses on
Finding tenders is the easy part. The hard part is deciding which ones are worth the bid. This project focuses on two things:

1. **It keeps the practice's own track record.** Every go/no-go is stored with its reason and, later, the outcome (won, lost, not submitted). The recommendation at the time is stored next to the decision, so agreement can be counted, and a reason that keeps repeating points to a rule the system is missing.
2. **It runs in the practice's own setup.** References, decisions and logs stay in the practice's own database, under the practice's own API key, and the Claude model is set in one place.

**How the check works:** the model only extracts each requirement from the notice, with a quote. Plain code then compares the requirements with the practice's own reference projects and facts, and decides: *go*, *conditional go*, *unresolved* or *no-go*. For example: "Needs 3 school references, practice has 1 (R01)" gives *conditional go*: the practice could bid with a partner. A requirement that isn't stated in the notice is never guessed: it simply isn't checked. If nothing in the notice can be compared, or the building type is unclear or outside the practice's usual ones, the result is *unresolved*. Building types the practice never pursues (here healthcare and infrastructure) are *no-go*. Other qualifications, such as a chamber registration or a certificate, are not compared: they are listed under *Also required* for the person to check.

## How it works
```
TED Search API (architecture and landscape CPV codes, published since the last successful run)
   -> fetch step (plain code): keep the practice's countries, calls for tenders and design contests only
   -> Postgres: insert once (idempotency key = source + notice ID + content hash), status = new
   -> requirement extraction (model, fixed JSON schema): turnover, insurance, staff, references, price weight,
      each with a quote from the notice; a value whose quote is not in the notice is dropped
   -> fit check (plain code): requirements vs the practice's own reference projects and facts
      -> go / conditional go / unresolved / no-go, why, and what else the notice requires
   -> daily Excel file -> partner decides go / no-go + reason -> decisions table
   -> after the award: outcome (won / lost / not submitted) -> decisions table
   -> MCP server (read-only, public tender facts only): "which GO tenders close this week?"
```
Only 1 step calls a model (requirement extraction). Everything else is deterministic code, because ten chained steps that are each 95% reliable succeed together only about 60% of the time (0.95¹⁰ ≈ 0.60). The practice's references and facts never go to the model; the comparison runs in code.

## How it fails safely
| Risk | What the system does |
|---|---|
| Same notice fetched twice | Unique key on source + notice ID + content hash; the insert does nothing |
| Machine off for days | Each run reads the last successful run from the `runs` table and fetches from there |
| Model call fails or stops early | Tried up to 3 times. If the problem is the notice itself (the API rejects it, or the answer is cut off or not valid JSON), the tender is marked `failed`, shown as *Assessment failed* in the Excel file, and not retried automatically, so a broken notice can't cost money every day. If the API can't be used at all (wrong key, no credit, outage), nothing is saved and the next run tries again; if no call got through, the run stops with an error |
| Model calls cost too much | At most 300 tenders are assessed per run; every call is logged in `model_calls` with tokens and cost |
| Something gets acted on by mistake | Only a person can record a decision; the system never contacts anyone |
| Model puts a minimum in the wrong field | Any open requirement that names a money amount blocks GO, so it is never marked GO unchecked |
| Model invents a requirement | Every extracted requirement must carry a quote, and code checks that the quote is in the notice text; if not, the requirement is dropped and logged. A dropped minimum or reference requirement still blocks GO, in case the model only reworded it |
| Requirement not stated in the notice | Not checked, never guessed. If nothing can be compared (for example, the requirements are only in the tender documents), the result is *unresolved* (*check yourself*) |

## Measured benefit
From the first real runs (3 fetch runs, early November 2026). Counts, not estimates.

| What | Result |
|---|---|
| Notices fetched from TED | 2,287 |
| Architecture tenders kept (plain-code filter, no model) | 186 (8%) |
| Assessed by the model step | 180, plus 1 that failed |
| Verdicts | 24 GO or CONDITIONAL, 82 NO-GO, 74 CHECK YOURSELF |
| Cost of assessing one tender once | $0.0013 (average over successful calls) |
| Total model cost, including repeat assessments while the rules were tuned | $1.05 for 784 calls, about $0.006 per tender kept |
| Failed model calls | 1 (marked *failed*, shown in the Excel file, not retried) |
| Requirements dropped because their quote was not in the notice | 7, in 7 tenders |

**In practice:** of 2,287 notices, 24 are worth a close read and 74 need a quick look at the notice. The 82 NO-GO tenders are ruled out with a stated reason.

**Not measured:** agreement between the verdicts and a practice's own go/no-go decisions. The practice in this repo is invented, so its decisions would prove nothing. A practice using it records its decisions in the Excel file, and agreement can then be counted from the `decisions` table.

## Run it yourself
Requirements: [Docker Desktop](https://www.docker.com/products/docker-desktop/), an Anthropic API key ([console.anthropic.com](https://console.anthropic.com)), and [Node.js](https://nodejs.org) 20 or newer (for option B and the MCP server).
The licence allows reading the code; running it in a practice needs written permission (see [License](#license)). To ask, open an issue on this repository.

Copy `.env.example` to `.env` and set at least `POSTGRES_PASSWORD` before the first start: the database takes its user and password from `.env` only when it is created.
```bash
cp .env.example .env          # Windows: copy .env.example .env
```
Commands below are for bash (macOS, Linux, Git Bash). Where Windows PowerShell needs a different form, it is given too.
Then pick how to run n8n. The workflow is the same in both.

**Option A: everything in Docker (recommended)**
```bash
docker compose up -d          # starts Postgres (creates the tables from db/schema.sql) and n8n
```
n8n runs at http://localhost:5679, on its own port so it never clashes with another n8n. On the first visit it asks you to create an owner account; it stays on this machine. In this n8n, open *Credentials*, create a new *Postgres* credential and name it `tender-radar Postgres`: host `db` (the database's name inside Docker), port `5432`, and the database, user and password from your `.env`.

**Option B: n8n installed on the machine (Postgres still in Docker)**
```bash
docker compose up -d db       # starts only Postgres
```
Requires Node.js and n8n 2.x: `npm install -g n8n@2.45.6`, the same version the Docker setup uses. On Windows, double-click `start-n8n.bat`. It starts a separate n8n for this project at http://localhost:5680 (first visit: create an owner account), with its own data folder (`n8n-data`) and file access limited to the `output` folder. Any other n8n on the same machine is not affected. In this n8n, create the same *Postgres* credential, `tender-radar Postgres`, with host `127.0.0.1`, port `5432`, and the database, user and password from your `.env`.

*n8n Cloud is not supported in v1: the database stays on the practice's own machine, and a cloud n8n can't reach it without exposing it to the internet.*

**Import the workflows:** in n8n, create a workflow, open the **⋯** menu, choose **Import from File** and pick the file. In each Postgres step, select your Postgres credential. Then switch the workflow on (*Publish* or *Active*, depending on the n8n version), or its schedule never runs.
1. `n8n/fetch-ted-notices.json` fetches new notices every morning at 07:00 and catches up on missed days.
2. `n8n/assess-tenders.json` assesses new tenders at 07:05. It needs a second credential of the type **Header Auth** (it sends a key with every request), named `Anthropic API key`, with name `x-api-key` and your Anthropic API key as the value; select it in the step *Claude: extract requirements with quotes*. The model is set in its first step, *Settings*.
3. `n8n/daily-tender-list.json` updates the Excel file every morning at 07:30. With option B, open its first step, *Settings: Excel file path*, and in its code replace `/data/output/Tenders.xlsx` with the full path of the file, using forward slashes, for example `D:/projects/tender-radar/output/Tenders.xlsx`. Option A needs no change.

**First run:** run the three workflows once by hand, in this order, and check that `output/Tenders.xlsx` appears. After that they run by themselves each morning while n8n is running, and catch up after days off.

**The database** gets its tables (`db/schema.sql`) and the demo practice's references and facts (`db/seed.sql`) automatically the first time Postgres starts. A database created earlier needs each file in `db/migrations/` that is newer than the database run once, oldest first (`2026-11-02.sql`, then `2026-11-05.sql`), and then the seed file. All are safe to repeat. `2026-11-05.sql` sets tenders with a status from the first design (such as *not_relevant*) back to new, so open ones among them are assessed on the next run. With the user and database from `.env` (`radar` and `tender_radar` by default):
```bash
docker compose exec -T db psql -U radar -d tender_radar < db/migrations/2026-11-02.sql
docker compose exec -T db psql -U radar -d tender_radar < db/migrations/2026-11-05.sql
docker compose exec -T db psql -U radar -d tender_radar < db/seed.sql
```
```powershell
Get-Content db\migrations\2026-11-02.sql | docker compose exec -T db psql -U radar -d tender_radar
Get-Content db\migrations\2026-11-05.sql | docker compose exec -T db psql -U radar -d tender_radar
Get-Content db\seed.sql | docker compose exec -T db psql -U radar -d tender_radar
```

To ask Claude about tenders in chat, see [Ask Claude about tenders](#ask-claude-about-tenders-mcp).

**Troubleshooting**

| Symptom | Fix |
|---|---|
| n8n can't connect to Postgres: "Connection refused" | Option A: use host `db`. Option B: use host `127.0.0.1` instead of `localhost`. On Windows, `localhost` can resolve to IPv6, while the database listens on IPv4 only. |
| Changed `POSTGRES_PASSWORD` in `.env` after the first start, and n8n or the MCP server can't log in | The database kept the old password. Use the old one, or change it in the database: `docker compose exec db psql -U radar -d tender_radar -c "ALTER ROLE radar PASSWORD '<new>'"` |
| Excel workflow stops at *Read Excel file* or *Save Excel file* | Close `Tenders.xlsx` in Excel and run the workflow again. Decisions already in the file are kept. |
| `docker compose up` fails: "port is already allocated" on 5432 | Another Postgres uses that port. Set another port in `.env`, e.g. `POSTGRES_PORT=5433`, and use it in the n8n credential (option B) and for the MCP server |
| `docker compose` fails: "cannot connect to the Docker daemon" or "pipe/docker_engine" | Docker Desktop is not running. Start it, wait until it says it is running, then run the command again |
| Assess workflow stops: "Anthropic API not reachable" | Check the *Anthropic API key* credential in n8n and the credit on the Anthropic account. Nothing was saved or charged; run it again |
| Excel workflow stops: "Some rows in the Excel file could not be saved" | Fix the rows it names (Decision: *go* or *no-go*; Outcome: *won*, *lost* or *not submitted*), save, close the file and run again |
| Tenders stay *Assessment failed* after the cause is fixed | Failed tenders are not retried automatically. To try them again (paid, about $0.0013 each): `docker compose exec db psql -U radar -d tender_radar -c "UPDATE tenders SET status='new', status_reason=NULL, recommendation=NULL WHERE status='failed'"`, then run *assess-tenders* |
| `start-n8n.bat`: "Task Broker's port 5679 is already in use" | Another n8n is running. The file sets its own helper port (`N8N_RUNNERS_BROKER_PORT=5681`); change it if 5681 is taken too. |

Incident history: [docs/failure-log.md](docs/failure-log.md).

## The daily Excel file
One file, `output/Tenders.xlsx`, updated in place every morning.

**How it is used:** the person who handles bids opens it in the morning, reads the rows marked *GO* or *CONDITIONAL* and their short *Why*, and opens the notice only for those. Nobody reads every tender.
- **One row per open tender.** Tenders due today or earlier drop out.
- **Columns:** Verdict, Why (what decides the verdict; "Price is 30% of the score" means price counts for 30% when the buyer picks the winner), Also required (other qualifications the notice asks for, summarised in English by the model from quoted notice text; standard paperwork left out), First step (request to participate or submit tender), Deadline, Days left, Added on, Title, Buyer, Country, Type, Link, then the partner's columns and Notice ID (the key that links a row to the database; don't edit it).
- **Second sheet, Reference projects:** the practice's own projects, so an ID such as R01 in the Why can be looked up.
- **Decision** (type *go* or *no-go*) **and Reason** are filled in only for tenders the practice actually considered, usually a few a week. Blank means not considered. Clearing a cell does not delete a decision already saved; to change one, type the new one. The reason records what the system can't know, such as capacity, the client relationship or the fee. **Outcome** (won / lost / not submitted) follows after the award; it matters mostly for *go* tenders, which stay in the file after they close.
- **The next run saves these to the database** before it rebuilds the file, so nothing typed in those three columns is lost (other cells and added columns are rebuilt from the database). If a row can't be saved (a Decision or Outcome it doesn't recognise, or a Reason without a Decision), the run stops and names the rows, and the file is left as it is until they are fixed. Tenders marked *go* stay in the file after they close, so the outcome can be filled in.
- **Why record decisions:** where the partner disagrees with the verdict, the reason shows a rule the system is missing.

*The file is a local Excel file, so it can't be updated while it is open in Excel: the run stops before writing it, and the next run catches up. A practice on Microsoft 365 can use an Excel file in OneDrive or SharePoint instead, which several people can keep open while it updates.*

## Ask Claude about tenders (MCP)
A small read-only [MCP](https://modelcontextprotocol.io) server ([mcp/server.mjs](mcp/server.mjs)) lets Claude, or any MCP client, answer questions such as *"which GO tenders close this week?"* or *"any school projects in Denmark?"*.

**What it can see:** only the view `public_tenders`: open tenders with title, buyer, country, deadline, link, verdict and *Also required*. Title, buyer, country, deadline and link come straight from the public notice; *Also required* is the model's English summary of quoted notice text; the verdict is the only part that reflects the practice.
**What it can't see:** the *Why* text, the reference projects, the practice's facts, the extracted requirements and the partner's decisions.

| Layer | What it does |
|---|---|
| Database login `mcp_reader` | Can read the view `public_tenders` and nothing else. Postgres refuses every other table, even if the server code had a bug ([db/mcp-reader.sql](db/mcp-reader.sql)) |
| No writes | The login has no write rights and no temporary tables; sessions also start read-only, with a 5-second limit per query |
| Fixed queries | Three tools (`list_tenders`, `search_tenders`, `get_tender`) with checked inputs and parameterised SQL. Claude never writes SQL |
| Untrusted text | Results are labelled as text copied from public notices, to be treated as data, not instructions |

**Limits, stated plainly:**
- A verdict can hint at a practice fact. A NO-GO on a tender that asks for €5m turnover implies the practice has less.
- A notice could contain text written to steer an AI. The server can only read, but if the same Claude also has tools that send email or change files, approve each of their actions yourself.
- The reader's password sits in `.env`, like every other secret here.

**Set it up:**
1. In `.env`, set `MCP_READER_PASSWORD` to a long random password.
2. Create the view and the login with that password (safe to repeat). The PowerShell version reads the password from `.env` itself:
   ```bash
   docker compose exec -T db psql -U radar -d tender_radar -v pw="<the password>" < db/mcp-reader.sql
   ```
   ```powershell
   $pw = ((Select-String -Path .env -Pattern '^MCP_READER_PASSWORD=' | Select-Object -Last 1).Line -split '=',2)[1]; Get-Content db\mcp-reader.sql | docker compose exec -T db psql -U radar -d tender_radar -v pw="$pw"
   ```
3. Install the server's libraries: in the `mcp` folder, run `npm install`. Then, from the repo root, check it with `node mcp/smoke-test.mjs`: it lists the three tools and a tender count for each.
4. Connect an MCP client. Either:
   - **Claude Code**, from the repo folder (connects it for this folder only):
     ```bash
     claude mcp add tender-radar -- node "<full path to the repo>/mcp/server.mjs"
     ```
   - **Claude Desktop**: quit the app, then open `claude_desktop_config.json` (on Windows in `%APPDATA%\Claude`, on macOS in `~/Library/Application Support/Claude`). Add the line below inside the file's outer `{ }`, keeping everything already in it (if it already has an `mcpServers` section, add only the `"tender-radar": {...}` part inside that). If something already comes before the new text, put a comma after it, so the entries are separated by commas. Start the app again.
     ```json
     "mcpServers": { "tender-radar": { "command": "node", "args": ["<full path to the repo>/mcp/server.mjs"] } }
     ```
   Use forward slashes in the path, also on Windows. The client config holds no password: the server reads it from `.env`.

## Security and data
Built to run on a practice's own machine with real data.
- **Data leaves the practice's machine in two places only:** the AI step (requirement extraction), which sends only the public notice text, and, if used, the MCP server (below). The practice's references and facts stay in its own database; the comparison is plain code.
- **That step uses the practice's own Anthropic API key.** Under Anthropic's commercial terms, API data is not used for model training and is kept for 30 days by default ([data usage](https://code.claude.com/docs/en/data-usage), [retention](https://platform.claude.com/docs/en/manage-claude/api-and-data-retention)).
- **Postgres and n8n listen on localhost only.** Nothing is reachable from the network.
- **Secrets stay in `.env`** on the practice's machine; `.gitignore` keeps it, the Excel file and n8n's data out of version control.
- **AI coding assistants can't read secrets.** [.claude/settings.json](.claude/settings.json) denies reading `.env`, `.mcp.json`, key files and n8n's own folder, asks before `docker compose down` and `docker volume rm`, and turns off the mode that skips permission prompts. A hook ([protect-secrets.js](.claude/hooks/protect-secrets.js)) blocks any command or search that names a secrets file. Per the [Claude Code docs](https://code.claude.com/docs/en/permissions), these rules cover Claude's own tools, not every program, so the same file also turns on Claude Code's [sandbox](https://code.claude.com/docs/en/sandboxing) for OS-level isolation. The sandbox runs on macOS, Linux and WSL2; on native Windows, run Claude Code inside WSL2 to get it.
- **n8n workflows can't read environment variables** (`N8N_BLOCK_ENV_ACCESS_IN_NODE=true` in the Docker setup), and n8n stores credentials encrypted.
- **The MCP server sees public tender facts only.** When someone asks Claude about tenders, the answer's data (titles, buyers, deadlines, verdicts) goes to Anthropic as part of that chat. A database login that can read nothing else enforces it (see [Ask Claude about tenders](#ask-claude-about-tenders-mcp)).
- **Personal data in TED notices** (contact persons) stays in the local database.
- **With client data,** the practice's data processing agreement should name Anthropic as a sub-processor.

## Handover
- **The practice's reference projects and facts** (turnover, insurance, staff, experience): edit [db/seed.sql](db/seed.sql) and run it again with the seed command under *The database* above. No code changes. Verdicts already given keep the old facts until the tenders are assessed again: to re-check all open tenders now, change `rules_version` in the *Settings* step of `n8n/assess-tenders.json` (at the usual model cost per tender). Keep [data/sample/reference_projects.csv](data/sample/reference_projects.csv) in step: it lists the same references.
- **Countries and tender categories (CPV codes, the EU's standard codes for what is being bought):** `COUNTRIES`, `CPV` and `MAIN_CPV_PREFIXES` at the top of the *Fetch new notices from TED* step in `n8n/fetch-ted-notices.json`.
- **Building types pursued, and which count as the same kind of reference:** `GROUP` and `NOT_PURSUED` at the top of the *Check fit (plain code)* step in `n8n/assess-tenders.json`. After a change, update `rules_version` in its *Settings* step: every open tender is then assessed again, at the usual model cost per tender.
- **The practice in words:** [data/sample/firm_profile.md](data/sample/firm_profile.md). It says which rules the code checks and where.
- **The practice owns the context** (references, facts, decisions, logs). The Claude model is set in one Settings step.
- Decisions and the reasons for them: [docs/decisions.md](docs/decisions.md).

## Data
Tender data comes from [TED](https://ted.europa.eu) (Tenders Electronic Daily), the EU's public procurement journal, through its open Search API. Under the [TED legal notice](https://ted.europa.eu/en/legal-notice), procurement notices can be freely reused. Source: TED, Publications Office of the European Union. This project is independent and not endorsed by the EU.

Notices can contain contact persons' names and emails. These stay in the local database and are not included in this repository or its examples.

The practice, its profile and its reference projects are **invented** for this demo. Any resemblance to a real firm or project is unintended.

## License
Copyright © 2026 Sandra Trochimowicz. All rights reserved. You may read the code here; using, copying, modifying or selling it needs written permission. See [LICENSE](LICENSE).
