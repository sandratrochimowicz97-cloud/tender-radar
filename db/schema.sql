-- Tender radar: state lives here, not in the workflow.
-- One row per tender notice. Re-running ingest never creates duplicates.

CREATE TABLE IF NOT EXISTS tenders (
    id              BIGSERIAL PRIMARY KEY,
    source          TEXT        NOT NULL,              -- 'ted' (later: one portal via browser automation)
    source_id       TEXT        NOT NULL,              -- the notice ID at the source
    content_hash    TEXT        NOT NULL,              -- hash of the fields we score on; changes if the notice is amended
    title           TEXT        NOT NULL,
    buyer           TEXT,
    country         CHAR(2),
    cpv_codes       TEXT[],
    deadline        TIMESTAMPTZ,
    value_eur       NUMERIC,
    url             TEXT,
    raw             JSONB       NOT NULL,              -- the notice as fetched, for audit and re-scoring
    status          TEXT        NOT NULL DEFAULT 'new'
        CHECK (status IN ('new','filtered_out','not_relevant','shortlisted','approved','rejected','failed')),
    status_reason   TEXT,                              -- why the rule step or the model set this status
    relevance_score NUMERIC,                           -- 0-1 from the relevance judge
    -- Go/no-go assessment (shortlist only), each claim backed by a quote from the notice
    requirements    JSONB,                             -- extracted: required references, turnover, certificates, team, deadlines; each with source quote
    reference_fit   JSONB,                             -- which of our reference projects meet each required reference, and what is missing
    recommendation  TEXT
        CHECK (recommendation IN ('go','conditional_go','no_go')),
    open_questions  TEXT[],                            -- at most 3 things to clarify before deciding
    explanation     TEXT,                              -- short reasons in plain language
    first_seen_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT tenders_idempotency UNIQUE (source, source_id, content_hash)
);

CREATE INDEX IF NOT EXISTS tenders_status_idx   ON tenders (status);
CREATE INDEX IF NOT EXISTS tenders_deadline_idx ON tenders (deadline);

-- One row per run: lets a run after a laptop-off gap catch up from the last success.
CREATE TABLE IF NOT EXISTS runs (
    id            BIGSERIAL PRIMARY KEY,
    started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at   TIMESTAMPTZ,
    status        TEXT        NOT NULL DEFAULT 'running'
        CHECK (status IN ('running','succeeded','failed')),
    fetched_from  TIMESTAMPTZ,                         -- window start: last successful run's finished_at
    fetched       INT DEFAULT 0,
    inserted      INT DEFAULT 0,
    shortlisted   INT DEFAULT 0,
    error         TEXT
);

-- Every paid model call, so cost per run is measured, not guessed.
CREATE TABLE IF NOT EXISTS model_calls (
    id            BIGSERIAL PRIMARY KEY,
    run_id        BIGINT REFERENCES runs(id),
    tender_id     BIGINT REFERENCES tenders(id),
    step          TEXT NOT NULL,                       -- 'relevance' | 'assess'
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

-- The partner's go/no-go decisions, with the reason. This is how the system learns the practice's judgment:
-- agreement between recommendation and decision is measured weekly, and repeated reasons become rules.
CREATE TABLE IF NOT EXISTS decisions (
    id              BIGSERIAL PRIMARY KEY,
    tender_id       BIGINT NOT NULL REFERENCES tenders(id),
    decision        TEXT   NOT NULL CHECK (decision IN ('go','no_go')),
    reason          TEXT   NOT NULL,                   -- in the partner's own words
    recommendation  TEXT,                              -- what the system recommended at the time (copied, so later changes don't rewrite history)
    decided_by      TEXT   NOT NULL,
    decided_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT one_decision_per_tender UNIQUE (tender_id)
);
