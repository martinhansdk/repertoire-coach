-- Create favorite tracks table for quick access to frequently-used tracks
-- Favorites are per-user and sync across devices

CREATE TABLE IF NOT EXISTS favorite_tracks (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  track_id UUID NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
  song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, track_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_favorite_tracks_user ON favorite_tracks(user_id);
CREATE INDEX IF NOT EXISTS idx_favorite_tracks_track ON favorite_tracks(track_id);
CREATE INDEX IF NOT EXISTS idx_favorite_tracks_user_added ON favorite_tracks(user_id, added_at DESC);

-- Row Level Security Policies
ALTER TABLE favorite_tracks ENABLE ROW LEVEL SECURITY;

-- Users can only see their own favorites
DROP POLICY IF EXISTS favorite_tracks_select ON favorite_tracks;
CREATE POLICY favorite_tracks_select ON favorite_tracks
  FOR SELECT USING (user_id = auth.uid());

-- Users can only add their own favorites
DROP POLICY IF EXISTS favorite_tracks_insert ON favorite_tracks;
CREATE POLICY favorite_tracks_insert ON favorite_tracks
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can only delete their own favorites
DROP POLICY IF EXISTS favorite_tracks_delete ON favorite_tracks;
CREATE POLICY favorite_tracks_delete ON favorite_tracks
  FOR DELETE USING (user_id = auth.uid());
