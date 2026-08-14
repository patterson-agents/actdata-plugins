#!/bin/sh
# verify-all.sh -- the single gate-battery entry point for actdata-plugins.
#
# Runs every discovered test suite, the skill-name-equals-directory invariant, the
# marketplace-registration and version-consistency invariants, the no-binaries and
# size-budget validators, and the "no expanded ${CLAUDE_PLUGIN_ROOT}" grep. Both CI
# (.github/workflows/ci.yml) and .githooks/pre-commit call this script; it is the one
# place the repository's invariants are defined.
#
# Adapted from patterson-corp/scripts/verify-all.sh. The Patterson-specific steps (the
# design-tokens theme round-trip and the brand forbidden-string greps) are deliberately
# absent -- this repository ships no design tokens and no brand assets. The
# marketplace-registration check in step 4 is new here.
#
# POSIX sh only. Usage: sh scripts/verify-all.sh   (from anywhere; resolves its own path)
# Exit: 0 only if every component below passes.
set -u

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
cd "$ROOT" || exit 2

overall=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; overall=1; }

echo "== actdata-plugins verify-all =="
echo "root: $ROOT"

# ---------------------------------------------------------------------------
# 1. Every test suite, discovered dynamically. Repository-wide so a suite added by any
#    plugin is included without editing this file. node_modules and .git are pruned --
#    a vendored dependency's own test harness is not this repository's to run.
# ---------------------------------------------------------------------------
suite_count=0
suite_fail=0
for suite in $(find . -path ./.git -prune -o -name node_modules -prune -o -path ./.tmp -prune -o -name 'run-tests.sh' -print | sort); do
  suite_count=$((suite_count + 1))
  echo "--- suite: $suite ---"
  if sh "$suite"; then
    :
  else
    suite_fail=$((suite_fail + 1))
  fi
done
if [ "$suite_count" -eq 0 ]; then
  fail "test suites (none found -- expected at least one run-tests.sh)"
elif [ "$suite_fail" -eq 0 ]; then
  pass "test suites ($suite_count suite(s), all green)"
else
  fail "test suites ($suite_fail of $suite_count suite(s) failed)"
fi

# ---------------------------------------------------------------------------
# 2. Skill name == directory name, scanned under plugins/ ONLY.
#    This is the invariant that catches a skill imported from elsewhere: Title Case
#    frontmatter names (`name: Plugin Structure`) are common outside this repository and
#    silently break skill resolution here.
# ---------------------------------------------------------------------------
skill_mismatch=0
skill_count=0
for skill_md in plugins/*/skills/*/SKILL.md; do
  [ -f "$skill_md" ] || continue
  skill_count=$((skill_count + 1))
  dir_name=$(basename "$(dirname "$skill_md")")
  frontmatter_name=$(sed -n '1,20p' "$skill_md" | grep -m1 '^name:' | sed 's/^name:[[:space:]]*//')
  if [ "$dir_name" != "$frontmatter_name" ]; then
    echo "  mismatch: $skill_md (dir=$dir_name, name=$frontmatter_name)"
    skill_mismatch=$((skill_mismatch + 1))
  fi
done
if [ "$skill_mismatch" -eq 0 ]; then
  pass "skill name == directory ($skill_count skill(s) under plugins/)"
else
  fail "skill name == directory ($skill_mismatch mismatch(es))"
fi

# ---------------------------------------------------------------------------
# 3. Plugin manifests are well-formed JSON and their name matches their directory.
# ---------------------------------------------------------------------------
manifest_bad=0
manifest_count=0
for manifest in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$manifest" ] || continue
  manifest_count=$((manifest_count + 1))
  plugin_dir=$(basename "$(dirname "$(dirname "$manifest")")")
  if ! declared=$(bun -e '
    const fs = require("node:fs");
    try {
      const m = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      process.stdout.write(String(m.name ?? ""));
    } catch (e) {
      process.stderr.write(String(e.message));
      process.exit(1);
    }
  ' "$manifest" 2>&1); then
    echo "  unparseable: $manifest ($declared)"
    manifest_bad=$((manifest_bad + 1))
    continue
  fi
  if [ "$declared" != "$plugin_dir" ]; then
    echo "  name mismatch: $manifest (dir=$plugin_dir, name=$declared)"
    manifest_bad=$((manifest_bad + 1))
  fi
done
if [ "$manifest_bad" -eq 0 ]; then
  pass "plugin manifests ($manifest_count manifest(s) parse, name == directory)"
else
  fail "plugin manifests ($manifest_bad problem(s))"
fi

# ---------------------------------------------------------------------------
# 4. Marketplace registration and version consistency.
#    A plugin that exists on disk but is missing from marketplace.json is invisible to
#    `claude plugin install`, and a version that disagrees between plugin.json and the
#    marketplace entry means the advertised version is not the installed one. Both are
#    silent failures at install time, which is why they are gated here.
# ---------------------------------------------------------------------------
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
if [ ! -f "$MARKETPLACE" ]; then
  fail "marketplace registration (.claude-plugin/marketplace.json not found)"
else
  if bun -e '
    const fs = require("node:fs");
    const path = require("node:path");
    const root = process.argv[1];
    const mp = JSON.parse(fs.readFileSync(path.join(root, ".claude-plugin/marketplace.json"), "utf8"));
    const entries = new Map((mp.plugins ?? []).map((p) => [p.name, p]));
    const pluginsDir = path.join(root, "plugins");
    const problems = [];
    let checked = 0;

    // A plugin still carrying the `claude plugin init` TODO placeholders is a draft. It is
    // CORRECT for a draft to be unregistered -- registering it would ship "TODO -- describe
    // WHEN Claude should use this" to users. Drafts are reported, not failed. Every other
    // consistency rule below still applies to them if they are registered anyway.
    const isDraft = (dir) => {
      const scan = (p) => {
        for (const e of fs.readdirSync(p, { withFileTypes: true })) {
          if (e.name === "node_modules" || e.name === ".git") continue;
          const full = path.join(p, e.name);
          if (e.isDirectory()) { if (scan(full)) return true; continue; }
          if (!e.name.endsWith(".md")) continue;
          if (/TODO — |TODO: |TODO -- /.test(fs.readFileSync(full, "utf8"))) return true;
        }
        return false;
      };
      try { return scan(path.join(pluginsDir, dir)); } catch { return false; }
    };

    const drafts = [];

    for (const dir of fs.readdirSync(pluginsDir).sort()) {
      const manifestPath = path.join(pluginsDir, dir, ".claude-plugin/plugin.json");
      if (!fs.existsSync(manifestPath)) continue;   // an empty placeholder shell, not yet a plugin
      checked++;
      const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
      const entry = entries.get(manifest.name);
      if (!entry) {
        if (isDraft(dir)) { drafts.push(manifest.name); continue; }
        problems.push(`${manifest.name}: on disk but absent from marketplace.json`);
        continue;
      }
      if (entry.version !== manifest.version) {
        problems.push(
          `${manifest.name}: version ${manifest.version} in plugin.json but ${entry.version} in marketplace.json`,
        );
      }
      const resolved = path.resolve(root, entry.source ?? "");
      if (!fs.existsSync(resolved)) {
        problems.push(`${manifest.name}: source "${entry.source}" does not resolve`);
      }
      if (!entry.relevance) {
        problems.push(`${manifest.name}: missing required "relevance" block`);
      }
    }

    for (const [name, entry] of entries) {
      const resolved = path.resolve(root, entry.source ?? "");
      if (!fs.existsSync(path.join(resolved, ".claude-plugin/plugin.json"))) {
        problems.push(`${name}: registered in marketplace.json but has no plugin.json on disk`);
      }
    }

    for (const p of problems) process.stdout.write(`  ${p}\n`);
    for (const d of drafts) {
      process.stdout.write(`  note: ${d} is still a scaffold (TODO placeholders); correctly unregistered\n`);
    }
    process.stdout.write(
      `  (checked ${checked} plugin(s) against ${entries.size} marketplace entr(ies)` +
        `${drafts.length ? `, ${drafts.length} draft(s) skipped` : ""})\n`,
    );
    process.exit(problems.length === 0 ? 0 : 1);
  ' "$ROOT"; then
    pass "marketplace registration + version consistency"
  else
    fail "marketplace registration + version consistency"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Cross-runtime manifests and marketplaces agree.
# ---------------------------------------------------------------------------
if bun "$ROOT/scripts/check-marketplace-compat.ts" "$ROOT"; then
  pass "Claude + OpenAI + Copilot marketplace compatibility"
else
  fail "Claude + OpenAI + Copilot marketplace compatibility"
fi

# ---------------------------------------------------------------------------
# 6. No tracked binaries, no size-budget overrun. The validators have their own TDD
#    suite (scripts/tests/run-tests.sh, already run in step 1); here they run against
#    the whole repository, which is their real job.
# ---------------------------------------------------------------------------
if bun "$ROOT/scripts/check-no-binaries.ts" "$ROOT"; then
  pass "no-binaries (scripts/check-no-binaries.ts)"
else
  fail "no-binaries (scripts/check-no-binaries.ts)"
fi

if bun "$ROOT/scripts/check-size.ts" "$ROOT"; then
  pass "size budget (scripts/check-size.ts)"
else
  fail "size budget (scripts/check-size.ts)"
fi

# ---------------------------------------------------------------------------
# 7. No expanded ${CLAUDE_PLUGIN_ROOT}. An absolute filesystem path immediately followed
#    by /plugins|/skills|/hooks means some tool wrote a resolved path back into a tracked
#    file instead of leaving the token literal.
#
#    ONE documented exemption: the placeholder path "/home/user/.claude/plugin[s]/my-plugin/".
#    That string is the *negative* half of a "Wrong / Correct" pair in
#    plugins/act-plugin-dev/skills/command-development/examples/plugin-commands.md, which
#    teaches authors not to hardcode plugin paths. A cautionary example is categorically
#    different from a leaked resolved path, and this check cannot tell them apart. The
#    exemption is written as the full literal placeholder path rather than a file
#    allowlist, so a real expanded path landing in that same file is still caught.
#
#    Both the pattern below and the mention of it in this comment wrap a letter in a
#    bracket character class ("plugin[s]") purely so THIS FILE does not itself contain the
#    literal string and therefore never flags itself -- the check scans all tracked files,
#    including its own source. The class still matches the real string in target files.
# ---------------------------------------------------------------------------
EXPANDED_EXEMPT='/home/user/\.claude/plugin[s]/my-plugin/'
expanded_hits=$(git grep -nE '(/home/|/workspaces/)[^"'"'"' ]*/(plugins|skills|hooks)/' -- . 2>/dev/null \
  | grep -vE "$EXPANDED_EXEMPT" || true)
if [ -z "$expanded_hits" ]; then
  pass "no expanded \${CLAUDE_PLUGIN_ROOT}"
else
  echo "$expanded_hits" | sed 's/^/  /'
  fail "no expanded \${CLAUDE_PLUGIN_ROOT}"
fi

echo "================================"
if [ "$overall" -eq 0 ]; then
  echo "VERIFY-ALL: PASS"
else
  echo "VERIFY-ALL: FAIL"
fi
exit "$overall"
