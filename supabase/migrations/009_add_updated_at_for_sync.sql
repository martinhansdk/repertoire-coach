-- Migration 009: Add updated_at columns and bidirectional sync support
-- This migration must be run manually in the Supabase dashboard

-- Add updated_at to markers
ALTER TABLE markers ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
UPDATE markers SET updated_at = created_at;

-- Add updated_at and deleted to choir_members
ALTER TABLE choir_members ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
UPDATE choir_members SET updated_at = joined_at;
ALTER TABLE choir_members ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT false;

-- Add updated_at to favorite_tracks
ALTER TABLE favorite_tracks ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
UPDATE favorite_tracks SET updated_at = added_at;

-- Drop user_playback_states table (no longer used)
DROP TABLE IF EXISTS user_playback_states;
