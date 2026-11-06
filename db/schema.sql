-- Tender go/no-go assistant: state lives here, not in the workflow.
-- One row per tender notice. Re-running ingest never creates duplicates.

CREATE TABLE IF NOT EXISTS tenders (
    id              BIGSERIAL PRIMARY KEY,
    source          TEXT        NOT NULL,              -- 'ted' (later: one portal via browser automation)
    source_id       TEXT        NOT NULL,              -- the notice ID at the source
    content_hash    TEXT        NOT NULL,              -- hash of the whole notice as fetched; changes if the notice is amended
    title           TEXT        NOT NULL,
    buyer           TEXT,
    country         CHAR(2),
    cpv_codes       TEXT[],
    deadline        TIMESTAMPTZ,
    value_eur       NUMERIC,
    url             TEXT,
    raw             JSONB       NOT NULL,              -- the notice as fetched, for audit and re-scoring
    status          TEXT        NOT NULL DEFAULT 'new'
        CHECK (status IN ('new','failed')),           -- failed: the assessment could not be completed
    status_reason   TEXT,                              -- why the assessment failed
    -- Go/no-go assessment, each claim backed by a quote from the notice
    requirements    JSONB,                             -- extracted: required references, turnover, certificates, team, deadlines; each with source quote
    reference_fit   JSONB,                             -- which of our reference projects meet each required reference, and what is missing
    recommendation  TEXT
        CHECK (recommendation IN ('go','conditional_go','unresolved','no_go')),
    open_questions  TEXT[],                            -- other things the bidder must have (shown as "Also required")
    explanation     TEXT,                              -- short reasons in plain language
    first_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT tenders_idempotency UNIQUE (source, source_id, content_hash)
);

CREATE INDEX IF NOT EXISTS tenders_status_idx   ON tenders (status);
CREATE INDEX IF NOT EXISTS tenders_deadline_idx ON tenders (deadline);

-- One row per run: lets a run after downtime catch up from the last success.
CREATE TABLE IF NOT EXISTS runs (
    id            BIGSERIAL PRIMARY KEY,
    started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at   TIMESTAMPTZ,
    status        TEXT        NOT NULL DEFAULT 'running'
        CHECK (status IN ('running','succeeded','failed')),
    fetched_from  TIMESTAMPTZ,                         -- window start: last successful run's finished_at
    fetched       INT DEFAULT 0,
    inserted      INT DEFAULT 0,
    error         TEXT
);

-- Every paid model call, so cost per run is measured, not guessed.
CREATE TABLE IF NOT EXISTS model_calls (
    id            BIGSERIAL PRIMARY KEY,
    run_id        BIGINT REFERENCES runs(id),
    tender_id     BIGINT REFERENCES tenders(id),
    step          TEXT NOT NULL,                       -- 'assess' (the one model step)
    model         TEXT NOT NULL,
    input_tokens  INT,
    output_tokens INT,
    cost_usd      NUMERIC,
    ok            BOOLEAN NOT NULL,
    error         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The practice's own reference projects (loaded from data/sample/reference_projects.csv).
CREATE TABLE IF NOT EXISTS reference_projects (
    id            TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    typology      TEXT NOT NULL,
    country       CHAR(2),
    year          INT,
    size_m2       NUMERIC,
    budget_eur_m  NUMERIC,
    highlights    TEXT
);

-- The practice's own facts that tenders set minimums for (loaded from db/seed.sql).
-- The fit check compares each extracted minimum with these values; a fact that is missing here is never guessed.
CREATE TABLE IF NOT EXISTS practice_facts (
    name          TEXT PRIMARY KEY,                   -- 'annual_turnover_eur' | 'professional_indemnity_eur' | 'staff' | 'lead_experience_years'
    value         NUMERIC NOT NULL,
    note          TEXT
);

-- The partner's go/no-go decisions, with the reason, next to what the system recommended at the time.
-- Agreement can be counted from here, and a reason that keeps repeating points to a rule the system is missing.
CREATE TABLE IF NOT EXISTS decisions (
    id              BIGSERIAL PRIMARY KEY,
    tender_id       BIGINT NOT NULL REFERENCES tenders(id),
    decision        TEXT   NOT NULL CHECK (decision IN ('go','no_go')),
    reason          TEXT   NOT NULL,                   -- in the partner's own words
    recommendation  TEXT,                              -- what the system recommended at the time (copied, so later changes don't rewrite history)
    decided_by      TEXT   NOT NULL,
    decided_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    outcome         TEXT CHECK (outcome IN ('won','lost','not_submitted')),  -- filled in after the award; empty until known
    CONSTRAINT one_decision_per_tender UNIQUE (tender_id)
);
