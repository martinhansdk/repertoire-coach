#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Download a Supabase database backup using Supabase CLI.

Usage:
  ./scripts/download-supabase-backup.sh [options]

Options:
  --output-dir DIR      Destination directory for dump files.
                        Default: backups/supabase/<timestamp>
  --prefix NAME         File prefix. Default: backup
  --include-history     Also dump supabase_migrations schema/data.
  -h, --help            Show this help.

Prerequisites:
  1) supabase login
  2) supabase link --project-ref <your-project-ref>

Outputs:
  <output-dir>/<prefix>-roles.sql
  <output-dir>/<prefix>-schema.sql
  <output-dir>/<prefix>-data.sql
  (optional) <output-dir>/<prefix>-history-schema.sql
  (optional) <output-dir>/<prefix>-history-data.sql
EOF
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

OUTPUT_DIR=""
PREFIX="backup"
INCLUDE_HISTORY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --prefix)
      PREFIX="${2:-}"
      shift 2
      ;;
    --include-history)
      INCLUDE_HISTORY="true"
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

if ! command -v supabase >/dev/null 2>&1; then
  echo "Error: supabase CLI is not installed or not in PATH." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is required for supabase db dump." >&2
  exit 1
fi

if ! supabase projects list --output json >/dev/null 2>&1; then
  echo "Error: Supabase CLI is not authenticated." >&2
  echo "Run: supabase login" >&2
  exit 1
fi

PROJECT_REF_FILE="${PROJECT_ROOT}/supabase/.temp/project-ref"
if [[ ! -s "${PROJECT_REF_FILE}" ]]; then
  echo "Error: Supabase project is not linked for this repo." >&2
  echo "Run: supabase link --project-ref <your-project-ref>" >&2
  exit 1
fi

if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="${PROJECT_ROOT}/backups/supabase/${TIMESTAMP}"
elif [[ "${OUTPUT_DIR}" != /* ]]; then
  OUTPUT_DIR="${PROJECT_ROOT}/${OUTPUT_DIR}"
fi

mkdir -p "${OUTPUT_DIR}"

ROLES_FILE="${OUTPUT_DIR}/${PREFIX}-roles.sql"
SCHEMA_FILE="${OUTPUT_DIR}/${PREFIX}-schema.sql"
DATA_FILE="${OUTPUT_DIR}/${PREFIX}-data.sql"
HISTORY_SCHEMA_FILE="${OUTPUT_DIR}/${PREFIX}-history-schema.sql"
HISTORY_DATA_FILE="${OUTPUT_DIR}/${PREFIX}-history-data.sql"

echo "Writing backup files to: ${OUTPUT_DIR}"

supabase db dump --linked -f "${ROLES_FILE}" --role-only
supabase db dump --linked -f "${SCHEMA_FILE}"
supabase db dump --linked -f "${DATA_FILE}" --use-copy --data-only

if [[ "${INCLUDE_HISTORY}" == "true" ]]; then
  supabase db dump --linked -f "${HISTORY_SCHEMA_FILE}" --schema supabase_migrations
  supabase db dump --linked -f "${HISTORY_DATA_FILE}" --use-copy --data-only --schema supabase_migrations
fi

echo "Backup completed:"
echo "  ${ROLES_FILE}"
echo "  ${SCHEMA_FILE}"
echo "  ${DATA_FILE}"
if [[ "${INCLUDE_HISTORY}" == "true" ]]; then
  echo "  ${HISTORY_SCHEMA_FILE}"
  echo "  ${HISTORY_DATA_FILE}"
fi
