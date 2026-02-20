-- Migration 012: Keep denormalized is_time_synced consistent with markers_json.
-- Rule: true iff all non-empty labels have numeric position_ms.

CREATE OR REPLACE FUNCTION marker_set_payload_is_time_synced(markers JSONB)
RETURNS BOOLEAN
LANGUAGE SQL
IMMUTABLE
AS $$
  SELECT NOT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(markers) AS e
    WHERE COALESCE(e->>'label', '') <> ''
      AND jsonb_typeof(e->'position_ms') IS DISTINCT FROM 'number'
  );
$$;

ALTER TABLE marker_sets
  DROP CONSTRAINT IF EXISTS marker_sets_is_time_synced_matches_payload;

ALTER TABLE marker_sets
  ADD CONSTRAINT marker_sets_is_time_synced_matches_payload
  CHECK (is_time_synced = marker_set_payload_is_time_synced(markers_json));
