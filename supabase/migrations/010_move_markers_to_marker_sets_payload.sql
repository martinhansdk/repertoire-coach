-- Migration 010: Move marker rows into marker_sets.markers_json payload
-- Breaking change: drops the markers table after backfill.

-- 1) Add payload column to marker_sets.
ALTER TABLE marker_sets
  ADD COLUMN IF NOT EXISTS markers_json JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 2) Backfill payload from existing markers table in display_order order.
WITH markers_grouped AS (
  SELECT
    m.marker_set_id,
    jsonb_agg(
      jsonb_build_object(
        'label', m.label,
        'position_ms', m.position_ms
      )
      ORDER BY m.display_order
    ) AS payload
  FROM markers m
  GROUP BY m.marker_set_id
)
UPDATE marker_sets ms
SET markers_json = mg.payload
FROM markers_grouped mg
WHERE ms.id = mg.marker_set_id;

-- 3) Ensure JSON shape is an array.
ALTER TABLE marker_sets
  DROP CONSTRAINT IF EXISTS marker_sets_markers_json_is_array;

ALTER TABLE marker_sets
  ADD CONSTRAINT marker_sets_markers_json_is_array
  CHECK (jsonb_typeof(markers_json) = 'array');

-- 4) Remove marker table policies and table.
DROP POLICY IF EXISTS markers_select ON markers;
DROP POLICY IF EXISTS markers_insert ON markers;
DROP POLICY IF EXISTS markers_update ON markers;
DROP POLICY IF EXISTS markers_delete ON markers;

DROP TABLE IF EXISTS markers;
