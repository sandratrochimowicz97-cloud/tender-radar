-- Read-only access for the MCP server: one view with public tender facts, and one login that can read only that view.
-- The view leaves out everything about the practice: the Why text, extracted requirements, reference fit,
-- reference projects, practice facts and the partner's decisions. The database enforces this, not the server code.
-- Safe to run again. Run with the reader's password from .env, for example:
--   docker compose exec -T db psql -U radar -d tender_radar -v pw="<MCP_READER_PASSWORD>" < db/mcp-reader.sql

CREATE OR REPLACE VIEW public_tenders AS
SELECT notice_id, title, buyer, country, deadline, url, verdict, also_required, added_on
FROM (
  SELECT DISTINCT ON (source_id)
         source_id AS notice_id, title, buyer, country, deadline::date AS deadline, url,
         CASE recommendation WHEN 'go' THEN 'GO' WHEN 'conditional_go' THEN 'CONDITIONAL'
                             WHEN 'unresolved' THEN 'CHECK YOURSELF' WHEN 'no_go' THEN 'NO-GO' END AS verdict,
         open_questions AS also_required,          -- taken from the notice text, not from the practice's data
         first_seen_at::date AS added_on
  FROM tenders
  WHERE source = 'ted'
  ORDER BY source_id, first_seen_at DESC, id DESC
) latest
WHERE deadline IS NULL OR deadline > current_date;  -- open tenders only

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mcp_reader') THEN
    CREATE ROLE mcp_reader LOGIN;
  END IF;
END $$;
ALTER ROLE mcp_reader PASSWORD :'pw';
-- Sessions start read-only and short. This is a second layer: the grants below are what actually blocks writes.
ALTER ROLE mcp_reader SET default_transaction_read_only = on;
ALTER ROLE mcp_reader SET statement_timeout = '5s';
ALTER ROLE mcp_reader CONNECTION LIMIT 3;

-- Nothing but the view: take back anything granted earlier, then grant the view alone.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM mcp_reader;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM mcp_reader;
SELECT format('GRANT CONNECT ON DATABASE %I TO mcp_reader', current_database()) \gexec
-- No temporary tables either (the project's own user is the database owner and keeps its rights).
SELECT format('REVOKE TEMPORARY ON DATABASE %I FROM PUBLIC', current_database()) \gexec
GRANT USAGE ON SCHEMA public TO mcp_reader;
GRANT SELECT ON public_tenders TO mcp_reader;
