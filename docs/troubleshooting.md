# Troubleshooting

Symptom, cause, fix. Every entry here is a failure that has actually occurred in this repository.

## Table of contents

- [The gate](#the-gate)
- [Plugins and components](#plugins-and-components)
- [Skills](#skills)
- [Commands and agents](#commands-and-agents)
- [MCP servers](#mcp-servers)
- [Hooks and guards](#hooks-and-guards)
- [Scripts and tests](#scripts-and-tests)
- [Git and tooling](#git-and-tooling)

---

## The gate

### The gate passes but I know something is wrong

**Cause:** You did not stage. `check-size.ts` and `check-no-binaries.ts` read **tracked** files via
`git ls-files`. Untracked work is invisible to them.

```sh
git add -A && sh scripts/verify-all.sh
```

This is the single most common false-green in the repository.

### `FAIL test suites (none found -- expected at least one run-tests.sh)`

**Cause:** The discovery `find` returned nothing. Either you are not at the repository root (unlikely
— the script resolves its own path), or the suites were removed.

**Fix:** Confirm at least one exists: `find . -name run-tests.sh -not -path './.git/*'`.

The zero-suite case is a deliberate failure rather than a vacuous pass, so a silently broken glob
cannot look green.

### `FAIL skill name == directory`

**Cause:** A `SKILL.md` frontmatter `name` does not equal its directory name. Almost always a skill
imported from elsewhere, where Title Case names are the norm.

```yaml
# skills/plugin-structure/SKILL.md
name: Plugin Structure     # wrong
name: plugin-structure     # correct
```

**Two mechanical gotchas** if the name *looks* right:

- The `name:` must appear in the **first 20 lines**.
- It must be at **column 0**. Indented, it is not found, and the comparison sees an empty string.

### `FAIL marketplace registration`

Read the printed problem line; each maps to one fix.

| Message | Fix |
|---|---|
| `on disk but absent from marketplace.json` | Add the catalog entry, with `source`, matching `version`, and `relevance` |
| `version X in plugin.json but Y in marketplace.json` | Bump both in the same commit |
| `source "..." does not resolve` | The path is wrong or the directory moved |
| `missing required "relevance" block` | Add one; it is required on every entry |
| `registered in marketplace.json but has no plugin.json on disk` | A stale entry for a removed or renamed plugin |

### `FAIL no expanded ${CLAUDE_PLUGIN_ROOT}`

**Cause:** A tracked file contains an absolute `/home/...` or `/workspaces/...` path followed by
`/plugins/`, `/skills/` or `/hooks/`. Usually a tool resolved the token and wrote the result back.

**Fix:** Replace with the literal `${CLAUDE_PLUGIN_ROOT}`.

The printed hits include file and line. There is exactly one exemption, for a documented cautionary
placeholder in `act-plugin-dev`'s teaching material.

### The size budget failed

```sh
node scripts/check-size.ts .
```

The `INFO` line reports total tracked bytes against the 2 MiB budget. Find the offender:

```sh
git ls-files -z | xargs -0 du -b 2>/dev/null | sort -rn | head -20
```

Usually a committed binary that `check-no-binaries.ts` should also have caught, or a large vendored
tree.

---

## Plugins and components

### My plugin does not appear in `claude plugin install`

**Cause, in order of likelihood:**

1. **Not registered.** No entry in `.claude-plugin/marketplace.json`. This is the answer most of the
   time. A plugin that is not in the catalog does not exist.
2. The marketplace was added before your change. Re-add it: `claude plugin marketplace add .`
3. `source` does not resolve to the plugin directory.

### My change does not take effect

**Cause:** Components are discovered at session start. An existing session holds the old copy.

**Fix:** Start a fresh session, or `/reload-plugins` where supported.

### The plugin installed but nothing from it is available

**Cause:** Discovery found no components. Check the layout — components must be at
`skills/<name>/SKILL.md`, `commands/<name>.md`, `agents/<name>.md`, not at the plugin root.

A `SKILL.md` at the plugin root is the single-skill template shape. It does not combine with a
`skills/` directory.

### `"skills": ["./"]` in `plugin.json`

**Cause:** Copied from the single-skill template, or left behind by `claude plugin init`.

**Fix:** Remove the field. It expects a `SKILL.md` at the plugin root and **breaks auto-discovery**
when a `skills/` directory exists. Plugins with a `skills/` directory need no `skills` field at all.

---

## Skills

### A skill never triggers

**Cause:** The description does not contain phrasing the user actually types. Descriptions are what
skills are matched on; the body is irrelevant until after a match.

**Fix:** Write concrete trigger phrases in the user's words, and include symbol triggers — flag
names, config keys, error strings. Those fire on pasted output, which quoted phrases never catch.

```yaml
description: This skill should be used when the user asks to "assess Postgres", "why is the database
  slow", "check replication", or mentions pg_stat_statements, replication slots, WAL shipping...
```

### The wrong skill triggers

**Cause:** Two descriptions claim the same utterance.

**Fix:** Narrow the losing one and add an explicit redirect. `gitlab-mcp-server` gave up its
connection-failure trigger to `ci-troubleshooting` and says so in its own description:

```text
For a server that will not connect, use ci-troubleshooting instead.
```

This matters most when the competing skill is authoritative and yours is derived. Qualify your
triggers so the authoritative one wins.

### A skill loads but the reference material does not

Reference files are read on demand, not automatically. `SKILL.md` must name them, and the reader must
have a reason to open them. A `references/` file nothing points at is dead weight.

---

## Commands and agents

### A command appears but has no description, or ignores `allowed-tools`

**Cause:** Its YAML frontmatter failed to parse. The component still loads, with **every field
dropped** — including the tool restriction.

**Diagnose:**

```sh
claude plugin validate plugins/<name>
```

`claude plugin validate .` will **not** catch this; it validates the marketplace manifest only.

**The two causes:**

```yaml
# 1. Unquoted colon-space inside a plain scalar
description: Report coverage: collectors, dashboards      # breaks
description: "Report coverage: collectors, dashboards"    # correct

# 2. A trailing colon at end of line
description: ... and here are the examples. Examples:     # breaks
```

For a genuinely multi-line description, use a block scalar (`description: |`) — though for agents,
prefer a short single-line description with the scenarios in the body's `## When to invoke`
section instead.

> [!NOTE]
> The validator stops at the first error. After fixing one, run it again — there may be more.

### An agent never gets delegated to

**Cause:** The `description` describes what the agent is, not when to use it, and the body has no
`## When to invoke` scenarios to match a situation against.

**Fix:** End the description with a delegation cue ("Use when...") plus a pointer to the body's
worked scenarios, and put two or three scenarios — each a distinct situation, each saying why this
agent rather than another — under `## When to invoke`. Generic filler scenarios do not help.

### A bundled script is not found at install time

**Cause:** A relative path. Commands execute from the user's working directory, not the plugin
directory.

```markdown
sh scripts/thing.sh                              # breaks after install
"${CLAUDE_PLUGIN_ROOT}/scripts/thing.sh"         # correct
```

The gate does **not** catch this — it only greps for *expanded* absolute paths. A relative path is
syntactically fine and silently wrong.

---

## MCP servers

### The server does not appear in `/mcp`

1. Is `.mcp.json` at the **plugin root**, not inside `skills/` or `commands/`?
2. Does the JSON parse?
3. If the URL comes from an environment variable, is it set?

### `${VAR}` in `.mcp.json` did not expand

`${CLAUDE_PLUGIN_ROOT}` expands. Arbitrary environment variables may not, depending on the client
version.

**Fix if it does not:** document the direct form instead of shipping the file.

```sh
claude mcp add --transport http gitlab https://<host>/api/v4/mcp
```

### The GitLab MCP server will not connect

Prerequisites fail far more often than configuration does. All three must be on, and on GitLab.com
they are **per top-level group** while on Self-Managed they are instance-wide:

1. GitLab Duo set to "Always on" or "On by default"
2. Beta and experimental features enabled
3. MCP access allowed

Minimum GitLab 18.6 for beta.

> [!WARNING]
> Do not retry in a loop. OAuth Dynamic Client Registration is limited to **10 registrations per hour
> per IP**. Exhausting it changes the failure into a different-looking one, and you end up debugging
> the wrong problem.

### A GitLab MCP tool is missing

Every tool is version-gated between 18.3 and 19.3. Several common ones arrived only in 19.3:
`list_merge_requests`, `add_branch`, `get_pipeline`, `list_pipelines`, `list_wiki_pages`.

Check the instance version against
[`tool-catalogue.md`](../plugins/act-gitlab-ci/skills/gitlab-mcp-server/references/tool-catalogue.md).

`semantic_code_search` additionally needs a Duo Core, Pro or Enterprise add-on.

### A tool returns 404 for one person and works for another

Not a bug. The server authenticates per user via OAuth and acts with **that person's** permissions.
Project access differs between people.

---

## Hooks and guards

### `BLOCKED by patterson-engineering: this command references a system temp directory`

**Cause:** Your command contains a system temp path. Scratch belongs in the gitignored `.tmp/`.

**The surprising case:** it matches the **literal string**, so it fires on a search pattern too:

```sh
grep -c '/t''mp/' file.md        # split the literal
grep -cE '/t[m]p/' file.md       # or use a character class
```

Both are legitimate ways to search for the pattern without writing it.

The documented escape hatch is `PATTERSON_ENGINEERING_HOOKS=off`, for a demo or a genuine false
positive. Reach for it rarely.

### A hook in a plugin never fires

1. Is it at `hooks/hooks.json`?
2. Does the JSON parse?
3. Does the command use the literal `${CLAUDE_PLUGIN_ROOT}`?
4. Is the handler executable?

Give any blocking hook an off switch environment variable and document it.

---

## Scripts and tests

### A test suite passes locally and fails in CI

**The usual cause:** the suite depends on something present locally and absent on the runner —
credentials, an installed binary, network access.

**The pattern that avoids it:** make the credential-free path work with no configuration, and test
that specifically.

`zoho-create.sh` parses `--dry-run` **before** reading any environment variable, so the dry run works
with no `ZOHO_*` set. Its suite unsets them all before running, so a developer's own environment
cannot mask a regression that would fail in CI.

**Skip gracefully on a missing tool:** print a note and continue rather than failing.

### A fixture trips the check it exists to test

**Cause:** You committed it. A file proving the size check works is itself an oversized tracked file.

**Fix:** Generate fixtures at test-run time into `.tmp/` with a cleanup trap. Never commit them.

### `node: command not found` in a suite

The gate runs suites with `sh`, and they inherit the environment. Guard tool use:

```sh
if ! command -v node >/dev/null 2>&1; then
  echo "  note: node not installed; skipping execution tests"
fi
```

---

## Git and tooling

### `git rm` fails with "changes staged in the index"

**Cause:** The file is staged. `git rm` refuses to discard staged content silently.

```sh
git rm -f <paths>        # after confirming you mean it
```

### `&&` or `||` fails in a shell command

The environment's interactive shell is Nushell, which has neither. The `Bash` tool runs a POSIX
shell, so `&&` works there.

If a compound command fails to parse, test which shell you are in before rewriting the command.

| Instead of | Nushell |
|---|---|
| `a && b` | `a; b` |
| `a \|\| b` | `try { a } catch { b }` |
| `cmd &` | `job spawn { cmd }` |
| `$(cmd)` | `(cmd)` |

### A commit was rejected by the pre-commit hook

Read the message; it names the scanner. Both trufflehog and trivy print the command to reproduce.

If it is a false positive, fix the pattern rather than bypassing. `git commit --no-verify` exists but
should come with an explanation.

### Python was rejected

Python is forbidden repository-wide: no `python`/`python3`, no `pip`, no `.py` files. Use TypeScript
under `node`, or POSIX `sh`.

This is why `zoho-create.sh` accepts JSON only — its CSV path used a Python converter and was removed
rather than ported.

---

## Still stuck

| Question | Where |
|---|---|
| How does any of this work? | [`architecture.md`](architecture.md) |
| What exactly does the gate check? | [`verification.md`](verification.md) |
| What are the rules? | [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| How do I write a *good* skill? | `act-plugin-dev`'s `skill-development` skill, then the `skill-reviewer` agent |
| Is my plugin correct? | The `plugin-validator` agent |

If the answer was not here and you worked it out, add it. An entry costs three lines and saves the
next person an afternoon.
