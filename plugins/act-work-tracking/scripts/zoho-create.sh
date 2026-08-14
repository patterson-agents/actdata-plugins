#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# zoho-create -- create Zoho Projects tasks and issues from a JSON file
#
# Tasks are high-level categories. Issues are concrete actionable work items.
# Issues are created through the bugs API; that is a Zoho naming quirk, not a
# mistake.
#
# SETUP (one time, Self Client flow, no web server needed):
#
#   1. Go to https://api-console.zoho.com
#   2. Add Client, choose "Self Client"
#   3. Note the Client ID and Client Secret
#   4. Under "Generate Code", paste these scopes:
#        ZohoProjects.portals.READ,
#        ZohoProjects.projects.READ,
#        ZohoProjects.tasks.CREATE,
#        ZohoProjects.tasks.READ,
#        ZohoBugTracker.bugs.CREATE,
#        ZohoBugTracker.bugs.READ
#   5. Set a duration (10 minutes is plenty) and click Create
#   6. Copy the grant code and immediately run this, it expires in 2 minutes:
#
#        curl -X POST "https://accounts.zoho.com/oauth/v2/token" \
#          -d "code=PASTE_GRANT_CODE" \
#          -d "client_id=YOUR_CLIENT_ID" \
#          -d "client_secret=YOUR_CLIENT_SECRET" \
#          -d "grant_type=authorization_code"
#
#   7. Store the refresh_token from the response as a secret. It does not expire.
#
# AUTH:
#   The header is "Authorization: Zoho-oauthtoken {access_token}", NOT the
#   standard Bearer prefix. Access tokens last an hour; this script refreshes
#   one automatically at the start of a live run.
#
# ENV VARS (required for a live run, not read at all under --dry-run):
#   ZOHO_CLIENT_ID
#   ZOHO_CLIENT_SECRET
#   ZOHO_REFRESH_TOKEN
#   ZOHO_PORTAL_ID
#   ZOHO_PROJECT_ID
#
# ENV VARS (optional):
#   ZOHO_ACCOUNTS_DOMAIN   default: https://accounts.zoho.com
#   ZOHO_API_DOMAIN        default: https://projectsapi.zoho.com
#
#   Regional data centres use different top-level domains (.eu, .in, .com.au).
#   A token issued in one region does not work against another, and the error
#   does not say so.
#
# USAGE:
#   ./zoho-create.sh items.json
#   ./zoho-create.sh --dry-run items.json
#   ./zoho-create.sh items.json --dry-run
#
# INPUT FORMAT:
#   [
#     {
#       "type": "task",
#       "title": "Category name",
#       "description": "High-level summary.",
#       "priority": "High"
#     },
#     {
#       "type": "issue",
#       "title": "Concrete work item",
#       "description": "Detail. Use <br> for line breaks; newlines do not render."
#     }
#   ]
#
#   JSON only. CSV input was removed: the conversion required an interpreter
#   this repository does not permit, and quoting rules made it a reliable source
#   of malformed descriptions.
#
# DEPENDENCIES: curl, jq
# =============================================================================

# --- Arguments ---------------------------------------------------------------
# Parsed before any configuration is read, so that --dry-run works with no
# credentials present. The test suite and CI depend on this.

DRY_RUN=false
INPUT_FILE=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      sed -n '3,78p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "ERROR: unknown option: $arg" >&2
      echo "Usage: $0 [--dry-run] <file.json>" >&2
      exit 1
      ;;
    *)
      if [[ -n "$INPUT_FILE" ]]; then
        echo "ERROR: more than one input file given: $INPUT_FILE and $arg" >&2
        exit 1
      fi
      INPUT_FILE="$arg"
      ;;
  esac
done

if [[ -z "$INPUT_FILE" ]]; then
  echo "Usage: $0 [--dry-run] <file.json>" >&2
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "ERROR: file not found: $INPUT_FILE" >&2
  exit 1
fi

case "${INPUT_FILE##*.}" in
  json|JSON) ;;
  *)
    echo "ERROR: unsupported file type. JSON only." >&2
    exit 1
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required. Install with: apt install jq / brew install jq" >&2
  exit 1
fi

# --- Configuration -----------------------------------------------------------
# Under --dry-run nothing here is required, so the guards stay unset-tolerant
# and the placeholders are only ever printed, never sent anywhere.

if $DRY_RUN; then
  ZOHO_PORTAL_ID="${ZOHO_PORTAL_ID:-<portal id>}"
  ZOHO_PROJECT_ID="${ZOHO_PROJECT_ID:-<project id>}"
else
  ZOHO_CLIENT_ID="${ZOHO_CLIENT_ID:?Set ZOHO_CLIENT_ID}"
  ZOHO_CLIENT_SECRET="${ZOHO_CLIENT_SECRET:?Set ZOHO_CLIENT_SECRET}"
  ZOHO_REFRESH_TOKEN="${ZOHO_REFRESH_TOKEN:?Set ZOHO_REFRESH_TOKEN}"
  ZOHO_PORTAL_ID="${ZOHO_PORTAL_ID:?Set ZOHO_PORTAL_ID}"
  ZOHO_PROJECT_ID="${ZOHO_PROJECT_ID:?Set ZOHO_PROJECT_ID}"
fi

ACCOUNTS_DOMAIN="${ZOHO_ACCOUNTS_DOMAIN:-https://accounts.zoho.com}"
API_DOMAIN="${ZOHO_API_DOMAIN:-https://projectsapi.zoho.com}"

BASE_URL="${API_DOMAIN}/restapi/portal/${ZOHO_PORTAL_ID}/projects/${ZOHO_PROJECT_ID}"
TOKEN_URL="${ACCOUNTS_DOMAIN}/oauth/v2/token"

ACCESS_TOKEN=""

# Rate limit is 100 requests per 2 minutes. 1.5s between calls is conservative,
# and a bulk run that trips the limit leaves a half-created backlog behind.
RATE_LIMIT_SLEEP=1.5

# --- Functions ---------------------------------------------------------------

get_access_token() {
  local response
  response=$(curl -s -X POST "${TOKEN_URL}" \
    -d "refresh_token=${ZOHO_REFRESH_TOKEN}" \
    -d "client_id=${ZOHO_CLIENT_ID}" \
    -d "client_secret=${ZOHO_CLIENT_SECRET}" \
    -d "grant_type=refresh_token")

  ACCESS_TOKEN=$(echo "$response" | jq -r '.access_token // empty')

  if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "ERROR: failed to get an access token" >&2
    echo "$response" | jq . 2>/dev/null || echo "$response" >&2
    exit 1
  fi
  echo "Authenticated."
}

create_task() {
  local title="$1"
  local description="$2"
  local priority="${3:-None}"

  if $DRY_RUN; then
    printf "  [dry run] POST %s/tasks/\n" "$BASE_URL"
    printf "            name=%s priority=%s\n" "$title" "$priority"
    return 0
  fi

  local response key id
  response=$(curl -s -X POST "${BASE_URL}/tasks/" \
    -H "Authorization: Zoho-oauthtoken ${ACCESS_TOKEN}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "name=${title}" \
    --data-urlencode "description=${description}" \
    --data-urlencode "priority=${priority}")

  key=$(echo "$response" | jq -r '.tasks[0].key // empty')
  id=$(echo "$response" | jq -r '.tasks[0].id_string // empty')

  if [[ -n "$key" ]]; then
    printf "  TASK  %s: %s (id %s)\n" "$key" "$title" "$id"
  else
    printf "  ERROR creating task: %s\n" "$title" >&2
    echo "$response" | jq . 2>/dev/null || echo "$response" >&2
    return 1
  fi

  sleep "$RATE_LIMIT_SLEEP"
}

create_issue() {
  local title="$1"
  local description="$2"

  if $DRY_RUN; then
    printf "  [dry run] POST %s/bugs/\n" "$BASE_URL"
    printf "            title=%s\n" "$title"
    return 0
  fi

  # Note: no `flag` field. Sending it fails with an error that does not name it.
  local response key id
  response=$(curl -s -X POST "${BASE_URL}/bugs/" \
    -H "Authorization: Zoho-oauthtoken ${ACCESS_TOKEN}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "title=${title}" \
    --data-urlencode "description=${description}")

  key=$(echo "$response" | jq -r '.bugs[0].key // empty')
  id=$(echo "$response" | jq -r '.bugs[0].id_string // empty')

  if [[ -n "$key" ]]; then
    printf "  ISSUE %s: %s (id %s)\n" "$key" "$title" "$id"
  else
    printf "  ERROR creating issue: %s\n" "$title" >&2
    echo "$response" | jq . 2>/dev/null || echo "$response" >&2
    return 1
  fi

  sleep "$RATE_LIMIT_SLEEP"
}

# --- Main --------------------------------------------------------------------

echo "zoho-create"
echo "==========="
printf "Portal:  %s\n" "$ZOHO_PORTAL_ID"
printf "Project: %s\n" "$ZOHO_PROJECT_ID"
printf "Input:   %s\n" "$INPUT_FILE"
printf "Mode:    %s\n" "$($DRY_RUN && echo 'DRY RUN' || echo 'LIVE')"
echo ""

if ! ITEMS=$(jq -e '.' "$INPUT_FILE" 2>&1); then
  echo "ERROR: input is not valid JSON: $INPUT_FILE" >&2
  exit 1
fi

if [[ "$(echo "$ITEMS" | jq -r 'type')" != "array" ]]; then
  echo "ERROR: input must be a JSON array of items." >&2
  exit 1
fi

TOTAL=$(echo "$ITEMS" | jq 'length')
TASK_COUNT=0
ISSUE_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

echo "Loaded $TOTAL items."
echo ""

if ! $DRY_RUN; then
  get_access_token
fi

for i in $(seq 0 $((TOTAL - 1))); do
  type=$(echo "$ITEMS" | jq -r ".[$i].type // empty")
  title=$(echo "$ITEMS" | jq -r ".[$i].title // empty")
  description=$(echo "$ITEMS" | jq -r ".[$i].description // empty")
  priority=$(echo "$ITEMS" | jq -r ".[$i].priority // \"None\"")

  if [[ -z "$title" ]]; then
    printf "  SKIP: item %s has no title\n" "$i" >&2
    SKIP_COUNT=$((SKIP_COUNT + 1))
    continue
  fi

  case "$type" in
    task)
      if create_task "$title" "$description" "$priority"; then
        TASK_COUNT=$((TASK_COUNT + 1))
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
      ;;
    issue)
      if create_issue "$title" "$description"; then
        ISSUE_COUNT=$((ISSUE_COUNT + 1))
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
      fi
      ;;
    *)
      printf "  SKIP: unknown type '%s' for '%s'\n" "$type" "$title" >&2
      SKIP_COUNT=$((SKIP_COUNT + 1))
      ;;
  esac
done

echo ""
echo "Done. Tasks: $TASK_COUNT, Issues: $ISSUE_COUNT, Skipped: $SKIP_COUNT, Failed: $FAIL_COUNT"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
