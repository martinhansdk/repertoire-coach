-- Fire-and-forget error log.  The Flutter client INSERTs on every
-- caught/uncaught exception; developers query via the Supabase
-- dashboard (service-role key, which bypasses RLS).

CREATE TABLE IF NOT EXISTS error_logs (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       uuid        DEFAULT auth.uid(),
  error_message text        NOT NULL,
  stack_trace   text,
  screen        text,
  platform      text,
  created_at    timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs (created_at DESC);

ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

-- Authenticated users may insert; user_id is filled automatically
-- by the DEFAULT.  No SELECT policy — reads are via the dashboard.
CREATE POLICY error_logs_insert ON error_logs
  FOR INSERT TO authenticated
  WITH CHECK (true);
