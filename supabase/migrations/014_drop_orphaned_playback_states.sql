-- Migration 014: Drop the orphaned playback_states table
-- This migration must be run manually in the Supabase dashboard

-- Migration 009 intended to remove the playback-position feature and ran
--   DROP TABLE IF EXISTS user_playback_states;
-- but `user_playback_states` is the *Drift* (local) table name. The Supabase
-- table created in 001_initial_schema.sql is `playback_states`, so the IF
-- EXISTS made that statement a silent no-op and the remote table survived.
--
-- The local Drift table was dropped correctly (lib/data/datasources/local/
-- database.dart), and no code reads or writes playback positions any more,
-- so the remote table has been dead — but still RLS-enabled, still carrying
-- an updated_at trigger — ever since.
--
-- CASCADE also removes the dependent objects created in 001:
--   idx_playback_states_user, update_playback_states_updated_at, and the
--   four playback_states_{select,insert,update,delete} RLS policies.
DROP TABLE IF EXISTS playback_states CASCADE;
