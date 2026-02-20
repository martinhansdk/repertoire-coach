-- Migration 011: Enforce monotonic marker positions in marker_sets.markers_json.
-- Monotonic rule: considering only non-null position_ms entries in array order,
-- values must be non-decreasing.

CREATE OR REPLACE FUNCTION marker_positions_are_monotonic(markers JSONB)
RETURNS BOOLEAN
LANGUAGE SQL
IMMUTABLE
AS $$
  WITH items AS (
    SELECT
      ordinality AS idx,
      CASE
        WHEN jsonb_typeof(value->'position_ms') = 'number'
          THEN (value->>'position_ms')::INT
        ELSE NULL
      END AS position_ms
    FROM jsonb_array_elements(markers) WITH ORDINALITY
  ),
  non_null AS (
    SELECT
      idx,
      position_ms,
      lag(position_ms) OVER (ORDER BY idx) AS previous_position
    FROM items
    WHERE position_ms IS NOT NULL
  )
  SELECT NOT EXISTS (
    SELECT 1
    FROM non_null
    WHERE previous_position IS NOT NULL
      AND position_ms < previous_position
  );
$$;

ALTER TABLE marker_sets
  DROP CONSTRAINT IF EXISTS marker_sets_markers_json_monotonic_positions;

ALTER TABLE marker_sets
  ADD CONSTRAINT marker_sets_markers_json_monotonic_positions
  CHECK (marker_positions_are_monotonic(markers_json));
