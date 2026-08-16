# Verification

Every mechanical invariant in this repository, what enforces it, and what nothing enforces.

```sh
sh scripts/verify-all.sh
```

One script. CI (`.github/workflows/ci.yml`), the GitLab mirror (`.gitlab-ci.yml`) and
`.githooks/pre-commit` all call it. It must print `VERIFY-ALL: PASS`.

## Table of contents

- [The staging trap](#the-staging-trap)
- [The seven checks](#the-seven-checks)
- [What the gate does not check](#what-the-gate-does-not-check)
- [The validators](#the-validators)
- [Writing a test suite](#writing-a-test-suite)
- [The pre-commit hook](#the-pre-commit-hook)
- [CI](#ci)
- [Known gaps in the gate itself](#known-gaps-in-the-gate-itself)

---

## The staging trap

> [!CAUTION]
> `check-size.ts` and `check-no-binaries.ts` enumerate files with `git ls-files`, which reports
> **tracked** files only. On unstaged work they measure almost nothing and pass trivially.
>
> Run `git add -A` before treating a green gate as meaningful.

This catches everyone once. A new plugin that is entirely untracked will sail through both validators
while contributing zero bytes and zero binaries to their view of the tree.

## The seven checks

`verify-all.sh` resolves its own path, `cd`s to the repository root and runs these in order. Each
prints `PASS` or `FAIL`; the script exits non-zero if any failed.

### 1. Test suites

Discovers every `run-tests.sh` in the repository and runs each with `sh`:

```sh
find . -path ./.git -prune -o -name node_modules -prune -o -path ./.tmp -prune \
       -o -name 'run-tests.sh' -print
```

`.git`, `node_modules` and `.tmp` are pruned. A vendored dependency's own harness is not this
repository's to run, and `.tmp` holds generated fixtures.

**Adding a suite requires no edit to the gate.** Drop a `run-tests.sh` anywhere and it is picked up.

Zero suites found is a failure, not a pass. That guards against the discovery glob silently breaking.

Current suites:

| Suite | Covers |
|---|---|
| `scripts/tests/run-tests.sh` | All three repository validators (`check-size.ts`, `check-no-binaries.ts`, `check-marketplace-compat.ts`) |
| `plugins/act-work-tracking/scripts/tests/run-tests.sh` | `zoho-create.sh`, 17 assertions |
| `plugins/act-gitlab-ci/scripts/tests/run-tests.sh` | `check-pipeline.ts`, 23 assertions |

### 2. Skill name equals directory name

Scans `plugins/*/skills/*/SKILL.md`. For each, compares the containing directory's name against the
frontmatter `name`.

```sh
frontmatter_name=$(sed -n '1,20p' "$skill_md" | grep -m1 '^name:' | sed 's/^name:[[:space:]]*//')
```

Two mechanical details that matter when debugging a mismatch:

- The `name:` must appear within the **first 20 lines**.
- It must be at **column 0**. An indented `name:` inside a nested structure is not found.

The glob is one level deep. A skill at `plugins/x/skills/a/b/SKILL.md` is not scanned.

### 3. Plugin manifests

For each `plugins/*/.claude-plugin/plugin.json`: it must parse as JSON, and its `name` must equal the
plugin's directory name.

Parsing is done by `bun -e`, so a syntax error is reported with the JSON parser's own message.

### 4. Marketplace registration and version consistency

The largest check. For every directory under `plugins/` that has a `plugin.json`:

| Rule | Failure |
|---|---|
| Registered in the catalog | `<name>: on disk but absent from marketplace.json` |
| `version` matches between the two manifests | `version X in plugin.json but Y in marketplace.json` |
| `source` resolves to a real path | `source "..." does not resolve` |
| A `relevance` block is present | `missing required "relevance" block` |

Then the reverse direction: every catalog entry must have a `plugin.json` on disk at its `source`.

A directory with no `plugin.json` is skipped as an empty placeholder shell rather than failing. That
is how `plugins/code-review/`, `plugins/standards/` and `plugins/git-workflows/` coexist with a green
gate.

#### The draft exemption

A plugin whose `.md` files contain `TODO — `, `TODO: ` or `TODO -- ` is a draft, and an unregistered
draft is reported as a note rather than failed:

```text
note: <name> is still a scaffold (TODO placeholders); correctly unregistered
```

> [!WARNING]
> The exemption applies **only while the plugin is absent from the catalog**. Once registered,
> `isDraft()` is never consulted and every rule above applies, so a fully-registered scaffold passes
> the gate while shipping placeholder text to users.
>
> The scan reads `.md` files only. TODO markers in `.ts` or `.json` do not mark a draft.

### 5. Cross-runtime marketplace compatibility

`scripts/check-marketplace-compat.ts` compares the Claude, OpenAI, and GitHub Copilot catalogs and
plugin manifests. It checks registration, names, versions, source paths, and required OpenAI policy
metadata.

### 6. No binaries, and the size budget

Both validators run against the whole repository. See [The validators](#the-validators).

### 7. No expanded `${CLAUDE_PLUGIN_ROOT}`

```sh
git grep -nE '(/home/|/workspaces/)[^"'"'"' ]*/(plugins|skills|hooks)/' -- .
```

An absolute path immediately followed by `/plugins/`, `/skills/` or `/hooks/` means a tool wrote a
resolved path back into a tracked file instead of leaving the token literal.

One exemption, written as a full literal string:

```text
/home/user/.claude/plugin[s]/my-plugin/
```

That is the *wrong* half of a Wrong/Correct pair in `act-plugin-dev`'s command-development examples,
which teaches authors not to hardcode plugin paths. Because the exemption is the literal path rather
than a file allowlist, a genuinely leaked path landing in that same file is still caught.

> [!NOTE]
> Both the pattern and its documentation wrap a letter in a character class (`plugin[s]`) so that
> `verify-all.sh` does not contain the literal string and therefore never flags itself. The check
> scans all tracked files, including its own source.

## What the gate does not check

Knowing the holes is as useful as knowing the checks.

| Not checked | Why not | Catch it with |
|---|---|---|
| **YAML frontmatter parses** in commands and agents | The gate reads frontmatter with `sed` and `grep`, not a YAML parser | `claude plugin validate plugins/<name>` |
| **Emoji** | A mechanical check cannot distinguish an ACT-authored surface from vendored upstream content, where check marks are semantic markers | Review, and the `plugin-validator` agent |
| **Relative paths where `${CLAUDE_PLUGIN_ROOT}` belongs** | A relative path is syntactically fine; it just breaks at install time | Reading the diff |
| **Environment identifiers leaking into a plugin** | The set of forbidden strings is per-change, not global | A targeted `git grep`, written per change |
| **Whether a skill is any good** | Not mechanical | The `skill-reviewer` agent |
| **Whether a scan in a pipeline actually gates it** | Out of scope for this repository's gate | `act-gitlab-ci`'s own checker, with its own caveats |

### The frontmatter gap, specifically

This is the most consequential omission, because the failure is silent and security-relevant.

```sh
claude plugin validate .                    # marketplace manifest ONLY
claude plugin validate plugins/<name>       # descends into commands and agents
```

The first is what `verify-all.sh` and CI run. The second is the one that catches an unparseable
`description:`. Run it per plugin you touch.

When frontmatter fails to parse, the component still loads, with every field dropped — including
`allowed-tools`, so the tool restriction silently does not apply.

## The validators

All three live in `scripts/`, import only `node:*` builtins, and run under `bun`.

### Shared contract

| | |
|---|---|
| Usage | `bun scripts/<name>.ts <path>` |
| Output | `LEVEL\|file\|line\|rule\|message` |
| Levels | `ERROR`, `WARN`, `INFO` |
| Exit 0 | Pass, no `ERROR` findings |
| Exit 1 | `ERROR` findings present |
| Exit 2 | Could not evaluate |

`line` is always `0` for all three, since they are whole-tree checks.

Exit 2 is distinct from exit 1 on purpose: "the tree is bad" and "I could not look at the tree" are
different outcomes, and conflating them turns a broken validator into a green build.

### `check-size.ts`

Sums the on-disk byte size of every file `git ls-files` reports as tracked.

```text
BUDGET_BYTES = 2 * 1024 * 1024      # 2 MiB
```

It deliberately does **not** use `du` block accounting, which overstates the real figure by more than
a factor of two on this tree and would make a byte budget fire on phantom growth. Tracked bytes are
what a clone actually downloads.

> [!NOTE]
> `[TBD: the 2 MiB budget figure is awaiting ratification; it is not specified in a Patterson
> source.]`

### `check-no-binaries.ts`

Flags tracked files that are fonts, office documents, PDFs, archives, or raster images over a
threshold.

| Category | Extensions | Limit |
|---|---|---|
| Font | `.woff`, `.woff2`, `.ttf`, `.otf`, `.eot` | Any |
| Archive | `.zip` | Any |
| Document | `.pdf`, and anything starting `doc`, `xls`, `ppt` | Any |
| Raster | `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp` | 50 KiB |
| **SVG** | `.svg` | **Exempt at any size** |

SVG is exempt because it is text, and because it is the only image format this catalog ships.

Brand fonts are licensed through Adobe Fonts and must never be committed. That is a licensing
constraint, not only a size one.

### `check-marketplace-compat.ts`

Verifies that every on-disk plugin is represented consistently across all three host catalogs
(Claude, OpenAI, and Copilot) and that no stale entries exist only in the OpenAI or Copilot
catalog.

For each plugin directory that has a `.claude-plugin/plugin.json`:

- All three per-plugin manifests (`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
  root `plugin.json`) must exist and carry the same `version`.
- An entry must exist in all three host catalogs.
- The Claude entry's `source` must resolve to the plugin's own directory.
- The OpenAI entry's `source.path` must resolve to the plugin's directory, with `source.source`
  set to `"local"`, and its `policy` must declare `AVAILABLE` / `ON_INSTALL`.
- The Copilot entry's `source` must resolve to the plugin's directory.
- No name may appear only in the OpenAI or Copilot catalog without a matching Claude entry.

Usage requires a path argument; omitting it or passing a non-directory exits 2.

## Writing a test suite

The convention, established by `scripts/tests/run-tests.sh` and followed by both plugin suites:

**POSIX `sh`, not bash.** The gate invokes suites with `sh`.

**Self-locating.** Resolve paths from `$0` so the suite runs from anywhere:

```sh
SUITE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
```

**Count and report.** Print one line per assertion, then a summary, and exit non-zero on any failure.

**Generate fixtures, do not commit them.** A fixture proving the size check works would itself be an
oversized file tripping the very check it tests. Generate into the gitignored `.tmp/` with a cleanup
trap:

```sh
mkdir -p "$ROOT/.tmp"
WORK=$(mktemp -d "$ROOT/.tmp/my-tests.XXXXXX") || exit 1
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
```

> [!CAUTION]
> Never `/tmp`. A workspace hook blocks any command referencing a system temp directory, and it
> matches the literal string — so it fires on a `grep` pattern containing it too.

**Skip gracefully on a missing tool.** Print a note and continue rather than failing. CI runners
differ, and a suite that fails for want of `jq` teaches nobody anything.

**Test the documented limitations too.** `act-gitlab-ci`'s suite asserts that its checker *does not*
follow `include:` directives. If that starts passing, the skill's caveats have become wrong and
someone needs to update the prose.

### Test-first

Write the failing fixtures before the implementation, and confirm they fail for the right reason —
missing script, not a typo in the test. All three repository validators came with their suite; new ones
should too.

## The pre-commit hook

Opt in once per clone:

```sh
git config core.hooksPath .githooks
```

It runs the full gate, not a subset — the gate is cheap here, with no build step, so there is no
reason to run less locally than CI runs.

It adds one thing CI cannot usefully do after the fact: a secret scan of the working tree, using
trufflehog and trivy. Both skip with a printed notice when not installed.

> [!IMPORTANT]
> That graceful skip is why the hook is a convenience rather than a control. If neither scanner is
> installed, nothing scans. You are the control.

Bypass deliberately with `git commit --no-verify`, and say why.

## CI

`.github/workflows/ci.yml` runs on every branch push and every pull request:

- `fetch-depth: 0`, because the validators read tracked files via `git ls-files` and the suites create
  throwaway git repositories
- Bun via `oven-sh/setup-bun@v2`
- `sh scripts/verify-all.sh`
- An advisory `claude plugin validate .` step, `continue-on-error: true`, which skips when the CLI is
  absent from the runner

`.gitlab-ci.yml` mirrors it. Keep the two in step: a check present in only one will be discovered by
whoever pushes to the other.

## Known gaps in the gate itself

Recorded rather than papered over.

**No per-plugin `claude plugin validate`.** The highest-value addition available. It would need to
skip gracefully when the CLI is absent, matching the existing advisory step. Until it exists, the
frontmatter parse failure described above reaches `main` undetected.

**`check-size.ts` cites a path that does not exist here.** Its budget comment refers to
`openspec/changes/add-repo-furniture/design.md` and "the OpenSpec planning root living in this
repository". There is no `openspec/` directory in `actdata-plugins`; the comment was carried over
from `patterson-corp` during the adaptation. The 2 MiB figure and the reasoning are unaffected, but
the citation is stale.

**The emoji rule has no mechanical enforcement**, by design. See
[`CONTRIBUTING.md`](../CONTRIBUTING.md#the-emoji-exemption-stated-precisely).

**`[TBD: no review cadence is defined for the gate itself.]`**
