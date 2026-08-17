#!/bin/sh
# Test harness for the repository validators. POSIX sh, no dependencies.
#
# Fixtures are generated at run time into throwaway git repositories under a scratch
# directory, never committed: a real oversized tree or a real font binary living in this
# repository would itself be flagged by the very validators it tests, and would violate
# the repository's own no-binaries / size-budget rules.
#
# Scratch lives in the repository's own gitignored .tmp/, never under /tmp -- the
# Patterson house standard forbids anything being created under /tmp, and the workspace
# wires a no-tmp-guard PreToolUse hook to enforce it.
#
# Usage: ./run-tests.sh    (run from anywhere)
set -u
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$DIR/../.." && pwd)
SIZE_CHECK="$DIR/../check-size.ts"
BIN_CHECK="$DIR/../check-no-binaries.ts"
COMPAT_CHECK="$DIR/../check-marketplace-compat.ts"
fail=0

mkdir -p "$ROOT/.tmp"
WORK=$(mktemp -d "$ROOT/.tmp/furniture-tests.XXXXXX")
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# make_repo NAME -- creates $WORK/NAME as a fresh git repo, prints its path.
make_repo() {
  _name=$1
  _repo="$WORK/$_name"
  mkdir -p "$_repo"
  git -C "$_repo" init -q
  git -C "$_repo" config user.email "test@example.invalid"
  git -C "$_repo" config user.name "test"
  printf '%s\n' "$_repo"
}

# add_file REPO RELPATH BYTES -- writes a file of exactly BYTES bytes and git-adds it.
add_file() {
  _repo=$1; _rel=$2; _bytes=$3
  _full="$_repo/$_rel"
  mkdir -p "$(dirname "$_full")"
  node -e '
    const fs = require("node:fs");
    const [file, n] = process.argv.slice(1);
    fs.writeFileSync(file, Buffer.alloc(Number(n), 65));
  ' "$_full" "$_bytes"
  git -C "$_repo" add -- "$_rel" >/dev/null
}

commit_repo() {
  _repo=$1
  git -C "$_repo" commit -q -m "fixture" >/dev/null
}

expect_exit() {
  _want=$1; _script=$2; _path=$3; _label=$4
  node "$_script" "$_path" >"$WORK/out.$$" 2>"$WORK/err.$$"
  _got=$?
  if [ "$_got" -ne "$_want" ]; then
    echo "FAIL $_label: expected exit $_want, got $_got"
    cat "$WORK/out.$$" "$WORK/err.$$" 2>/dev/null
    fail=1
  else
    echo "ok   $_label (exit $_got)"
  fi
}

expect_rule() {
  _rule=$1; _script=$2; _path=$3; _label=$4
  if node "$_script" "$_path" 2>/dev/null | grep -q "|$_rule|"; then
    echo "ok   rule $_rule reported ($_label)"
  else
    echo "FAIL rule $_rule NOT reported ($_label)"; fail=1
  fi
}

expect_no_rule() {
  _rule=$1; _script=$2; _path=$3; _label=$4
  if node "$_script" "$_path" 2>/dev/null | grep -q "|$_rule|"; then
    echo "FAIL rule $_rule wrongly reported ($_label)"; fail=1
  else
    echo "ok   rule $_rule correctly absent ($_label)"
  fi
}

echo "== check-size.ts =="

# A tree comfortably under the 1 MiB budget.
small=$(make_repo small)
add_file "$small" "a.txt" 1024
commit_repo "$small"
expect_exit 0 "$SIZE_CHECK" "$small" "compliant tree passes"
expect_rule "size/budget" "$SIZE_CHECK" "$small" "compliant tree (INFO line present)"

# A tree whose single tracked file exceeds 1 MiB (1048576 bytes) on its own.
big=$(make_repo big)
add_file "$big" "blob.bin" 2200000
commit_repo "$big"
expect_exit 1 "$SIZE_CHECK" "$big" "oversized tree fails"
expect_rule "size/budget" "$SIZE_CHECK" "$big" "oversized tree"

# Misuse: missing/unreadable path.
expect_exit 2 "$SIZE_CHECK" "$WORK/does-not-exist" "missing path is 'could not evaluate'"

# Misuse: wrong argument count.
node "$SIZE_CHECK" >/dev/null 2>&1
if [ $? -ne 2 ]; then echo "FAIL no-args: expected exit 2"; fail=1; else echo "ok   no-args (exit 2)"; fi

echo "== check-no-binaries.ts =="

# A clean tree: only text and one small SVG (allowed regardless of size).
clean=$(make_repo clean)
add_file "$clean" "README.md" 200
add_file "$clean" "logo.svg" 80000
commit_repo "$clean"
expect_exit 0 "$BIN_CHECK" "$clean" "clean tree passes"
expect_no_rule "binaries/font" "$BIN_CHECK" "$clean" "clean tree"
expect_no_rule "binaries/oversized-raster" "$BIN_CHECK" "$clean" "clean tree, large SVG allowed"

# A tree with a font file.
font=$(make_repo font)
add_file "$font" "assets/brand.woff2" 4096
commit_repo "$font"
expect_exit 1 "$BIN_CHECK" "$font" "font-carrying tree fails"
expect_rule "binaries/font" "$BIN_CHECK" "$font" "woff2 file"

# A tree with an oversized raster image (> 50 KB) and a compliant small one.
raster=$(make_repo raster)
add_file "$raster" "big.png" 60000
add_file "$raster" "small.jpg" 10000
commit_repo "$raster"
expect_exit 1 "$BIN_CHECK" "$raster" "oversized raster fails"
expect_rule "binaries/oversized-raster" "$BIN_CHECK" "$raster" "60KB png"
if node "$BIN_CHECK" "$raster" 2>/dev/null | grep -q "small\.jpg"; then
  echo "FAIL small.jpg wrongly flagged in raster tree"; fail=1
else
  echo "ok   small.jpg (10KB) correctly not flagged"
fi

# An office/PDF/archive tree.
office=$(make_repo office)
add_file "$office" "policy.pdf" 2048
add_file "$office" "sheet.xlsx" 2048
add_file "$office" "bundle.zip" 2048
commit_repo "$office"
expect_exit 1 "$BIN_CHECK" "$office" "office/pdf/archive tree fails"
expect_rule "binaries/office" "$BIN_CHECK" "$office" "pdf/xlsx"
expect_rule "binaries/archive" "$BIN_CHECK" "$office" "zip"

# Misuse: missing/unreadable path.
expect_exit 2 "$BIN_CHECK" "$WORK/does-not-exist" "missing path is 'could not evaluate'"

# Misuse: wrong argument count.
node "$BIN_CHECK" >/dev/null 2>&1
if [ $? -ne 2 ]; then echo "FAIL no-args: expected exit 2"; fail=1; else echo "ok   no-args (exit 2)"; fi

echo "== check-marketplace-compat.ts =="

compat="$WORK/compat"
mkdir -p "$compat/.claude-plugin" "$compat/.agents/plugins" "$compat/.github/plugin" \
  "$compat/plugins/example/.claude-plugin" "$compat/plugins/example/.codex-plugin"
printf '%s\n' '{"plugins":[{"name":"example","version":"1.0.0","source":"./plugins/example","relevance":{}}]}' > "$compat/.claude-plugin/marketplace.json"
printf '%s\n' '{"plugins":[{"name":"example","source":{"source":"local","path":"./plugins/example"},"policy":{"installation":"AVAILABLE","authentication":"ON_INSTALL"},"category":"Test"}]}' > "$compat/.agents/plugins/marketplace.json"
printf '%s\n' '{"plugins":[{"name":"example","version":"1.0.0","source":"./plugins/example"}]}' > "$compat/.github/plugin/marketplace.json"
printf '%s\n' '{"name":"example","version":"1.0.0"}' > "$compat/plugins/example/.claude-plugin/plugin.json"
printf '%s\n' '{"name":"example","version":"1.0.0"}' > "$compat/plugins/example/.codex-plugin/plugin.json"
printf '%s\n' '{"name":"example","version":"1.0.0"}' > "$compat/plugins/example/plugin.json"
expect_exit 0 "$COMPAT_CHECK" "$compat" "matching host manifests pass"

printf '%s\n' '{"name":"example","version":"2.0.0"}' > "$compat/plugins/example/plugin.json"
expect_exit 1 "$COMPAT_CHECK" "$compat" "cross-host version drift fails"
expect_rule "compat" "$COMPAT_CHECK" "$compat" "cross-host version drift"

# Reset to matching versions for subsequent tests.
printf '%s\n' '{"name":"example","version":"1.0.0"}' > "$compat/plugins/example/plugin.json"

# Negative: wrong source directory in Claude catalog.
wrong_src=$(mktemp -d "$WORK/compat-wrong-src.XXXXXX")
cp -r "$compat/." "$wrong_src/"
printf '%s\n' '{"plugins":[{"name":"example","version":"1.0.0","source":"./plugins/other","relevance":{}}]}' > "$wrong_src/.claude-plugin/marketplace.json"
expect_exit 1 "$COMPAT_CHECK" "$wrong_src" "wrong Claude source directory fails"
expect_rule "compat" "$COMPAT_CHECK" "$wrong_src" "wrong Claude source"

# Negative: stale entry present only in Copilot catalog (not in Claude).
stale_copilot=$(mktemp -d "$WORK/compat-stale-copilot.XXXXXX")
cp -r "$compat/." "$stale_copilot/"
printf '%s\n' '{"plugins":[{"name":"example","version":"1.0.0","source":"./plugins/example"},{"name":"stale","version":"1.0.0","source":"./plugins/stale"}]}' > "$stale_copilot/.github/plugin/marketplace.json"
expect_exit 1 "$COMPAT_CHECK" "$stale_copilot" "host-only stale Copilot entry fails"
expect_rule "compat" "$COMPAT_CHECK" "$stale_copilot" "stale Copilot entry"

# Negative: stale entry present only in OpenAI catalog.
stale_openai=$(mktemp -d "$WORK/compat-stale-openai.XXXXXX")
cp -r "$compat/." "$stale_openai/"
printf '%s\n' '{"plugins":[{"name":"example","source":{"source":"local","path":"./plugins/example"},"policy":{"installation":"AVAILABLE","authentication":"ON_INSTALL"},"category":"Test"},{"name":"stale","source":{"source":"local","path":"./plugins/stale"},"policy":{"installation":"AVAILABLE","authentication":"ON_INSTALL"},"category":"Test"}]}' > "$stale_openai/.agents/plugins/marketplace.json"
expect_exit 1 "$COMPAT_CHECK" "$stale_openai" "host-only stale OpenAI entry fails"
expect_rule "compat" "$COMPAT_CHECK" "$stale_openai" "stale OpenAI entry"

# Negative: missing OpenAI manifest for a plugin.
no_openai_manifest=$(mktemp -d "$WORK/compat-no-openai-manifest.XXXXXX")
cp -r "$compat/." "$no_openai_manifest/"
rm "$no_openai_manifest/plugins/example/.codex-plugin/plugin.json"
expect_exit 1 "$COMPAT_CHECK" "$no_openai_manifest" "missing OpenAI manifest fails"
expect_rule "compat" "$COMPAT_CHECK" "$no_openai_manifest" "missing OpenAI manifest"

# Negative: missing Copilot manifest for a plugin.
no_copilot_manifest=$(mktemp -d "$WORK/compat-no-copilot-manifest.XXXXXX")
cp -r "$compat/." "$no_copilot_manifest/"
rm "$no_copilot_manifest/plugins/example/plugin.json"
expect_exit 1 "$COMPAT_CHECK" "$no_copilot_manifest" "missing Copilot manifest fails"
expect_rule "compat" "$COMPAT_CHECK" "$no_copilot_manifest" "missing Copilot manifest"

# Negative: missing OpenAI policy metadata.
no_policy=$(mktemp -d "$WORK/compat-no-policy.XXXXXX")
cp -r "$compat/." "$no_policy/"
printf '%s\n' '{"plugins":[{"name":"example","source":{"source":"local","path":"./plugins/example"},"category":"Test"}]}' > "$no_policy/.agents/plugins/marketplace.json"
expect_exit 1 "$COMPAT_CHECK" "$no_policy" "missing OpenAI policy metadata fails"
expect_rule "compat" "$COMPAT_CHECK" "$no_policy" "missing OpenAI policy"

# Negative: malformed JSON in a host catalog.
bad_json=$(mktemp -d "$WORK/compat-bad-json.XXXXXX")
cp -r "$compat/." "$bad_json/"
printf '%s\n' '{invalid json' > "$bad_json/.agents/plugins/marketplace.json"
expect_exit 1 "$COMPAT_CHECK" "$bad_json" "malformed catalog JSON fails"

# Negative: exit 2 for missing root path.
expect_exit 2 "$COMPAT_CHECK" "$WORK/does-not-exist" "missing path is 'could not evaluate'"

# Negative: exit 2 when no argument is provided.
node "$COMPAT_CHECK" >/dev/null 2>&1
if [ $? -ne 2 ]; then echo "FAIL compat-no-args: expected exit 2"; fail=1; else echo "ok   compat-no-args (exit 2)"; fi

[ "$fail" -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED"
exit "$fail"
