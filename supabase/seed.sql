-- LOCAL/CI SEED — applied only by `supabase start` / `supabase db reset`.
-- Never runs against production.

-- Test-only introspection helper used by the schema-drift integration test:
-- lets the test compare each model's toJson() keys against the actual table
-- columns, catching "the client sends a column the table doesn't have" (and
-- vice versa) before it becomes a permanent silent push failure.
CREATE OR REPLACE FUNCTION public.table_columns(p_table text)
RETURNS TABLE(column_name text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT column_name::text
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = p_table;
$$;

-- Only the service role (i.e. the test harness) may call it.
REVOKE ALL ON FUNCTION public.table_columns(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.table_columns(text) TO service_role;
