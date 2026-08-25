-- Add time sync flag to marker sets
ALTER TABLE marker_sets
  ADD COLUMN IF NOT EXISTS is_time_synced BOOLEAN NOT NULL DEFAULT true;
