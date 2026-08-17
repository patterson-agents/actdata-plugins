# Glossary

Terms as this repository uses them. Several are overloaded elsewhere, and the differences matter.

---

### Agent

A subagent defined at `agents/<name>.md`, delegated to for a bounded task. Discovered by YAML
frontmatter, which must carry `name`, a one-to-two-sentence `description` ending in a delegation
cue, `tools` and `model`.

The `description` is what decides when it gets used. The worked scenarios that teach the
orchestrator when to delegate live in the body's `## When to invoke` section, which is loaded only
when the agent runs — descriptions are paid for in every session, scenarios are not.

### Catalog

Informal name for `.claude-plugin/marketplace.json`. See [Marketplace](#marketplace).

### `${CLAUDE_PLUGIN_ROOT}`

The literal token a plugin uses to reference its own bundled files. Resolves at runtime to the
install location.

Written literally, never as a resolved path (the gate fails on those) and never replaced with a
relative path (which passes the gate and breaks at install time, since commands run from the user's
working directory).

### Command

A user-invoked action at `commands/<name>.md`, addressed as `/<plugin-name>:<command-name>`.
Discovered by YAML frontmatter carrying `description`, `argument-hint` and `allowed-tools`.

Written **for** Claude, not to the user: the body is instructions to follow, not documentation to
read.

### Component

Collectively: skills, commands, agents, hooks and MCP servers. The installable parts of a plugin.

### Draft

A plugin still carrying `claude plugin init` TODO placeholders. It is *correct* for a draft to be
unregistered, and the gate reports it as a note rather than a failure.

The exemption applies only while it is absent from the catalog. See
[`verification.md`](verification.md#the-draft-exemption).

### Gate

`scripts/verify-all.sh`. The single definition of every mechanical invariant, called by CI, the
GitLab mirror and the pre-commit hook. Must print `VERIFY-ALL: PASS`.

### Hook

Event-driven interception, configured at `hooks/hooks.json`. Fires on events such as `PreToolUse` or
`SessionStart`.

A hook that can block should have an off switch environment variable, and it should be documented.

### Marketplace

The catalog of installable plugins, `.claude-plugin/marketplace.json`. Also the repository as a
whole, in the sense "this repository is a marketplace".

> [!IMPORTANT]
> Marketplace **names occupy one flat global namespace**. Registering a second marketplace under the
> name `actdata-plugins` replaces this one rather than merging with it.

### MCP server

An external tool server declared in a plugin's `.mcp.json`. Installing the plugin registers it.

Two distinct things can share a name — GitLab, for instance, has both an HTTP server at
`/api/v4/mcp` for interactive sessions and a runner-image binary supplying tools inside CI jobs. They
are not interchangeable.

### Plugin

An installable unit at `plugins/<name>/`, manifested by `.claude-plugin/plugin.json` and registered
in the marketplace.

> [!IMPORTANT]
> A plugin with no catalog entry **does not exist**, however complete it is on disk.

### `relevance`

A required block on every marketplace entry, describing when the plugin is worth surfacing:

```json
"relevance": {
  "topic": "short topic phrase",
  "signals": { "filesRead": ["**/pattern"] }
}
```

Write the globs as evidence of the *problem*, not of the plugin. A pattern matching the plugin's own
files makes it relevant only to itself.

### Progressive disclosure

The convention that a `SKILL.md` body stays lean — roughly 1,500 to 2,000 words — with detail pushed
into `references/` and working artefacts into `examples/`.

The body carries reasoning; references carry lookup material. It matters because skill *descriptions*
are always in context while bodies are read on demand.

### Reference

A file under a skill's `references/`, read on demand. Long-form detail that would bloat the skill
body.

A reference nothing points at is dead weight; `SKILL.md` must name it.

### Settings file

`.agents/<plugin-name>.local.md`, written by the operator and gitignored via `.agents/*.local.md`.
`.claude/<plugin-name>.local.md` remains supported as a legacy fallback.

Holds the environment identifiers plugins deliberately do not ship — hostnames, addresses, IDs. See
[ADR 0002](decisions/0002-config-driven-plugins.md).

### Skill

Knowledge at `skills/<name>/SKILL.md`, loaded when its description matches what the user is doing.

> [!WARNING]
> The frontmatter `name` must be **identical** to the directory name, in kebab-case. Title Case names
> are the norm outside this repository, so imported skills usually arrive broken. The gate fails on a
> mismatch.

### Suite

A `run-tests.sh` anywhere in the repository. The gate discovers and runs every one; adding a suite
needs no edit to the gate.

POSIX `sh`, self-locating, fixtures generated into `.tmp/` and never committed.

### `[TBD:]`

The marker for a gap that should be escalated rather than filled by inference:

```text
[TBD: no DAST tool is named in the CI/CD Pipeline Standards]
```

A question for whoever owns the answer, not a defect to quietly resolve.

```sh
grep -rn '\[TBD' plugins/ docs/
```

### Tracked bytes

The sum of on-disk sizes of files `git ls-files` reports, which is the payload a clone downloads.
Budgeted at 2 MiB.

Deliberately not `du` block accounting, which overstates the real figure by more than a factor of two
here.

> [!CAUTION]
> Tracked means staged or committed. Unstaged work is invisible to the validators, so `git add -A`
> before trusting a green gate.

### `.tmp/`

The gitignored scratch directory at the repository root. **Never** a system temp directory; a
workspace hook blocks those, matching the literal string.

Test fixtures are generated here at run time and cleaned up with a `trap`.
