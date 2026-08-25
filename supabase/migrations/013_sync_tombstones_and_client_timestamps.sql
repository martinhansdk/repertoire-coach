-- Migration 013: Tombstone-based deletion sync + client-authoritative timestamps
-- Run manually in the Supabase dashboard (like migration 009).
--
-- WHY (see sync review):
--  1. Deletions were previously synced "by absence": the client hard-deleted any
--     local row not returned by getAllRemote(). Any partial/empty remote read
--     (empty membership chain, RLS hiccup, PostgREST row limit) was
--     indistinguishable from mass deletion and destroyed local data.
--     Fix: deletions become data ("deleted" tombstone rows) and sync like any
--     other update. Absence no longer implies anything.
--  2. updated_at was overwritten server-side by BEFORE UPDATE triggers (and by
--     the client at push time), so "newest wins" compared push times instead of
--     edit times, letting older edits overwrite newer ones. Fix: updated_at is
--     now client-authoritative (set at edit time, in UTC); drop the triggers on
--     synced tables.

-- ============================================================
-- 1. Tombstone columns (choir_members already has one from 009)
-- ============================================================
ALTER TABLE choirs          ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE concerts        ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE songs           ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE tracks          ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE marker_sets     ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE favorite_tracks ADD COLUMN IF NOT EXISTS deleted BOOLEAN NOT NULL DEFAULT false;

-- ============================================================
-- 1b. tracks had no updated_at column at all: the client stripped it on
--     insert and never sent it on update, so track conflict resolution had no
--     edit time to compare. Add it, backfilled from created_at.
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tracks' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE tracks ADD COLUMN updated_at TIMESTAMPTZ;
    UPDATE tracks SET updated_at = created_at;
    ALTER TABLE tracks ALTER COLUMN updated_at SET NOT NULL;
    ALTER TABLE tracks ALTER COLUMN updated_at SET DEFAULT now();
  END IF;
END $$;

-- ============================================================
-- 2. Client-authoritative updated_at: drop server stamping triggers
--    (users/playback_states are not part of the sync algorithm; users trigger
--    is left in place. NOTE: playback_states was NOT actually dropped by
--    migration 009 -- that statement used the Drift-side name
--    `user_playback_states` and silently no-opped. Migration 014 drops it.)
-- ============================================================
DROP TRIGGER IF EXISTS update_choirs_updated_at      ON choirs;
DROP TRIGGER IF EXISTS update_concerts_updated_at    ON concerts;
DROP TRIGGER IF EXISTS update_songs_updated_at       ON songs;
DROP TRIGGER IF EXISTS update_marker_sets_updated_at ON marker_sets;

-- ============================================================
-- 3. RLS: deletion is now an UPDATE (deleted := true), so the existing
--    FOR UPDATE policies govern who may delete. VERIFY before deploying that,
--    for each table below, the UPDATE policy covers at least the principals the
--    old DELETE policy covered (001_initial_schema.sql and
--    008_fix_marker_delete_policies.sql), otherwise some users lose the
--    ability to delete:
--      choirs:       DELETE was owner_id = auth.uid()
--      choir_members:DELETE was choir owner
--      concerts:     DELETE was any choir member
--      songs:        DELETE was any choir member (via concert join)
--      tracks:       DELETE was any choir member (via song/concert join)
--      marker_sets:  DELETE per 008 (owner; see that migration)
--      favorite_tracks: DELETE was user_id = auth.uid()
--    The old FOR DELETE policies are left in place; they are simply no longer
--    exercised by the app. is_time_synced CHECK (migration 012) is unaffected:
--    tombstoned marker_sets keep their payload.
