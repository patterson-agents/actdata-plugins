#!/bin/sh
# =============================================================================
# Tests for post-mr-review.ts and ai-review.sh.
#
# Fixture-driven throughout: no network, no GitLab, no real engines. The
# wrapper's pure functions are covered by unit.test.ts under `bun test`; this
# suite covers the CLI contract, the dry-run action planning, and the shell
# harness with a stub engine. scripts/verify-all.sh discovers and runs this
# file, so a regression fails the repository gate.
# =============================================================================

set -u

SUITE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR=$(CDPATH= cd -- "$SUITE_DIR/../../.." && pwd)
WRAPPER="$PLUGIN_DIR/scripts/post-mr-review.ts"
HARNESS="$PLUGIN_DIR/scripts/ai-review.sh"
FIXTURES="$SUITE_DIR/fixtures"

passed=0
failed=0

pass() { passed=$((passed + 1)); printf '  ok   %s\n' "$1"; }
fail() { failed=$((failed + 1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }

echo "post-mr-review.ts / ai-review.sh"

for f in "$WRAPPER" "$HARNESS"; do
  if [ ! -f "$f" ]; then
    fail "exists: $f"
    echo "  $passed passed, $failed failed"
    exit 1
  fi
done
pass "wrapper and harness exist"

if ! command -v bun >/dev/null 2>&1; then
  echo "  note: bun not installed; skipping execution tests"
  echo "  $passed passed, $failed failed"
  [ "$failed" -eq 0 ] || exit 1
  exit 0
fi

TMPDIR_LOCAL="$PLUGIN_DIR/../../.tmp"
mkdir -p "$TMPDIR_LOCAL"
WORK=$(mktemp -d "$TMPDIR_LOCAL/mr-review-tests.XXXXXX") || exit 1
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# --- unit tests ---------------------------------------------------------------

if bun test "$SUITE_DIR/unit.test.ts" >"$WORK/unit.log" 2>&1; then
  pass "unit.test.ts suite"
else
  fail "unit.test.ts suite" "$(tail -5 "$WORK/unit.log")"
fi

# --- --extract contract --------------------------------------------------------

out=$(bun "$WRAPPER" --extract "$FIXTURES/transcript.ndjson" 2>&1)
if [ $? -eq 0 ] && printf '%s' "$out" | grep -q '"findings"'; then
  pass "--extract parses a docker-agent transcript"
else
  fail "--extract parses a docker-agent transcript" "$out"
fi

out=$(bun "$WRAPPER" --extract "$FIXTURES/claude-output.json" --report 2>&1)
if [ $? -eq 0 ] && printf '%s' "$out" | grep -q 'Retry loop has no upper bound'; then
  pass "--extract --report renders a claude result"
else
  fail "--extract --report renders a claude result" "$out"
fi

if bun "$WRAPPER" --extract "$FIXTURES/transcript.ndjson" --report --blocking >/dev/null 2>&1; then
  fail "--blocking exits 1 on a blocker"
else
  pass "--blocking exits 1 on a blocker"
fi

if bun "$WRAPPER" --extract "$FIXTURES/claude-output.json" --blocking >/dev/null 2>&1; then
  pass "--blocking exits 0 with no blocker"
else
  fail "--blocking exits 0 with no blocker"
fi

if bun "$WRAPPER" --extract "$FIXTURES/transcript-malformed.ndjson" >/dev/null 2>&1; then
  fail "malformed transcript exits non-zero"
else
  pass "malformed transcript exits non-zero"
fi

# --- dry-run: inline mode over fixtures ----------------------------------------

run_dry() {
  # $1 head sha, $2 mode, $3 token ("" for none), remaining env via caller
  AI_REVIEW_DRY_RUN=1 \
  GITLAB_TOKEN="$3" \
  AI_REVIEW_MODE="$2" \
  CI_API_V4_URL="https://gitlab.example.com/api/v4" \
  CI_PROJECT_ID="123" \
  CI_MERGE_REQUEST_IID="7" \
  CI_MERGE_REQUEST_SOURCE_BRANCH_SHA="$1" \
  AI_REVIEW_FIXTURE_CHANGES="$FIXTURES/mr-changes.json" \
  AI_REVIEW_FIXTURE_NOTES="$FIXTURES/notes-with-marker.json" \
  AI_REVIEW_FIXTURE_DISCUSSIONS="$FIXTURES/discussions-stale.json" \
  AI_REVIEW_FIXTURE_OUTPUT="$FIXTURES/transcript.ndjson" \
  AI_REVIEW_ARTIFACTS="$WORK/artifacts" \
  bun "$WRAPPER" 2>"$WORK/dry-stderr.txt"
}

HEAD_SHA="beefbeefbeefbeefbeefbeefbeefbeefbeefbeef"

out=$(run_dry "$HEAD_SHA" inline fake-token)
status=$?

if [ "$status" -eq 0 ]; then
  pass "dry-run inline exits 0"
else
  fail "dry-run inline exits 0" "exit $status: $(cat "$WORK/dry-stderr.txt")"
fi

count=$(printf '%s\n' "$out" | grep -c '"path":"/discussions"')
if [ "$count" -eq 2 ]; then
  pass "dry-run inline plans one discussion per finding"
else
  fail "dry-run inline plans one discussion per finding" "saw $count: $out"
fi

if printf '%s' "$out" | grep -q '"path":"/discussions/d1f2e3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0"'; then
  pass "dry-run inline resolves the stale bot thread"
else
  fail "dry-run inline resolves the stale bot thread" "$out"
fi

if printf '%s' "$out" | grep -q '"path":"/notes/101"'; then
  pass "dry-run inline updates the sticky summary note"
else
  fail "dry-run inline updates the sticky summary note" "$out"
fi

if printf '%s' "$out" | grep -q '"new_line":42'; then
  pass "dry-run inline carries the diff position"
else
  fail "dry-run inline carries the diff position" "$out"
fi

if [ -f "$WORK/artifacts/findings.json" ] && [ -f "$WORK/artifacts/review.md" ]; then
  pass "dry-run writes findings.json and review.md artifacts"
else
  fail "dry-run writes findings.json and review.md artifacts"
fi

# --- dry-run: pipeline retry is a no-op ----------------------------------------

out=$(run_dry "abc123abc123" inline fake-token)
if [ $? -eq 0 ] && printf '%s' "$out" | grep -q 'already reviewed'; then
  pass "same-head retry is a no-op"
else
  fail "same-head retry is a no-op" "$out"
fi

# --- dry-run: no token downgrades to log mode ----------------------------------

out=$(run_dry "$HEAD_SHA" inline "")
if [ $? -eq 0 ] &&
  grep -q 'falling back to log mode' "$WORK/dry-stderr.txt" &&
  printf '%s' "$out" | grep -q '\[BLOCKER\]'; then
  pass "missing token downgrades inline to log with a notice"
else
  fail "missing token downgrades inline to log with a notice" "$out $(cat "$WORK/dry-stderr.txt")"
fi

# --- harness: stub engine -------------------------------------------------------

printf 'diff --git a/src/app.ts b/src/app.ts\n--- a/src/app.ts\n+++ b/src/app.ts\n@@ -1 +1 @@\n+changed\n' >"$WORK/stub.diff"

out=$(TMPDIR="$WORK" \
  AI_REVIEW_DIFF_FILE="$WORK/stub.diff" \
  AI_REVIEW_ENGINE_CMD="sh $FIXTURES/stub-engine.sh" \
  sh "$HARNESS" 2>&1)
if [ $? -eq 0 ] && printf '%s' "$out" | grep -q 'Stub blocker finding'; then
  pass "harness reports stub engine findings"
else
  fail "harness reports stub engine findings" "$out"
fi

if TMPDIR="$WORK" \
  AI_REVIEW_DIFF_FILE="$WORK/stub.diff" \
  AI_REVIEW_ENGINE_CMD="sh $FIXTURES/stub-engine.sh" \
  AI_REVIEW_BLOCKING=1 \
  sh "$HARNESS" >/dev/null 2>&1; then
  fail "harness blocking mode exits 1 on a blocker"
else
  pass "harness blocking mode exits 1 on a blocker"
fi

: >"$WORK/empty.diff"
out=$(TMPDIR="$WORK" AI_REVIEW_DIFF_FILE="$WORK/empty.diff" sh "$HARNESS" 2>&1)
if [ $? -eq 0 ] && printf '%s' "$out" | grep -q 'empty diff'; then
  pass "harness exits 0 on an empty diff"
else
  fail "harness exits 0 on an empty diff" "$out"
fi

echo "  $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
