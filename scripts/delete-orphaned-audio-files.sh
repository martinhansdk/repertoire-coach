#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Find and optionally delete orphaned Supabase storage objects for tracks.

An orphaned file is in storage.objects but has no matching public.tracks.storage_path.
Deletion is performed through the Storage API (not direct SQL).

Usage:
  ./scripts/delete-orphaned-audio-files.sh [options]

Options:
  --bucket NAME         Storage bucket name. Default: audio_files
  --batch-size N        Number of paths per delete request. Default: 100
  --limit N             Only process first N orphaned files (for testing)
  --execute             Actually delete files. Without this flag, script is dry-run.
  -h, --help            Show this help.

Required environment variables:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  SUPABASE_DB_URL

Notes:
  - Dry-run mode is the default and does not delete anything.
  - Uses SQL only for discovery; deletion goes through /storage/v1/object/{bucket}.
EOF
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUCKET="audio_files"
BATCH_SIZE=100
LIMIT=""
EXECUTE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket)
      BUCKET="${2:-}"
      shift 2
      ;;
    --batch-size)
      BATCH_SIZE="${2:-}"
      shift 2
      ;;
    --limit)
      LIMIT="${2:-}"
      shift 2
      ;;
    --execute)
      EXECUTE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/.env"
fi

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "Error: SUPABASE_URL is required." >&2
  exit 1
fi

if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "Error: SUPABASE_SERVICE_ROLE_KEY is required." >&2
  exit 1
fi

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "Error: SUPABASE_DB_URL is required." >&2
  exit 1
fi

for cmd in psql jq curl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Error: required command not found: ${cmd}" >&2
    exit 1
  fi
done

if ! [[ "${BATCH_SIZE}" =~ ^[0-9]+$ ]] || [[ "${BATCH_SIZE}" -le 0 ]]; then
  echo "Error: --batch-size must be a positive integer." >&2
  exit 1
fi

if [[ -n "${LIMIT}" ]] && { ! [[ "${LIMIT}" =~ ^[0-9]+$ ]] || [[ "${LIMIT}" -le 0 ]]; }; then
  echo "Error: --limit must be a positive integer." >&2
  exit 1
fi

SUPABASE_URL="${SUPABASE_URL%/}"

LIMIT_SQL=""
if [[ -n "${LIMIT}" ]]; then
  LIMIT_SQL="LIMIT ${LIMIT}"
fi

read -r -d '' SQL <<EOF || true
WITH orphaned AS (
  SELECT
    o.name AS storage_path,
    COALESCE((o.metadata->>'size')::bigint, 0) AS size_bytes
  FROM storage.objects o
  LEFT JOIN public.tracks t
    ON t.storage_path = o.name
  WHERE o.bucket_id = :'bucket'
    AND t.id IS NULL
  ORDER BY size_bytes DESC, o.created_at DESC
  ${LIMIT_SQL}
)
SELECT COALESCE(
  json_agg(
    json_build_object(
      'storage_path', storage_path,
      'size_bytes', size_bytes
    )
  ),
  '[]'::json
)::text
FROM orphaned;
EOF

ORPHANS_JSON="$(psql "${SUPABASE_DB_URL}" -v ON_ERROR_STOP=1 -v bucket="${BUCKET}" -tA -c "${SQL}")"

COUNT="$(jq 'length' <<<"${ORPHANS_JSON}")"
TOTAL_BYTES="$(jq '[.[].size_bytes] | add // 0' <<<"${ORPHANS_JSON}")"

echo "Bucket: ${BUCKET}"
echo "Orphaned files: ${COUNT}"
echo "Total orphaned bytes: ${TOTAL_BYTES}"

if [[ "${COUNT}" -eq 0 ]]; then
  echo "No orphaned files found."
  exit 0
fi

echo ""
echo "Largest 10 orphaned files:"
jq -r '
  sort_by(.size_bytes) | reverse | .[:10][]
  | "\(.size_bytes)\t\(.storage_path)"
' <<<"${ORPHANS_JSON}"

if [[ "${EXECUTE}" != "true" ]]; then
  echo ""
  echo "Dry run complete. Re-run with --execute to delete these files."
  exit 0
fi

echo ""
echo "Deleting orphaned files via Storage API..."

DELETED=0
for ((start=0; start<COUNT; start+=BATCH_SIZE)); do
  end=$((start + BATCH_SIZE))
  PATHS_JSON="$(jq -c ".[$start:$end] | map(.storage_path)" <<<"${ORPHANS_JSON}")"

  RESPONSE_FILE="$(mktemp)"
  HTTP_CODE="$(
    curl -sS -o "${RESPONSE_FILE}" -w "%{http_code}" \
      -X DELETE "${SUPABASE_URL}/storage/v1/object/${BUCKET}" \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      --data "{\"prefixes\":${PATHS_JSON}}"
  )"

  if [[ "${HTTP_CODE}" -lt 200 || "${HTTP_CODE}" -ge 300 ]]; then
    echo "Error: delete request failed with HTTP ${HTTP_CODE}" >&2
    cat "${RESPONSE_FILE}" >&2
    rm -f "${RESPONSE_FILE}"
    exit 1
  fi

  rm -f "${RESPONSE_FILE}"

  BATCH_COUNT="$(jq 'length' <<<"${PATHS_JSON}")"
  DELETED=$((DELETED + BATCH_COUNT))
  echo "Deleted ${DELETED}/${COUNT}"
done

echo ""
echo "Done. Deleted ${DELETED} orphaned files."
