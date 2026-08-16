# Architecture

How this marketplace is put together, and why it is shaped the way it is.

For the rules you must follow, see [`CONTRIBUTING.md`](../CONTRIBUTING.md). This document explains
the machinery those rules protect.

## Table of contents

- [The shape of the thing](#the-shape-of-the-thing)
- [Three catalogs, three manifests](#three-catalogs-three-manifests)
- [How components are discovered](#how-components-are-discovered)
- [Namespacing](#namespacing)
- [`${CLAUDE_PLUGIN_ROOT}`](#claude_plugin_root)
- [When things happen](#when-things-happen)
- [The config-driven pattern](#the-config-driven-pattern)
- [MCP servers inside a plugin](#mcp-servers-inside-a-plugin)
- [Dependency posture](#dependency-posture)
- [Why there is no build step](#why-there-is-no-build-step)

---

## The shape of the thing

```text
.claude-plugin/marketplace.json     Claude Code catalog
.agents/plugins/marketplace.json    ChatGPT and Codex catalog
.github/plugin/marketplace.json     GitHub Copilot catalog
        |
        |  one entry per installable plugin, each with a `source` path
        v
plugins/<name>/
    .claude-plugin/plugin.json      Claude Code manifest
    .codex-plugin/plugin.json       OpenAI manifest
    plugin.json                     GitHub Copilot manifest
    skills/<skill-name>/SKILL.md    knowledge, loaded on demand
    commands/<name>.md              user-invoked, /plugin-name:command-name
    agents/<name>.md                delegated subagents
    hooks/hooks.json                event-driven interception
    .mcp.json                       external tool servers
    scripts/                        bundled executables
```

Everything above is plain text. There is no compilation, bundling, or generated artefact. The three
catalogs describe the same plugin directories in each host's native schema. Reusable behavior lives
in `skills/`; Claude commands and agents remain host-specific adapters.

### Cross-runtime invariants

- Every shipped plugin appears in all three catalogs.
- Its directory name and all three manifest names match.
- Its version matches every manifest and every versioned catalog entry.
- OpenAI entries include installation, authentication, and category policy metadata.
- Core workflows do not require commands, agents, or hooks, because ChatGPT executes skills.

`scripts/check-marketplace-compat.ts` enforces the mechanical parts of this contract.

### The one asymmetry worth memorising

A plugin's *existence on disk* and its *installability* are separate facts, and only the second one
matters to a user:

> [!IMPORTANT]
> A plugin with no entry in `.claude-plugin/marketplace.json` cannot be installed, no matter how
> complete it is. Creating the directory and registering it are one task.

This is gated. `scripts/verify-all.sh` step 4 fails the build on a plugin that exists on disk but is
absent from the catalog, with one deliberate exception described in
[Drafts](#drafts-the-one-permitted-gap).

## Three catalogs, three manifests

Each plugin ships host-specific catalog entries and host-specific per-plugin manifests. They serve
different readers and duplicate exactly one field on purpose.

### Catalog entries (one per host)

| | `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` | `.github/plugin/marketplace.json` |
|---|---|---|---|
| Host | Claude | OpenAI / Codex | GitHub Copilot |
| Answers | "What can I install, and is it relevant to me?" | Same | Same |
| Required extras | `source` (relative path), `relevance` | `source.path`, `source.source`, `policy`, `category` | `source` (relative path) |
| Version field | `version` | — (not versioned) | `version` |

### Per-plugin manifests (one per host per plugin)

| | `plugins/<name>/.claude-plugin/plugin.json` | `plugins/<name>/.codex-plugin/plugin.json` | `plugins/<name>/plugin.json` |
|---|---|---|---|
| Host | Claude | OpenAI / Codex | GitHub Copilot |
| Read by | The runtime, after install | Same | Same |
| Scope | One plugin | One plugin | One plugin |

### The fields that must agree

`version` appears in both and **must match**. The gate compares them, because a mismatch means the
advertised version is not the installed one, and that failure is silent at install time.

`name` in `plugin.json` must equal the plugin's directory name. The gate compares those too.

### `relevance`

Required on every marketplace entry:

```json
"relevance": {
  "topic": "short topic phrase",
  "signals": {
    "filesRead": ["**/pattern-that-implies-relevance"]
  }
}
```

This is how a plugin surfaces to someone who has not gone looking for it. The `filesRead` globs
describe the files whose presence suggests the plugin would help. `act-gitlab-ci` lists
`**/.gitlab-ci.yml`; `act-platform-engineering` lists `**/postgresql.conf` and friends.

Write these as *evidence of the problem*, not as evidence of the plugin. A pattern matching the
plugin's own files makes it relevant only to itself.

### Drafts: the one permitted gap

A plugin still carrying `claude plugin init` TODO placeholders is a **draft**. It is correct for a
draft to be unregistered, because registering it would ship `TODO -- describe WHEN Claude should use
this` to users.

The gate detects a draft by scanning the plugin's `.md` files for `TODO — `, `TODO: ` or `TODO -- `,
and reports it as a note rather than a failure.

> [!WARNING]
> The draft exemption applies **only while the plugin is absent from the catalog**. Once an entry
> exists, `isDraft()` is never consulted and every consistency rule applies. A fully-registered
> scaffold passes the gate while shipping placeholder text to users.
>
> Note also that the draft scan reads `.md` files only. TODO markers in a `.ts` or `.json` file do
> not mark a plugin as a draft.

## How components are discovered

Two different mechanisms, and knowing which applies to what saves an afternoon.

| Component | Discovered by | Failure mode when wrong |
|---|---|---|
| Skill | Directory scan of `skills/*/`, then frontmatter `name` must equal the directory name | Skill does not resolve |
| Command | YAML frontmatter in `commands/*.md` | Appears in the menu with **empty metadata** |
| Agent | YAML frontmatter in `agents/*.md` | Loads with **empty metadata** |
| Hook | Presence of `hooks/hooks.json` | Silently inert |
| MCP server | Presence of `.mcp.json` | Server absent from `/mcp` |

### The frontmatter failure is the dangerous one

When a command's or agent's YAML fails to parse, it does not disappear. It loads with every
frontmatter field dropped, which means:

- the `description` is gone, so the user cannot tell what it does
- `argument-hint` is gone
- **`allowed-tools` is gone**, so the tool restriction silently does not apply

The most common cause is an unquoted colon-space inside a plain scalar:

```yaml
# Breaks. The ": " terminates the scalar.
description: Report coverage across the fleet: collectors, plugins, dashboards

# Correct.
description: "Report coverage across the fleet: collectors, plugins, dashboards"
```

A trailing colon has the same effect: a `description:` line ending in `Examples:` is a YAML error.

> [!CAUTION]
> `scripts/verify-all.sh` does **not** parse frontmatter, and neither does `claude plugin validate .`
> — that validates the marketplace manifest only. The check that catches this is
> `claude plugin validate plugins/<name>`, per plugin. See [`verification.md`](verification.md).

### The skill-name invariant

`skills/foo-bar/SKILL.md` must contain `name: foo-bar`. Kebab-case, identical string.

This exists because Title Case frontmatter names (`name: Plugin Structure`) are the norm outside this
repository, so any skill imported from elsewhere arrives broken. The gate reads the first 20 lines
looking for a `^name:` at column 0.

## Namespacing

Installed components are addressed as `<plugin-name>:<component-name>`:

```text
/act-platform-engineering:assess-postgres     a command
act-plugin-dev:skill-reviewer                 an agent
act-gitlab-ci:pipeline-standards              a skill
```

Two consequences:

**Marketplace names are one flat global namespace.** Registering a second marketplace called
`actdata-plugins` replaces this one rather than merging with it.

**Component names only need to be unique within their plugin.** Two plugins may both ship a
`review-pipeline` command. Skills are the exception worth thinking about, because a skill competes for
attention on trigger phrases rather than on its name — two skills claiming the same user utterance
will fight regardless of namespace.

## `${CLAUDE_PLUGIN_ROOT}`

The literal token a plugin uses to reference its own bundled files:

```markdown
bun "${CLAUDE_PLUGIN_ROOT}/scripts/check-pipeline.ts" .gitlab-ci.yml
```

It resolves at runtime to wherever the plugin was installed. Two rules:

**Never write a resolved path.** An absolute `/home/...` or `/workspaces/...` path pointing at
`plugins/`, `skills/` or `hooks/` means a tool wrote its own machine's layout into a tracked file.
The gate greps for exactly that and fails.

**Never use a relative path instead.** A relative path passes the gate but breaks at install time,
because commands execute from the user's working directory, not from the plugin directory. This is
the failure the gate cannot see, which makes it worth checking by eye.

The gate carries one documented exemption: the placeholder `/home/user/.claude/plugins/my-plugin/`
appearing as the *wrong* half of a Wrong/Correct pair in `act-plugin-dev`'s teaching material. The
exemption is written as the full literal string rather than as a file allowlist, so a genuinely
leaked path landing in that same file is still caught.

## When things happen

Understanding the timeline explains most "why didn't my change take effect" questions.

| Moment | What happens |
|---|---|
| **Catalog time** | `marketplace.json` is read. Only entries, `source` paths and `relevance` matter. Nothing inside a plugin is read. |
| **Install time** | The plugin directory is copied. `plugin.json` is read. Nothing executes. |
| **Session start** | Components are discovered: skills indexed by description, commands and agents by frontmatter, hooks registered, MCP servers started. |
| **Invocation** | A skill body is read when its description matches. A command runs when typed. An agent runs when delegated. A script runs when a command tells it to. |

A change to a component does not reach an existing session. Start a fresh session, or `/reload-plugins`
where supported.

> [!NOTE]
> Skill *descriptions* are loaded at session start; skill *bodies* are read on demand. That is why
> the description is the highest-leverage text in a skill: it is always in context, competing against
> every other skill's description, while the body costs nothing until it is needed.

## The config-driven pattern

The operational plugins ship **no environment identifiers**: no hostnames, addresses, database names,
portal IDs or endpoints, not even as defaults or fallbacks.

Site-specific values live in a gitignored file the operator writes:

```text
.agents/<plugin-name>.local.md
```

`.gitignore` carries `.agents/*.local.md` so one can never be committed by accident.
`.claude/<plugin-name>.local.md` is also supported as a legacy fallback.

### The contract

Every command and agent that needs a target follows the same resolution order:

1. An explicit argument
2. The settings file
3. **Ask the user**

Never invent, guess, or pattern-match a value.

### Why, specifically

A command that defaults to a plausible hostname will eventually run a diagnostic against the wrong
machine and report confident findings about it. The failure is silent and the output looks correct,
which is the worst combination available.

A missing settings file producing a question is a good outcome, not a degraded one.

### Implementing it

Give the plugin a skill that owns the contract, and have the others defer to it.
`act-platform-engineering/skills/infrastructure-inventory/` is the worked example: it defines the
file location, the table schema, the resolution order and the never-invent rule, and four sibling
skills reference it by name rather than restating it.

## MCP servers inside a plugin

A plugin ships `.mcp.json` at its root:

```json
{
  "mcpServers": {
    "gitlab": {
      "type": "http",
      "url": "${GITLAB_MCP_URL}"
    }
  }
}
```

Installing the plugin registers the server. Two consequences worth weighing before shipping one:

**Every install attempts a connection.** A plugin with an MCP server is not passive.

**Endpoints are usually site-specific.** Hardcoding one would violate the config-driven rule, so
`act-gitlab-ci` takes its URL from an environment variable. With the variable unset the server fails
to connect, which is deliberate: it fails visibly rather than reaching somewhere unintended.

Prefer a bundled script over an MCP server when the work is a one-shot command. A server is the right
shape when the plugin needs live, structured access to an external system across a conversation.

## Dependency posture

The repository's own tooling has **zero third-party dependencies**. Both validators in `scripts/`
import only `node:*` builtins.

That is a deliberate property, not an accident of scope:

> [!NOTE]
> A dependency-free gate runs before `bun install` and cannot itself become a supply-chain surface.
> A validator that needed packages to run could not validate a tree whose packages had not been
> vetted yet.

New validators should hold that line. Plugin-bundled scripts should too where practical:
`act-gitlab-ci/scripts/check-pipeline.ts` is zero-dependency for the same reason, and
`act-work-tracking/scripts/zoho-create.sh` uses only `curl` and `jq`.

Anything genuinely needed gets scored first:

```sh
socket package shallow npm pkg:npm/<name>@<version> --markdown
```

Flag anything under 90 and name which of the five dimensions is low.

## Why there is no build step

Every component is a file the runtime reads directly. Adding a build would mean the repository no
longer contains what gets installed, and the gate would be validating inputs rather than outputs.

Two things follow:

- **The gate can check the real artefact.** `check-size.ts` sums tracked bytes because tracked bytes
  *are* the payload a clone downloads.
- **A change is testable immediately.** `claude plugin marketplace add .` against a local checkout
  installs exactly what is on disk.

`package.json` exists for scripts and a single `@types/bun` devDependency. It is not a package
anyone installs; `private: true` says so.

## Further reading

| Topic | Where |
|---|---|
| The rules, stated as rules | [`CONTRIBUTING.md`](../CONTRIBUTING.md) |
| The gate, check by check | [`verification.md`](verification.md) |
| Getting started | [`onboarding.md`](onboarding.md) |
| Why the big decisions were made | [`decisions/`](decisions/) |
| Authoring a specific component type | The `act-plugin-dev` skills |
