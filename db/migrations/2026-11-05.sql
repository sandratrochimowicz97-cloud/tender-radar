-- For databases created before 2026-11-05: run once to bring them up to date. Safe to repeat.
-- Removes what the first design (a separate relevance step) left behind; no workflow uses it.
ALTER TABLE tenders DROP COLUMN IF EXISTS relevance_score;
ALTER TABLE runs DROP COLUMN IF EXISTS shortlisted;
ALTER TABLE tenders DROP CONSTRAINT IF EXISTS tenders_status_check;
-- Statuses of the first design no workflow reads any more: such tenders are treated as new.
UPDATE tenders SET status = 'new' WHERE status NOT IN ('new','failed');
ALTER TABLE tenders ADD CONSTRAINT tenders_status_check CHECK (status IN ('new','failed'));
