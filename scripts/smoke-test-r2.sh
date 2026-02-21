#!/usr/bin/env bash
# Smoke test: audio-signer edge function → Cloudflare R2
#
# Verifies the full upload path end-to-end:
#   1. Sign in to Supabase
#   2. Look up the test user's first choir membership
#   3. Request a presigned PUT URL from the audio-signer edge function
#   4. PUT a tiny dummy file to R2 via that URL
#   5. Assert HTTP 200

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
CREDS_FILE="${PROJECT_ROOT}/email-credentials.txt"

# ---------------------------------------------------------------------------
# Colour codes
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ok()       { echo -e "${GREEN}✓${NC} $*"; }
fail()     { echo -e "${RED}✗${NC} $*" >&2; }
step()     { echo -e "${YELLOW}→${NC} $*"; }
die()      { fail "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Step 0: Load credentials
# ---------------------------------------------------------------------------
step "Loading credentials"

if [[ ! -f "${ENV_FILE}" ]]; then
  die ".env file not found at ${ENV_FILE}"
fi
if [[ ! -f "${CREDS_FILE}" ]]; then
  die "email-credentials.txt not found at ${CREDS_FILE}"
fi

# shellcheck disable=SC2046
export $(grep -v '^#' "${ENV_FILE}" | xargs)

if [[ -z "${SUPABASE_URL:-}" ]]; then
  die "SUPABASE_URL not set in ${ENV_FILE}"
fi
if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  die "SUPABASE_ANON_KEY not set in ${ENV_FILE}"
fi

EMAIL="$(sed -n '1p' "${CREDS_FILE}")"
PASSWORD="$(sed -n '2p' "${CREDS_FILE}")"

if [[ -z "${EMAIL}" || -z "${PASSWORD}" ]]; then
  die "email-credentials.txt must have email on line 1 and password on line 2"
fi

# Strip any trailing slash from the URL so paths compose cleanly
SUPABASE_URL="${SUPABASE_URL%/}"

ok "Credentials loaded (${EMAIL})"

# ---------------------------------------------------------------------------
# Step 0b: Dependency check
# ---------------------------------------------------------------------------
step "Checking required commands"

for cmd in curl jq; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    die "Required command not found: ${cmd}  (install it and re-run)"
  fi
done

ok "curl and jq are available"

# ---------------------------------------------------------------------------
# Step 1: Sign in
# ---------------------------------------------------------------------------
step "Signing in to Supabase (${SUPABASE_URL})"

SIGNIN_RESPONSE="$(
  curl -sS -X POST \
    "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Content-Type: application/json" \
    --data "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}"
)"

ACCESS_TOKEN="$(echo "${SIGNIN_RESPONSE}" | jq -r '.access_token // empty')"

if [[ -z "${ACCESS_TOKEN}" ]]; then
  ERROR_MSG="$(echo "${SIGNIN_RESPONSE}" | jq -r '.error_description // .msg // .message // "unknown error"')"
  fail "Sign-in failed: ${ERROR_MSG}"
  echo "  Full response: ${SIGNIN_RESPONSE}" >&2
  exit 1
fi

ok "Signed in successfully"

# ---------------------------------------------------------------------------
# Step 2: Look up first choir membership
# ---------------------------------------------------------------------------
step "Looking up first choir membership"

MEMBERS_RESPONSE="$(
  curl -sS -X GET \
    "${SUPABASE_URL}/rest/v1/choir_members?select=choir_id&limit=1" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}"
)"

CHOIR_ID="$(echo "${MEMBERS_RESPONSE}" | jq -r '.[0].choir_id // empty')"

if [[ -z "${CHOIR_ID}" ]]; then
  fail "No choir membership found for this user"
  echo "  Response: ${MEMBERS_RESPONSE}" >&2
  die "The test account must belong to at least one choir"
fi

ok "Choir ID: ${CHOIR_ID}"

# ---------------------------------------------------------------------------
# Step 3: Request presigned PUT URL from audio-signer
# ---------------------------------------------------------------------------
TIMESTAMP="$(date +%s)"
TRACK_ID="smoke-test-${TIMESTAMP}"

step "Requesting presigned PUT URL (trackId: ${TRACK_ID})"

SIGNER_RESPONSE="$(
  curl -sS -X POST \
    "${SUPABASE_URL}/functions/v1/audio-signer/upload" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "{\"choirId\":\"${CHOIR_ID}\",\"trackId\":\"${TRACK_ID}\",\"extension\":\".mp3\",\"contentType\":\"audio/mpeg\"}"
)"

PRESIGNED_URL="$(echo "${SIGNER_RESPONSE}" | jq -r '.url // empty')"
OBJECT_KEY="$(echo "${SIGNER_RESPONSE}" | jq -r '.objectKey // empty')"

if [[ -z "${PRESIGNED_URL}" || -z "${OBJECT_KEY}" ]]; then
  ERROR_MSG="$(echo "${SIGNER_RESPONSE}" | jq -r '.error // "unknown error"')"
  fail "audio-signer failed: ${ERROR_MSG}"
  echo "  Full response: ${SIGNER_RESPONSE}" >&2
  exit 1
fi

ok "Presigned URL received"
echo "     Object key: ${OBJECT_KEY}"

# ---------------------------------------------------------------------------
# Step 4: Write dummy file and PUT to R2
# ---------------------------------------------------------------------------
TMPFILE="$(mktemp /tmp/smoke-test-r2-XXXXXX.mp3)"
# Tiny placeholder — R2 accepts any bytes; MP3 content is not validated
printf '\xff\xfb\x90\x00\x00\x00\x00\x00' > "${TMPFILE}"

step "Uploading dummy file to R2 via presigned URL"

HTTP_STATUS="$(
  curl -sS -o /dev/null -w "%{http_code}" \
    -X PUT "${PRESIGNED_URL}" \
    -H "Content-Type: audio/mpeg" \
    --data-binary "@${TMPFILE}"
)"

rm -f "${TMPFILE}"

# ---------------------------------------------------------------------------
# Step 5: Assert success
# ---------------------------------------------------------------------------
echo ""
if [[ "${HTTP_STATUS}" == "200" ]]; then
  ok "R2 PUT succeeded (HTTP ${HTTP_STATUS})"
  echo ""
  echo -e "${GREEN}✓ Smoke test passed${NC}"
  echo ""
  echo "  Object key : ${OBJECT_KEY}"
  echo ""
  echo "  NOTE: This test object has no matching database row, so the"
  echo "  audio-signer /delete endpoint cannot authorise its removal."
  echo "  To clean up, delete it manually from the Cloudflare R2 dashboard,"
  echo "  or leave it (it is only a few bytes)."
else
  fail "R2 PUT failed with HTTP status: ${HTTP_STATUS}"
  echo ""
  echo -e "${RED}✗ Smoke test failed${NC}"
  exit 1
fi
