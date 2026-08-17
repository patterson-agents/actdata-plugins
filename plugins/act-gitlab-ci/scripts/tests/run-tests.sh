#!/bin/sh
# =============================================================================
# Tests for check-pipeline.ts.
#
# Asserts the two ends of the contract: a compliant fixture exits 0, a violating
# one exits 1 with the expected rule ids. scripts/verify-all.sh discovers and
# runs this suite, so a regression fails the repository gate.
#
# The checker is deliberately a regex scanner, so these tests also pin its
# documented blind spots -- a change that "fixes" one of them silently would
# make the skill's caveats wrong.
# =============================================================================

set -u

SUITE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR=$(CDPATH= cd -- "$SUITE_DIR/../.." && pwd)
CHECKER="$PLUGIN_DIR/scripts/check-pipeline.ts"

passed=0
failed=0

pass() { passed=$((passed + 1)); printf '  ok   %s\n' "$1"; }
fail() { failed=$((failed + 1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }

echo "check-pipeline.ts"

if [ ! -f "$CHECKER" ]; then
  fail "checker exists" "$CHECKER not found"
  echo "  $passed passed, $failed failed"
  exit 1
fi
pass "checker exists"

if ! command -v node >/dev/null 2>&1; then
  echo "  note: node not installed; skipping execution tests"
  echo "  $passed passed, $failed failed"
  [ "$failed" -eq 0 ] || exit 1
  exit 0
fi

# --- compliant fixture -------------------------------------------------------

out=$(node "$CHECKER" "$SUITE_DIR/compliant/gitlab-ci.yml" 2>&1)
status=$?

if [ "$status" -eq 0 ]; then
  pass "compliant fixture exits 0"
else
  fail "compliant fixture exits 0" "exit $status; output: $out"
fi

if printf '%s' "$out" | grep -q '^ERROR|'; then
  fail "compliant fixture produces no ERROR findings" "$out"
else
  pass "compliant fixture produces no ERROR findings"
fi

# --- violating fixture -------------------------------------------------------

out=$(node "$CHECKER" "$SUITE_DIR/violating/gitlab-ci.yml" 2>&1)
status=$?

if [ "$status" -eq 1 ]; then
  pass "violating fixture exits 1"
else
  fail "violating fixture exits 1" "exit $status"
fi

check_rule() {
  if printf '%s' "$out" | grep -q "|$1|"; then
    pass "detects $1"
  else
    fail "detects $1" "not in output"
  fi
}

check_rule "required-scan/sast"
check_rule "required-scan/dast"
check_rule "required-scan/secret-scanning"
check_rule "container-scanner/not-approved"
check_rule "credentials/arm-client-secret"
check_rule "credentials/client-secret"
check_rule "secrets/inline-literal"
check_rule "mr-policy/approvers"
check_rule "build/one-build-many-artifacts"
check_rule "build/unit-tests"
check_rule "deploy/strategy"
check_rule "deploy/rollback"
check_rule "deploy/smoke-test"

# --- output contract ---------------------------------------------------------

if printf '%s' "$out" | head -1 | grep -qE '^(ERROR|WARN|INFO)\|[^|]*\|[0-9]+\|[^|]+\|'; then
  pass "output matches LEVEL|file|line|rule|message"
else
  fail "output matches LEVEL|file|line|rule|message" "first line: $(printf '%s' "$out" | head -1)"
fi

# --- documented blind spots --------------------------------------------------
# These assert the checker does NOT detect things, matching the caveats in the
# skill. If one starts passing, the documentation needs updating too.

TMPDIR_LOCAL="$PLUGIN_DIR/../../.tmp"
mkdir -p "$TMPDIR_LOCAL"
WORK=$(mktemp -d "$TMPDIR_LOCAL/check-pipeline-tests.XXXXXX") || exit 1
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

cat > "$WORK/included.yml" <<'YAML'
include:
  - project: 'platform/ci-templates'
    file: '/all-scans.yml'
deploy:
  script:
    - deploy
YAML

out=$(node "$CHECKER" "$WORK/included.yml" 2>&1)
if printf '%s' "$out" | grep -q 'coverage/includes-not-followed'; then
  pass "reports that include: cannot be followed"
else
  fail "reports that include: cannot be followed" "$out"
fi

if printf '%s' "$out" | grep -q 'required-scan/sast'; then
  pass "scans behind include: still read as missing (documented limitation)"
else
  fail "scans behind include: still read as missing (documented limitation)"
fi

cat > "$WORK/placeholder.yml" <<'YAML'
variables:
  DB_PASSWORD: "${VAULT_DB_PASSWORD}"
  API_KEY: "<your-api-key-here>"
YAML

out=$(node "$CHECKER" "$WORK/placeholder.yml" 2>&1)
if printf '%s' "$out" | grep -q 'secrets/inline-literal'; then
  fail "placeholders are not flagged as inline secrets" "$out"
else
  pass "placeholders are not flagged as inline secrets"
fi

# --- argument handling -------------------------------------------------------

if node "$CHECKER" >/dev/null 2>&1; then
  fail "no argument exits non-zero"
else
  [ $? -eq 2 ] && pass "no argument exits 2" || pass "no argument exits non-zero"
fi

if node "$CHECKER" "$WORK/does-not-exist.yml" >/dev/null 2>&1; then
  fail "missing target exits non-zero"
else
  pass "missing target exits non-zero"
fi

echo "  $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
