<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../docs/assets/act-wordmark-white.svg">
  <img src="../../docs/assets/act-wordmark.svg" alt="ACT Data" width="260">
</picture>

# act-plugin-dev

Everything needed to build a plugin for the `actdata-plugins` marketplace, and the conventions
that keep one from breaking at install time.

![skills](https://img.shields.io/badge/skills-11-00A8E1?labelColor=003767)
![agents](https://img.shields.io/badge/agents-3-003767)
![commands](https://img.shields.io/badge/commands-1-147EC2)
![size](https://img.shields.io/badge/size-535_KB-00817D)
![deps](https://img.shields.io/badge/dependencies-none-58585B)

</div>

---

## Table of contents

- [What this is](#what-this-is)
- [What ships](#what-ships)
- [Skills](#skills)
- [Agents](#agents)
- [The guided workflow](#the-guided-workflow)
- [Install](#install)
- [The conventions this plugin enforces](#the-conventions-this-plugin-enforces)
- [Upstream and divergence](#upstream-and-divergence)
- [What this plugin does NOT do](#what-this-plugin-does-not-do)
- [Layout](#layout)

## What this is

A fork of Claude Code's `plugin-dev` toolkit, adapted for this marketplace. It carries the same
seven reference skills, four portable workflow skills, the same three review agents, and the same
eight-phase creation command —
with the generic advice replaced by what is actually true here: plugins live at `plugins/<name>/`,
skill names are kebab-case and must match their directory, and a plugin is not
finished until it is registered in `.claude-plugin/marketplace.json`.

The point of the fork is that generic plugin advice produces plugins that fail this repository's
gate. Rather than leave that gap for each author to rediscover, the gap is closed in the guidance
itself.

## What ships

| Component | Count | What it is |
|---|---|---|
| Skills | **11** | Authoring guidance plus portable creation and review workflows for supported hosts. |
| Agents | **3** | `agent-creator` generates agents; `plugin-validator` audits a plugin against structure, manifest, marketplace registration, and repository conventions; `skill-reviewer` reviews a single skill. |
| Command | **1** | `/act-plugin-dev:create-plugin`, an eight-phase guided workflow from concept to registered plugin. |
| Utility scripts | **6** | POSIX-sh validators shipped inside the skills: `validate-agent.sh`, `validate-hook-schema.sh`, `test-hook.sh`, `hook-linter.sh`, `validate-settings.sh`, `parse-frontmatter.sh`. |

No MCP server, no hooks, no output styles. This plugin is reference material and workflow, not
runtime behaviour.

## Skills

| Skill | What it covers |
|---|---|
| [`plugin-structure`](skills/plugin-structure/) | Directory layout, `plugin.json`, component organization, auto-discovery, `${CLAUDE_PLUGIN_ROOT}`. Leads with the four things fixed by this marketplace. |
| [`skill-development`](skills/skill-development/) | Writing a skill: trigger descriptions, progressive disclosure, imperative voice, the name-equals-directory rule. |
| [`command-development`](skills/command-development/) | Slash commands: frontmatter, arguments, bash execution, interactive patterns, testing. |
| [`agent-development`](skills/agent-development/) | Subagents: system prompt design, triggering conditions, `<example>` blocks, tool selection. |
| [`hook-development`](skills/hook-development/) | All hook events, prompt-based vs command hooks, output schemas, security, portable paths. |
| [`mcp-integration`](skills/mcp-integration/) | Wiring an MCP server into a plugin: stdio, SSE and HTTP server types, authentication, tool usage. |
| [`plugin-settings`](skills/plugin-settings/) | Portable `.agents/<plugin-name>.local.md` settings with a legacy Claude fallback. |

## Agents

| Agent | When it runs |
|---|---|
| [`agent-creator`](agents/agent-creator.md) | Asked to create, generate, or build an agent. Produces identifier, triggering description with examples, and system prompt. |
| [`plugin-validator`](agents/plugin-validator.md) | Asked to validate a plugin, or proactively after plugin components change. Checks manifest, structure, naming, **marketplace registration and version consistency**, and the ACT conventions. |
| [`skill-reviewer`](agents/skill-reviewer.md) | After a skill is created or modified. Reviews description quality, progressive disclosure, and writing style. |

## The guided workflow

```text
/act-plugin-dev:create-plugin [optional description]
```

Eight phases: Discovery, Component Planning, Detailed Design, Structure Creation, Component
Implementation, Validation, Testing, Documentation & Registration.

Two phases differ from upstream in ways that matter:

- **Phase 4 registers the plugin in `marketplace.json` at the same time it creates the directory**,
  so a plugin is never left half-registered. It also does not ask where to put the plugin — the
  answer is always `plugins/<name>/`.
- **Phase 6 runs the repository gate** (`sh scripts/verify-all.sh` and `claude plugin validate .`)
  before the agent-based review, so mechanical failures surface before anyone reads prose.

## Install

```sh
claude plugin marketplace add patterson-agents/actdata-plugins
claude plugin install act-plugin-dev@actdata-plugins
```

From a local checkout:

```sh
claude plugin marketplace add /path/to/actdata-plugins
claude plugin install act-plugin-dev@actdata-plugins
```

Verify:

```sh
claude plugin validate .
```

## The conventions this plugin enforces

These are the rules that differ from generic plugin advice, and the reason this fork exists. The
repository gate (`sh scripts/verify-all.sh`) checks every mechanical one.

| Rule | Why it is not optional |
|---|---|
| Skill directory name == frontmatter `name`, kebab-case | Title Case names are widespread outside this repository and break skill resolution here. The gate fails on a mismatch. |
| Plugins live at `plugins/<name>/` | `marketplace.json` declares `metadata.pluginRoot: "./plugins"`. |
| Registered in `.claude-plugin/marketplace.json` | An unregistered plugin is invisible to `claude plugin install`. |
| `version` matches between `plugin.json` and the marketplace entry | Otherwise the advertised version is not the installed one. Bump both together. |
| No `"skills": ["./"]` alongside a `skills/` directory | That field is the single-skill template shape and breaks auto-discovery. |
| `${CLAUDE_PLUGIN_ROOT}` stays literal | A resolved absolute path written back into a tracked file breaks the plugin on every other machine. |
| No binaries, 2 MiB tracked-byte budget | Enforced by `scripts/check-no-binaries.ts` and `scripts/check-size.ts`. |

## Upstream and divergence

**Source:** Claude Code's `plugin-dev` plugin, version `0.1.0`, authored by Daisy Hollman at
Anthropic. Vendored from the local marketplace cache at
`~/.claude/plugins/cache/claude-code-plugins/plugin-dev/0.1.0/`.

This is a **fork, not a dependency**. Upstream will move; this will not follow automatically. The
list below is what makes re-syncing tractable — keep it accurate.

### Changed from upstream

| Change | Where | Why |
|---|---|---|
| Frontmatter `name` rewritten to kebab-case | all 7 `skills/*/SKILL.md` | Upstream ships Title Case (`name: Agent Development`) in kebab-case directories. The repository gate requires them identical. This is the only edit to 6 of the 7 SKILL.md files. |
| `npm` / `npx` replaced with `bun` / `bunx` | 7 files across `command-development`, `hook-development`, `plugin-structure` | Historical: an earlier marketplace policy. The marketplace no longer prescribes a package manager; either form is acceptable in examples. |
| ACT marketplace section added | `skills/plugin-structure/SKILL.md` | Location, registration, skill naming, and the `"skills": ["./"]` trap, stated before the generic layout advice. |
| Rewritten for this marketplace | `commands/create-plugin.md` | Conventions table; Phase 4 creates *and registers*; Phase 6 runs the repository gate; Phase 8 verifies registration consistency; emoji removed from quality standards. |
| ACT convention checks added | `agents/plugin-validator.md` | Marketplace registration, version consistency, skill-name-equals-directory, expanded plugin roots, binaries. New report sections for each. |
| Name-equals-directory check added | `agents/skill-reviewer.md` | The failure mode this fork exists to prevent. |
| `plugin.json` rewritten | `.claude-plugin/plugin.json` | ACT author, license, homepage, repository, keywords. |

### Upstream defects fixed here

| Defect | Where | Fix |
|---|---|---|
| Conversational text committed into an agent system prompt: *"Excellent work! The agent-development skill is now complete… Would you like me to create more agents?"* | `agents/plugin-validator.md` | Removed, replaced with edge-case and reporting-discipline guidance. |
| Unmatched closing code fence, opening a fence that never closes so all following text renders as code | `agents/agent-creator.md`, `agents/skill-reviewer.md`, `agents/plugin-validator.md` | Removed. |

### Deliberately *not* changed

**Vendored reference content style.** The vendored `skills/*/references/` and `skills/*/examples/`
files keep their upstream formatting — including check and cross marks used as semantic DO/DON'T
markers and as terminal status output in shell scripts. Restyling them across 30-plus files would
multiply the diff against upstream for no benefit.

## What this plugin does NOT do

> [!CAUTION]
> A passing `plugin-validator` report means "nothing detectable was found in these files", not
> "this plugin works". Only installing it and exercising it in a session shows that.

- **It does not track upstream.** Nothing here notices when Anthropic's `plugin-dev` changes. Re-syncing is a manual diff against the version recorded above.
- **It does not install or enable anything.** The workflow writes files and registers a manifest entry; you still run `claude plugin install` and reload.
- **It does not validate at runtime.** There are no hooks. Nothing blocks a convention violation at write time — the gate is a script you run, and the validator is an agent you invoke.
- **It does not know Claude Code's current schema.** The reference content describes the plugin API as of upstream `0.1.0`. Where Claude Code has moved on, the docs are the authority and this is stale.
- **It cannot judge whether a plugin should exist.** It will happily help build a plugin that duplicates one already in the catalog. Phase 1 asks you to check; it cannot decide for you.

## Layout

```text
act-plugin-dev/
├── .claude-plugin/plugin.json
├── README.md
├── agents/
│   ├── agent-creator.md
│   ├── plugin-validator.md
│   └── skill-reviewer.md
├── commands/
│   └── create-plugin.md
└── skills/<seven skills>/
    ├── SKILL.md          # lean: decision rules + pointers
    ├── references/       # full detail, loaded on demand
    ├── examples/         # working code
    └── scripts/          # POSIX-sh validators
```

All intra-plugin references use the literal `${CLAUDE_PLUGIN_ROOT}`. There are no absolute paths
anywhere in this plugin.
