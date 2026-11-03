-- For databases created before 2026-11-02: run once to bring them up to date.
ALTER TABLE tenders DROP CONSTRAINT IF EXISTS tenders_recommendation_check;
ALTER TABLE tenders ADD CONSTRAINT tenders_recommendation_check
    CHECK (recommendation IN ('go','conditional_go','unresolved','no_go'));

-- Outcome of each decision, filled in after the award.
ALTER TABLE decisions ADD COLUMN IF NOT EXISTS outcome TEXT
    CHECK (outcome IN ('won','lost','not_submitted'));
