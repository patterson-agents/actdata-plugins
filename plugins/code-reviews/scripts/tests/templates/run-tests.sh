#!/bin/sh
# =============================================================================
# Template and cross-reference checks for the code-reviews plugin.
#
# This plugin ships no runtime -- every surface uses its host's own harness --
# so there is nothing to unit test. What can rot is the shipped configuration:
# a YAML template that stops parsing, an instructions file missing the
# frontmatter Copilot requires, or a SKILL.md naming a reference that no longer
# exists. Those are what this suite pins.
#
# scripts/verify-all.sh discovers and runs this file.
# =============================================================================

set -u

SUITE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_DIR=$(CDPATH= cd -- "$SUITE_DIR/../../.." && pwd)

passed=0
failed=0

pass() { passed=$((passed + 1)); printf '  ok   %s\n' "$1"; }
fail() { failed=$((failed + 1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }

echo "code-reviews templates"

# --- the plugin ships no runtime ---------------------------------------------
# The whole point of the design. If a script reappears here, either the design
# changed and this test should be deleted deliberately, or something crept back.

runtime=$(find "$PLUGIN_DIR" -name '*.ts' -o -name '*.py' | grep -v '/tests/' || true)
if [ -z "$runtime" ]; then
  pass "plugin ships no runtime code"
else
  fail "plugin ships no runtime code" "$runtime"
fi

# --- skills exist -------------------------------------------------------------

for skill in review install; do
  if [ -f "$PLUGIN_DIR/skills/$skill/SKILL.md" ]; then
    pass "skills/$skill/SKILL.md exists"
  else
    fail "skills/$skill/SKILL.md exists"
  fi
done

# --- instructions files carry the frontmatter Copilot requires ----------------

for f in $(find "$PLUGIN_DIR" -name '*.instructions.md'); do
  name=$(basename "$f")
  head1=$(head -1 "$f")
  if [ "$head1" != "---" ]; then
    fail "$name opens with frontmatter" "first line: $head1"
    continue
  fi
  front=$(sed -n '2,/^---$/p' "$f")
  missing=""
  for key in description applyTo; do
    printf '%s' "$front" | grep -q "^$key:" || missing="$missing $key"
  done
  if [ -z "$missing" ]; then
    pass "$name has description and applyTo"
  else
    fail "$name has description and applyTo" "missing:$missing"
  fi
done

# --- YAML templates parse -----------------------------------------------------

if command -v bun >/dev/null 2>&1; then
  for f in $(find "$PLUGIN_DIR/skills" -name '*.yml' -o -name '*.yaml'); do
    name=$(basename "$f")
    if err=$(bun -e '
      import { readFileSync } from "node:fs";
      Bun.YAML.parse(readFileSync(process.argv[1], "utf8"));
    ' "$f" 2>&1); then
      pass "$name parses as YAML"
    else
      fail "$name parses as YAML" "$err"
    fi
  done
else
  echo "  note: bun not installed; skipping YAML parse checks"
fi

# --- every referenced resource exists ----------------------------------------
# Catches a SKILL.md or reference naming a file that was renamed or removed.

for skill_md in "$PLUGIN_DIR"/skills/*/SKILL.md; do
  skill_dir=$(dirname "$skill_md")
  skill_name=$(basename "$skill_dir")
  refs=$(grep -o '`\(references\|templates\)/[A-Za-z0-9._-]*`' "$skill_md" | tr -d '`' | sort -u)
  for ref in $refs; do
    if [ -e "$skill_dir/$ref" ]; then
      pass "$skill_name references $ref"
    else
      fail "$skill_name references $ref" "no such file"
    fi
  done
done

# --- shell templates are valid POSIX sh --------------------------------------

for f in "$PLUGIN_DIR"/skills/install/templates/pre-push; do
  [ -f "$f" ] || continue
  if sh -n "$f" 2>/dev/null; then
    pass "$(basename "$f") is valid sh"
  else
    fail "$(basename "$f") is valid sh"
  fi
done

echo "  $passed passed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
