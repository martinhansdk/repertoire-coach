-- Allow any choir member to delete shared markers and marker sets,
-- not just the creator.  This matches the existing UPDATE policies
-- and fixes a bug where non-creator edits (delete-then-recreate in
-- the save flow) silently fail on the server, leaving stale rows.

-- marker_sets: allow choir-member delete for shared sets
DROP POLICY IF EXISTS marker_sets_delete ON marker_sets;
CREATE POLICY marker_sets_delete ON marker_sets
  FOR DELETE USING (
    (is_shared = true AND EXISTS (
      SELECT 1 FROM tracks t
      JOIN songs s ON t.song_id = s.id
      JOIN concerts c ON s.concert_id = c.id
      JOIN choir_members cm ON c.choir_id = cm.choir_id
      WHERE t.id = track_id AND cm.user_id = auth.uid()
    ))
    OR (is_shared = false AND created_by_user_id = auth.uid())
  );

-- markers: allow choir-member delete for markers in shared sets
DROP POLICY IF EXISTS markers_delete ON markers;
CREATE POLICY markers_delete ON markers
  FOR DELETE USING (
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
