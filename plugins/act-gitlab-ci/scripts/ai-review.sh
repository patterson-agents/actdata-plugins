#!/bin/sh
# =============================================================================
# ai-review -- run the review rubric over a local diff with whatever AI engine
# is installed, and print the findings.
#
# The engine-agnostic harness for scripted surfaces: git hooks, ad-hoc runs,
# and anywhere the GitLab CI wrapper (post-mr-review.ts) does not apply. It
# never talks to GitLab; it reviews a local diff and reports to stdout.
#
# Usage:
#   ai-review.sh [git diff arguments]        # default: git diff HEAD
#   ai-review.sh origin/main...HEAD          # a pre-push style range
#
# Environment:
#   AI_REVIEW_ENGINE       docker-agent | claude | codex | copilot
#                          (default: first of those found on PATH)
#   AI_REVIEW_ENGINE_CMD   full command run via sh -c, prompt on stdin;
#                          overrides AI_REVIEW_ENGINE entirely
#   AI_REVIEW_ENGINE_FLAGS safety flags for docker-agent (default:
#                          --safety restricted)
#   AI_REVIEW_AGENT_CONFIG docker-agent config path (default:
#                          review-agent.yaml next to this script)
#   AI_REVIEW_RUBRIC       rubric path (default: review-rubric.md next to
#                          this script, then the plugin skill copy)
#   AI_REVIEW_MAX_TURNS    turn cap for CLI engines (default 25)
#   AI_REVIEW_DIFF_FILE    read the diff from a file instead of running git
#   AI_REVIEW_BLOCKING     "1" exits 1 when a blocker is found (for hooks
#                          that gate; default advisory)
#
# Exit: 0 review printed (or empty diff), 1 engine/contract failure or a
#       blocker under AI_REVIEW_BLOCKING=1, 2 configuration error.
# =============================================================================

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

err() { printf 'ai-review: %s\n' "$1" >&2; }

# --- locate the rubric -------------------------------------------------------

RUBRIC="${AI_REVIEW_RUBRIC:-}"
if [ -z "$RUBRIC" ]; then
  for candidate in \
    "$SCRIPT_DIR/review-rubric.md" \
    "$SCRIPT_DIR/../skills/mr-review-agent/references/review-rubric.md"; do
    if [ -f "$candidate" ]; then RUBRIC="$candidate"; break; fi
  done
fi
if [ -z "$RUBRIC" ] || [ ! -f "$RUBRIC" ]; then
  err "rubric not found; set AI_REVIEW_RUBRIC"
  exit 2
fi

# --- collect the diff --------------------------------------------------------

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/ai-review.XXXXXX") || exit 2
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

DIFF_FILE="$WORKDIR/diff.patch"
if [ -n "${AI_REVIEW_DIFF_FILE:-}" ]; then
  cp "$AI_REVIEW_DIFF_FILE" "$DIFF_FILE" || exit 2
elif [ $# -gt 0 ]; then
  git diff --no-color "$@" >"$DIFF_FILE" || { err "git diff failed"; exit 2; }
else
  git diff --no-color HEAD >"$DIFF_FILE" || { err "git diff failed"; exit 2; }
fi

if [ ! -s "$DIFF_FILE" ]; then
  echo "ai-review: empty diff, nothing to review."
  exit 0
fi

# --- build the prompt --------------------------------------------------------

PROMPT_FILE="$WORKDIR/prompt.md"
{
  cat "$RUBRIC"
  printf '\n\nRespond with ONLY the findings-contract JSON object. No prose before or after it.\n'
  printf '\nDiff under review:\n```diff\n'
  cat "$DIFF_FILE"
  printf '```\n'
} >"$PROMPT_FILE"

# --- pick and run the engine -------------------------------------------------
# The engine reviews untrusted diff content; run it with no GitLab credentials
# in its environment.

OUT_FILE="$WORKDIR/engine-output.txt"
MAX_TURNS="${AI_REVIEW_MAX_TURNS:-25}"

run_engine() {
  if [ -n "${AI_REVIEW_ENGINE_CMD:-}" ]; then
    GITLAB_TOKEN= GITLAB_ACCESS_TOKEN= CI_JOB_TOKEN= sh -c "$AI_REVIEW_ENGINE_CMD" <"$PROMPT_FILE" >"$OUT_FILE" 2>"$WORKDIR/engine-stderr.txt"
    return $?
  fi

  engine="${AI_REVIEW_ENGINE:-}"
  if [ -z "$engine" ]; then
    for candidate in docker-agent claude codex copilot; do
      if command -v "$candidate" >/dev/null 2>&1; then engine="$candidate"; break; fi
    done
  fi
  if [ -z "$engine" ]; then
    err "no engine found (docker-agent, claude, codex or copilot); set AI_REVIEW_ENGINE_CMD"
    return 2
  fi

  case "$engine" in
    docker-agent)
      config="${AI_REVIEW_AGENT_CONFIG:-$SCRIPT_DIR/review-agent.yaml}"
      [ -f "$config" ] || config="$SCRIPT_DIR/../skills/mr-review-agent/examples/review-agent.yaml"
      # shellcheck disable=SC2086 -- flags are deliberately word-split
      GITLAB_TOKEN= GITLAB_ACCESS_TOKEN= CI_JOB_TOKEN= TELEMETRY_ENABLED=false \
        docker-agent run --exec "$config" --json ${AI_REVIEW_ENGINE_FLAGS:---safety restricted} - \
        <"$PROMPT_FILE" >"$OUT_FILE" 2>"$WORKDIR/engine-stderr.txt"
      ;;
    claude)
      GITLAB_TOKEN= GITLAB_ACCESS_TOKEN= CI_JOB_TOKEN= \
        claude -p --output-format json --max-turns "$MAX_TURNS" --allowedTools "Read Grep Glob" \
        <"$PROMPT_FILE" >"$OUT_FILE" 2>"$WORKDIR/engine-stderr.txt"
      ;;
    codex)
      # Best effort: verify flags against `codex exec --help` for the
      # installed version; override with AI_REVIEW_ENGINE_CMD on drift.
      GITLAB_TOKEN= GITLAB_ACCESS_TOKEN= CI_JOB_TOKEN= \
        codex exec --json <"$PROMPT_FILE" >"$OUT_FILE" 2>"$WORKDIR/engine-stderr.txt"
      ;;
    copilot)
      # Best effort: verify flags against `copilot --help` for the installed
      # version; override with AI_REVIEW_ENGINE_CMD on drift.
      GITLAB_TOKEN= GITLAB_ACCESS_TOKEN= CI_JOB_TOKEN= \
        copilot -p "$(cat "$PROMPT_FILE")" >"$OUT_FILE" 2>"$WORKDIR/engine-stderr.txt"
      ;;
    *)
      err "unknown AI_REVIEW_ENGINE \"$engine\""
      return 2
      ;;
  esac
}

run_engine
engine_status=$?
if [ "$engine_status" -eq 2 ]; then
  exit 2
fi
if [ ! -s "$OUT_FILE" ]; then
  err "engine produced no output (exit $engine_status)"
  [ -s "$WORKDIR/engine-stderr.txt" ] && cat "$WORKDIR/engine-stderr.txt" >&2
  exit 1
fi

# --- report ------------------------------------------------------------------
# Prefer the wrapper's parser (same contract as CI); fall back to a raw dump
# plus a grep when bun is not installed.

EXTRACTOR="$SCRIPT_DIR/post-mr-review.ts"
if command -v bun >/dev/null 2>&1 && [ -f "$EXTRACTOR" ]; then
  if [ "${AI_REVIEW_BLOCKING:-0}" = "1" ]; then
    bun "$EXTRACTOR" --extract "$OUT_FILE" --report --blocking
  else
    bun "$EXTRACTOR" --extract "$OUT_FILE" --report
  fi
  exit $?
fi

cat "$OUT_FILE"
if [ "${AI_REVIEW_BLOCKING:-0}" = "1" ] &&
  grep -Eq '"severity"[[:space:]]*:[[:space:]]*"blocker"' "$OUT_FILE"; then
  err "blocker finding present"
  exit 1
fi
exit 0
