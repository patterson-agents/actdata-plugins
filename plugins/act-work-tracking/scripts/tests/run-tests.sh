#!/bin/sh
# =============================================================================
# Tests for zoho-create.sh.
#
# The central guarantee under test: --dry-run performs no network access and
# reads no credentials, so it runs in CI where no ZOHO_* variables exist.
# scripts/verify-all.sh discovers and runs this suite, so a regression here
# fails the whole repository gate rather than surfacing later.
#
# Scratch goes in the repository's gitignored .tmp/, never a system temp
# directory: the workspace wires a PreToolUse guard that blocks those.
# =============================================================================

set -u

SUITE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR=$(CDPATH= cd -- "$SUITE_DIR/../.." && pwd)
ROOT=$(CDPATH= cd -- "$PLUGIN_DIR/../.." && pwd)
SCRIPT="$PLUGIN_DIR/scripts/zoho-create.sh"
SAMPLE="$PLUGIN_DIR/skills/zoho-projects/examples/sample-backlog.json"

mkdir -p "$ROOT/.tmp"
WORK=$(mktemp -d "$ROOT/.tmp/zoho-create-tests.XXXXXX") || exit 1
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

passed=0
failed=0

pass() { passed=$((passed + 1)); printf '  ok   %s\n' "$1"; }
fail() { failed=$((failed + 1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }

# Deliberately clear every credential so a developer's own environment cannot
# mask a regression that would fail in CI.
unset ZOHO_CLIENT_ID ZOHO_CLIENT_SECRET ZOHO_REFRESH_TOKEN \
      ZOHO_PORTAL_ID ZOHO_PROJECT_ID ZOHO_ACCOUNTS_DOMAIN ZOHO_API_DOMAIN 2>/dev/null || true

echo "zoho-create.sh"

# --- preconditions -----------------------------------------------------------

if [ ! -f "$SCRIPT" ]; then
  fail "script exists" "$SCRIPT not found"
  echo "  $passed passed, $failed failed"
  exit 1
fi
pass "script exists"

if [ -x "$SCRIPT" ]; then
  pass "script is executable"
else
  fail "script is executable" "missing the executable bit"
fi

if [ -f "$SAMPLE" ]; then
  pass "sample backlog exists"
else
  fail "sample backlog exists" "$SAMPLE not found"
fi

if command -v jq >/dev/null 2>&1; then
  HAVE_JQ=1
else
  HAVE_JQ=0
  echo "  note: jq not installed; skipping the tests that require it"
fi

# --- the guarantee: dry run needs no credentials -----------------------------

if [ "$HAVE_JQ" = 1 ] && [ -f "$SAMPLE" ]; then
  if out=$("$SCRIPT" --dry-run "$SAMPLE" 2>&1); then
    pass "dry run succeeds with no ZOHO_* variables set"

    if printf '%s' "$out" | grep -q 'DRY RUN'; then
      pass "dry run reports its mode"
    else
      fail "dry run reports its mode" "no DRY RUN marker in output"
    fi

    if printf '%s' "$out" | grep -q 'Loaded 5 items'; then
      pass "parses all sample items"
    else
      fail "parses all sample items" "expected 'Loaded 5 items'"
    fi

    if printf '%s' "$out" | grep -q 'Tasks: 2, Issues: 3'; then
      pass "counts tasks and issues separately"
    else
      fail "counts tasks and issues separately" "expected 'Tasks: 2, Issues: 3'"
    fi

    if printf '%s' "$out" | grep -q '/tasks/' && printf '%s' "$out" | grep -q '/bugs/'; then
      pass "issues route to the bugs endpoint"
    else
      fail "issues route to the bugs endpoint" "expected both /tasks/ and /bugs/ in output"
    fi
  else
    fail "dry run succeeds with no ZOHO_* variables set" "$out"
  fi

  # Argument order must not matter: both forms are documented.
  if "$SCRIPT" "$SAMPLE" --dry-run >/dev/null 2>&1; then
    pass "accepts --dry-run after the filename"
  else
    fail "accepts --dry-run after the filename"
  fi
fi

# --- argument and input validation -------------------------------------------

if "$SCRIPT" >/dev/null 2>&1; then
  fail "no arguments is an error"
else
  pass "no arguments is an error"
fi

if "$SCRIPT" --dry-run "$WORK/absent.json" >/dev/null 2>&1; then
  fail "missing file is an error"
else
  pass "missing file is an error"
fi

printf 'type,title\ntask,x\n' > "$WORK/items.csv"
if "$SCRIPT" --dry-run "$WORK/items.csv" >/dev/null 2>&1; then
  fail "CSV input is rejected"
else
  pass "CSV input is rejected"
fi

if [ "$HAVE_JQ" = 1 ]; then
  printf '{ not json' > "$WORK/broken.json"
  if "$SCRIPT" --dry-run "$WORK/broken.json" >/dev/null 2>&1; then
    fail "malformed JSON is an error"
  else
    pass "malformed JSON is an error"
  fi

  printf '{"type":"task","title":"x"}' > "$WORK/object.json"
  if "$SCRIPT" --dry-run "$WORK/object.json" >/dev/null 2>&1; then
    fail "a bare object is rejected"
  else
    pass "a bare object is rejected"
  fi

  printf '[{"type":"nonsense","title":"x","description":"y"}]' > "$WORK/unknown.json"
  if out=$("$SCRIPT" --dry-run "$WORK/unknown.json" 2>&1); then
    if printf '%s' "$out" | grep -q 'Skipped: 1'; then
      pass "an unknown type is skipped, not fatal"
    else
      fail "an unknown type is skipped, not fatal" "$out"
    fi
  else
    fail "an unknown type is skipped, not fatal" "script exited non-zero"
  fi

  printf '[{"type":"task","description":"no title here"}]' > "$WORK/untitled.json"
  if out=$("$SCRIPT" --dry-run "$WORK/untitled.json" 2>&1); then
    if printf '%s' "$out" | grep -q 'Skipped: 1'; then
      pass "an item with no title is skipped"
    else
      fail "an item with no title is skipped" "$out"
    fi
  else
    fail "an item with no title is skipped" "script exited non-zero"
  fi
fi

# --- house rules -------------------------------------------------------------
# The repository forbids Python anywhere in the tree; this script previously
# shelled out to it for CSV conversion.
if grep -qE 'python3?[[:space:]]' "$SCRIPT"; then
  fail "no Python interpreter is invoked"
else
  pass "no Python interpreter is invoked"
fi

echo "  $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
