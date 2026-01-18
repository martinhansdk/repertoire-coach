-- Initial database schema for Repertoire Coach
-- This migration creates all core tables and RLS policies

-- Users table (extends Supabase Auth)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  display_name VARCHAR(255),
  last_accessed_concert_id UUID,
  language_preference VARCHAR(10) DEFAULT 'en',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Choirs table
CREATE TABLE IF NOT EXISTS choirs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Choir members junction table
CREATE TABLE IF NOT EXISTS choir_members (
  choir_id UUID NOT NULL REFERENCES choirs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (choir_id, user_id)
);

-- Concerts table
CREATE TABLE IF NOT EXISTS concerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  choir_id UUID NOT NULL REFERENCES choirs(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  concert_date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Songs table
CREATE TABLE IF NOT EXISTS songs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  concert_id UUID NOT NULL REFERENCES concerts(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tracks table
CREATE TABLE IF NOT EXISTS tracks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  audio_url TEXT,
  storage_path TEXT,
  duration_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Marker sets table (shared or private)
CREATE TABLE IF NOT EXISTS marker_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id UUID NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  is_shared BOOLEAN NOT NULL DEFAULT false,
  created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Markers table (positions within marker sets)
CREATE TABLE IF NOT EXISTS markers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  marker_set_id UUID NOT NULL REFERENCES marker_sets(id) ON DELETE CASCADE,
  label VARCHAR(255) NOT NULL,
  position_ms INTEGER NOT NULL,
  display_order INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Playback states table (per-user, private)
CREATE TABLE IF NOT EXISTS playback_states (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  track_id UUID NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
  position_ms INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, song_id, track_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_choir_members_user ON choir_members(user_id);
CREATE INDEX IF NOT EXISTS idx_choir_members_choir ON choir_members(choir_id);
CREATE INDEX IF NOT EXISTS idx_concerts_choir_date ON concerts(choir_id, concert_date);
CREATE INDEX IF NOT EXISTS idx_songs_concert ON songs(concert_id);
CREATE INDEX IF NOT EXISTS idx_tracks_song ON tracks(song_id);
CREATE INDEX IF NOT EXISTS idx_marker_sets_track ON marker_sets(track_id);
CREATE INDEX IF NOT EXISTS idx_marker_sets_user ON marker_sets(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_markers_set ON markers(marker_set_id);
CREATE INDEX IF NOT EXISTS idx_playback_states_user ON playback_states(user_id);

-- Updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_choirs_updated_at ON choirs;
CREATE TRIGGER update_choirs_updated_at BEFORE UPDATE ON choirs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_concerts_updated_at ON concerts;
CREATE TRIGGER update_concerts_updated_at BEFORE UPDATE ON concerts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_songs_updated_at ON songs;
CREATE TRIGGER update_songs_updated_at BEFORE UPDATE ON songs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_marker_sets_updated_at ON marker_sets;
CREATE TRIGGER update_marker_sets_updated_at BEFORE UPDATE ON marker_sets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_playback_states_updated_at ON playback_states;
CREATE TRIGGER update_playback_states_updated_at BEFORE UPDATE ON playback_states
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Users table RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_own ON users;
CREATE POLICY users_select_own ON users
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS users_insert_own ON users;
CREATE POLICY users_insert_own ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS users_update_own ON users;
CREATE POLICY users_update_own ON users
  FOR UPDATE USING (auth.uid() = id);

-- Choirs table RLS
ALTER TABLE choirs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS choirs_select_member ON choirs;
CREATE POLICY choirs_select_member ON choirs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM choir_members
      WHERE choir_id = id AND user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS choirs_insert_own ON choirs;
CREATE POLICY choirs_insert_own ON choirs
  FOR INSERT WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS choirs_update_owner ON choirs;
CREATE POLICY choirs_update_owner ON choirs
  FOR UPDATE USING (owner_id = auth.uid());

DROP POLICY IF EXISTS choirs_delete_owner ON choirs;
CREATE POLICY choirs_delete_owner ON choirs
  FOR DELETE USING (owner_id = auth.uid());

-- Choir members table RLS
ALTER TABLE choir_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS choir_members_select ON choir_members;
CREATE POLICY choir_members_select ON choir_members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM choir_members cm
      WHERE cm.choir_id = choir_members.choir_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS choir_members_insert ON choir_members;
CREATE POLICY choir_members_insert ON choir_members
  FOR INSERT WITH CHECK (
    -- Allow if you're the choir owner
    EXISTS (
      SELECT 1 FROM choirs
      WHERE id = choir_id AND owner_id = auth.uid()
    )
    -- OR if you're adding yourself to a choir you just created
    OR (user_id = auth.uid())
  );

DROP POLICY IF EXISTS choir_members_delete ON choir_members;
CREATE POLICY choir_members_delete ON choir_members
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM choirs
      WHERE id = choir_id AND owner_id = auth.uid()
    )
  );

-- Concerts table RLS
ALTER TABLE concerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS concerts_select ON concerts;
CREATE POLICY concerts_select ON concerts
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM choir_members cm
      WHERE cm.choir_id = concerts.choir_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS concerts_insert ON concerts;
CREATE POLICY concerts_insert ON concerts
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM choir_members cm
      WHERE cm.choir_id = concerts.choir_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS concerts_update ON concerts;
CREATE POLICY concerts_update ON concerts
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM choir_members cm
      WHERE cm.choir_id = concerts.choir_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS concerts_delete ON concerts;
CREATE POLICY concerts_delete ON concerts
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM choir_members cm
      WHERE cm.choir_id = concerts.choir_id AND cm.user_id = auth.uid()
    )
  );

-- Songs table RLS
ALTER TABLE songs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS songs_select ON songs;
CREATE POLICY songs_select ON songs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM concerts c
      JOIN choir_members cm ON cm.choir_id = c.choir_id
      WHERE c.id = songs.concert_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS songs_insert ON songs;
CREATE POLICY songs_insert ON songs
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM concerts c
      JOIN choir_members cm ON cm.choir_id = c.choir_id
      WHERE c.id = songs.concert_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS songs_update ON songs;
CREATE POLICY songs_update ON songs
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM concerts c
      JOIN choir_members cm ON cm.choir_id = c.choir_id
      WHERE c.id = songs.concert_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS songs_delete ON songs;
CREATE POLICY songs_delete ON songs
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM concerts c
      JOIN choir_members cm ON cm.choir_id = c.choir_id
      WHERE c.id = songs.concert_id AND cm.user_id = auth.uid()
    )
  );

-- Tracks table RLS
ALTER TABLE tracks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tracks_select ON tracks;
CREATE POLICY tracks_select ON tracks
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM songs s
      JOIN concerts c ON c.id = s.concert_id
      JOIN choir_members cm ON cm.choir_id = c.choir_id
      WHERE s.id = tracks.song_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tracks_insert ON tracks;
CREATE POLICY tracks_insert ON tracks
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM songs s
      JOIN concerts c ON c.id = s.concert_id
      JOIN choir_members cm ON cm.choir_id = c.choir_id
      WHERE s.id = tracks.song_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tracks_update ON tracks;
CREATE POLICY tracks_update ON tracks
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM songs s
      JOIN concerts c ON c.id = s.concert_id
      JOIN choir_members cm ON cm.choir_id = c.choir_id
      WHERE s.id = tracks.song_id AND cm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tracks_delete ON tracks;
CREATE POLICY tracks_delete ON tracks
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM songs s
      JOIN concerts c ON c.id = s.concert_id
      JOIN choir_members cm ON cm.choir_id = c.choir_id
      WHERE s.id = tracks.song_id AND cm.user_id = auth.uid()
    )
  );

-- Marker sets table RLS
ALTER TABLE marker_sets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS marker_sets_select ON marker_sets;
CREATE POLICY marker_sets_select ON marker_sets
  FOR SELECT USING (
    (is_shared = true AND EXISTS (
      SELECT 1 FROM tracks t
      JOIN songs s ON t.song_id = s.id
      JOIN concerts c ON s.concert_id = c.id
      JOIN choir_members cm ON c.choir_id = cm.choir_id
      WHERE t.id = track_id AND cm.user_id = auth.uid()
    ))
    OR (is_shared = false AND created_by_user_id = auth.uid())
  );

DROP POLICY IF EXISTS marker_sets_insert ON marker_sets;
CREATE POLICY marker_sets_insert ON marker_sets
  FOR INSERT WITH CHECK (
    (is_shared = true AND EXISTS (
      SELECT 1 FROM tracks t
      JOIN songs s ON t.song_id = s.id
      JOIN concerts c ON s.concert_id = c.id
      JOIN choir_members cm ON c.choir_id = cm.choir_id
      WHERE t.id = track_id AND cm.user_id = auth.uid()
    ))
    OR (is_shared = false AND created_by_user_id = auth.uid())
  );

DROP POLICY IF EXISTS marker_sets_update ON marker_sets;
CREATE POLICY marker_sets_update ON marker_sets
  FOR UPDATE USING (
    (is_shared = true AND EXISTS (
      SELECT 1 FROM tracks t
      JOIN songs s ON t.song_id = s.id
      JOIN concerts c ON s.concert_id = c.id
      JOIN choir_members cm ON c.choir_id = cm.choir_id
      WHERE t.id = track_id AND cm.user_id = auth.uid()
    ))
    OR (is_shared = false AND created_by_user_id = auth.uid())
  );

DROP POLICY IF EXISTS marker_sets_delete ON marker_sets;
CREATE POLICY marker_sets_delete ON marker_sets
  FOR DELETE USING (created_by_user_id = auth.uid());

-- Markers table RLS
ALTER TABLE markers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS markers_select ON markers;
CREATE POLICY markers_select ON markers
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM marker_sets ms
      WHERE ms.id = marker_set_id
      AND (
        (ms.is_shared = true AND EXISTS (
          SELECT 1 FROM tracks t
          JOIN songs s ON t.song_id = s.id
          JOIN concerts c ON s.concert_id = c.id
          JOIN choir_members cm ON c.choir_id = cm.choir_id
          WHERE t.id = ms.track_id AND cm.user_id = auth.uid()
        ))
        OR (ms.is_shared = false AND ms.created_by_user_id = auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS markers_insert ON markers;
CREATE POLICY markers_insert ON markers
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM marker_sets ms
      WHERE ms.id = marker_set_id
      AND (
        (ms.is_shared = true AND EXISTS (
          SELECT 1 FROM tracks t
          JOIN songs s ON t.song_id = s.id
          JOIN concerts c ON s.concert_id = c.id
          JOIN choir_members cm ON c.choir_id = cm.choir_id
          WHERE t.id = ms.track_id AND cm.user_id = auth.uid()
        ))
        OR (ms.is_shared = false AND ms.created_by_user_id = auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS markers_update ON markers;
CREATE POLICY markers_update ON markers
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM marker_sets ms
      WHERE ms.id = marker_set_id
      AND (
        (ms.is_shared = true AND EXISTS (
          SELECT 1 FROM tracks t
          JOIN songs s ON t.song_id = s.id
          JOIN concerts c ON s.concert_id = c.id
          JOIN choir_members cm ON c.choir_id = cm.choir_id
          WHERE t.id = ms.track_id AND cm.user_id = auth.uid()
        ))
        OR (ms.is_shared = false AND ms.created_by_user_id = auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS markers_delete ON markers;
CREATE POLICY markers_delete ON markers
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM marker_sets ms
      WHERE ms.id = marker_set_id AND ms.created_by_user_id = auth.uid()
    )
  );

-- Playback states table RLS
ALTER TABLE playback_states ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS playback_states_select ON playback_states;
CREATE POLICY playback_states_select ON playback_states
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS playback_states_insert ON playback_states;
CREATE POLICY playback_states_insert ON playback_states
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS playback_states_update ON playback_states;
CREATE POLICY playback_states_update ON playback_states
  FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS playback_states_delete ON playback_states;
CREATE POLICY playback_states_delete ON playback_states
  FOR DELETE USING (user_id = auth.uid());
