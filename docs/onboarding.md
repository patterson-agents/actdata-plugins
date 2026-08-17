# Onboarding

Your first day in `actdata-plugins`, from a fresh clone to a merged change.

This is the orientation layer. [`CONTRIBUTING.md`](../CONTRIBUTING.md) is the rulebook and does not
repeat itself here; read this first, then that.

## Table of contents

- [What you are working on](#what-you-are-working-on)
- [Day one: environment](#day-one-environment)
- [Orientation: how the repository is shaped](#orientation-how-the-repository-is-shaped)
- [The gate](#the-gate)
- [Making a change](#making-a-change)
- [Learning path](#learning-path)
- [First tasks](#first-tasks)
- [Security and supply chain](#security-and-supply-chain)
- [Team, access and communication](#team-access-and-communication)
- [Keeping this guide honest](#keeping-this-guide-honest)

---

## What you are working on

`actdata-plugins` is a plugin marketplace for **Claude Code, ChatGPT, Codex, and GitHub Copilot**. It is not an application or a
service. There is no server, no build step and nothing to deploy.

The deliverable is the three host catalogs plus the plugins under `plugins/` that they point at.
People install those plugins through Claude Code, ChatGPT/Codex, or GitHub Copilot, so **the install
experience is the product**. A plugin that is correct on disk but broken on one supported host is not
compatible with that host.

One consequence dominates everything else:

> [!IMPORTANT]
> A plugin that is not registered in `.claude-plugin/marketplace.json` **does not exist**. It cannot
> be installed, however finished it looks. Creating a plugin directory and registering it are one
> task, not two.

### What a plugin is made of

Four component types, all discovered by convention rather than declared:

| Component | Lives at | Discovered by |
|---|---|---|
| Skill | `skills/<name>/SKILL.md` | Directory scan; frontmatter `name` must equal the directory name |
| Command | `commands/<name>.md` | YAML frontmatter |
| Agent | `agents/<name>.md` | YAML frontmatter |
| Hook | `hooks/hooks.json` | The file's presence |

> [!WARNING]
> Frontmatter is not decoration. A command or agent whose YAML fails to parse still appears in the
> menu but loads with **empty metadata**, silently dropping its `allowed-tools` restriction. The
> repository gate does not catch this. See [The gate](#the-gate).

## Day one: environment

### Prerequisites

| Tool | Why | Verify |
|---|---|---|
| **Node 24+** | Runs the validators and test suites (native TypeScript). | `node --version` |
| **git** | 2.x | `git --version` |
| **Claude Code CLI** | `claude plugin validate`, and installing what you build | `claude --version` |
| **jq** | Used by one bundled plugin script | `jq --version` |
| **trufflehog**, **trivy** | Pre-commit secret scanning. Optional; the hook skips gracefully. | `trufflehog --version` |
| **socket** | Supply-chain scoring before adding any dependency | `socket --version` |

There is no toolchain manifest pinning versions in this repository; install tools however your
machine already does. Use whatever package manager you prefer for the devDependencies —
`package-lock.json` is the lockfile CI uses, and other managers' lockfiles are gitignored so they
never land by accident.

### Setup

```sh
git clone <repository-url> actdata-plugins
cd actdata-plugins

npm install                       # devDependencies only; nothing here needs building
git config core.hooksPath .githooks   # opt into the local pre-commit gate, once per clone
```

### Confirm it works

```sh
sh scripts/verify-all.sh
```

You want `VERIFY-ALL: PASS` on a clean checkout before you change anything. If it fails on a fresh
clone, that is a repository problem rather than a you problem, and it is worth raising immediately.

### Install what is here, and use it

The fastest way to understand a marketplace is to be a user of it:

```sh
claude plugin marketplace add .
claude plugin install act-plugin-dev@actdata-plugins
```

Then start a fresh session and run `/help`. The commands appear namespaced as
`<plugin-name>:<command-name>`. Seeing your own change surface that way closes the loop between what
you edited and what a user gets.

## Orientation: how the repository is shaped

```text
.claude-plugin/marketplace.json   # Claude Code catalog
.agents/plugins/marketplace.json  # ChatGPT and Codex catalog
.github/plugin/marketplace.json   # GitHub Copilot catalog
plugins/<name>/
  .claude-plugin/plugin.json      # Claude manifest
  .codex-plugin/plugin.json       # OpenAI manifest
  plugin.json                     # Copilot manifest
  skills/<skill-name>/SKILL.md    # frontmatter name MUST equal the directory name
  agents/*.md  commands/*.md  hooks/hooks.json
  scripts/                        # bundled executables, referenced via ${CLAUDE_PLUGIN_ROOT}
scripts/verify-all.sh             # the gate. One script, every mechanical invariant.
scripts/check-size.ts             # node:* builtins only, run with node
scripts/check-no-binaries.ts
docs/decisions/                   # ADRs
.tmp/                             # gitignored scratch; preferred over /tmp so work stays inspectable
```

### The four plugins

| Plugin | What it is | Read it because |
|---|---|---|
| `act-plugin-dev` | The toolkit for building plugins here: 7 skills, 3 review agents, the guided creation workflow | It is both the tooling you will use and the reference implementation you will copy |
| `act-platform-engineering` | PostgreSQL, ZFS, Linux and Proxmox assessment | The largest plugin. Good example of splitting one domain across several skills. |
| `act-work-tracking` | Zoho Projects tracking and reporting conventions | Smallest complete plugin. Good first read. |
| `act-gitlab-ci` | GitLab CI, the GitLab MCP server, `glab`, pipeline standards | The only plugin shipping an MCP server and a validator with its own test suite |

### Suggested reading order

1. This file.
2. [`README.md`](../README.md) — what the marketplace is and the plugin catalog.
3. `plugins/act-plugin-dev/README.md` — then its skills as you need them.
4. [`docs/decisions/`](decisions/README.md) — the ADR index. Start with
   [`0001-fork-plugin-dev.md`](decisions/0001-fork-plugin-dev.md) and the reason `act-plugin-dev` is
   a fork rather than a dependency.

### Two design principles worth internalising early

**Progressive disclosure.** A `SKILL.md` body should be lean, roughly 1,500 to 2,000 words, with
detail pushed into `references/` and working artefacts into `examples/`. The body carries the
reasoning; the references carry the lookup material.

**Config-driven, not hardcoded.** The operational plugins ship **no** environment identifiers: no
hostnames, addresses, database names or portal IDs, not even as defaults or fallbacks. Those come
from a gitignored `.agents/<plugin-name>.local.md` the operator writes (`.claude/` is the legacy
fallback location). With no settings file present, the commands ask rather than guess.

That constraint is deliberate. A command that defaults to a plausible-looking hostname is a command
that will eventually run a diagnostic against the wrong machine and report confident findings about
it.

## The gate

```sh
sh scripts/verify-all.sh
```

One script defines every mechanical invariant. CI (`.github/workflows/ci.yml`), the GitLab mirror
(`.gitlab-ci.yml`) and `.githooks/pre-commit` all call it. It must print `VERIFY-ALL: PASS`.

It checks: every discovered `run-tests.sh`, skill name equals directory name, plugin manifests parse
and match their directory, marketplace registration and version consistency, no tracked binaries, the
2 MiB tracked-byte budget, and no expanded `${CLAUDE_PLUGIN_ROOT}`.

### The trap that catches everyone once

> [!CAUTION]
> `check-size.ts` and `check-no-binaries.ts` read **tracked** files via `git ls-files`. On unstaged
> work they measure almost nothing and pass trivially.
>
> **Run `git add -A` before treating a green gate as meaningful.**

### What the gate does not check

Knowing the gaps is as useful as knowing the checks:

| Not checked | Catch it with |
|---|---|
| YAML frontmatter parses in commands and agents | `claude plugin validate plugins/<name>` per plugin |
| Emoji | Review, and the `plugin-validator` agent. A mechanical check cannot tell an ACT-authored surface from vendored upstream content. |
| Whether a skill is any good | The `skill-reviewer` agent |
| Environment identifiers leaking into a plugin | A targeted `git grep`, written per change |

> [!NOTE]
> `claude plugin validate .` checks the **marketplace manifest**. It does not descend into each
> plugin's commands and agents. `claude plugin validate plugins/<name>` does, and it is the only
> thing that catches an unparseable frontmatter block. Run it per plugin when you touch one.

## Making a change

The full rules are in [`CONTRIBUTING.md`](../CONTRIBUTING.md). The loop:

```sh
git switch -c feat/my-change      # never work on main
# ... make the change ...
git add -A                        # stage BEFORE verifying; the validators read tracked files
sh scripts/verify-all.sh          # must print VERIFY-ALL: PASS
claude plugin validate .
claude plugin validate plugins/<name>   # per plugin you touched
git commit -m "feat(scope): summary"
```

Conventional commits, one logical change per pull request, branch from `main`. No AI attribution in
commit messages or PR bodies: no `Claude-Session:` trailers, no "Generated with" footers, no AI
co-author lines.

### Adding a plugin

Prefer the guided workflow. It creates the directory, writes the manifest, registers the marketplace
entry and runs the gate, which keeps a plugin from sitting half-registered:

```text
/act-plugin-dev:create-plugin
```

The by-hand checklist is in [`CONTRIBUTING.md`](../CONTRIBUTING.md#adding-a-plugin).

### When a source is silent

Write `[TBD: what is missing]` rather than inventing an answer. A `[TBD]` is a question to escalate
to whoever owns the thing, not a defect to quietly resolve.

```sh
grep -rn '\[TBD' plugins/ docs/
```

This convention is used throughout the repository, including in this guide.

## Learning path

The `act-plugin-dev` plugin carries the reference material. Load a skill when you need it rather than
reading them all up front:

| You are about to | Load |
|---|---|
| Create or restructure a plugin | `plugin-structure` |
| Write a skill | `skill-development` |
| Write a slash command | `command-development` |
| Write a subagent | `agent-development` |
| Write a hook | `hook-development` |
| Wire in an MCP server | `mcp-integration` |
| Add user-supplied configuration | `plugin-settings` |

Three review agents are available and worth using before you open a pull request:

- `plugin-validator` — manifest, structure, naming, registration, security
- `skill-reviewer` — description quality, progressive disclosure, writing style
- `agent-creator` — generates an agent's identifier, triggering examples and system prompt

### Learning by reading a real diff

`git log` is short. Reading the commit that added the three operational plugins shows a complete
worked example: manifests, marketplace registration, skills with references, agents with triggering
examples, commands with frontmatter, two test suites, and the README updates that go with them.

## First tasks

Real open items, roughly by increasing difficulty. Each is genuinely unfinished; none is busywork.

### Warm-up

**1. Audit `[TBD]` markers.**
Run the grep above. Each one is a real question someone needs to answer. Working out *who* owns each
answer is a fast way to learn the repository's boundaries.

### Substantial

**2. Close the gate's blind spot.**
Add a per-plugin `claude plugin validate plugins/<name>` step to `scripts/verify-all.sh`. It must skip
gracefully when the CLI is absent, matching the advisory step already in `.github/workflows/ci.yml`.
Frontmatter parse errors silently drop every field — including `allowed-tools` — and the gate cannot
see them today; see [The gate](#the-gate). This is the highest-leverage change on this list.

**3. Extend `act-work-tracking`.**
At two skills it is the thinnest registered plugin (the others carry six or seven). Scope a third
skill against a real work-tracking need with `/act-plugin-dev:create-plugin`'s skill guidance, and
ship it registered and versioned.

### Deeper

**4. Rebalance `act-platform-engineering/skills/linux-host-tuning/`.**
Its `SKILL.md` is a router with no commands in the body; everything is one file-read away in
`references/`. Compare against `proxmox-virtualization` and `observability`, which keep commands
inline. Decide whether to inline `references/disk-health.md`, and write down why.

**5. Resolve the pipeline standards conflict.**
`act-gitlab-ci/skills/pipeline-standards/` is translated from a standard that does not permit GitLab
and whose approved-tool list excludes GitLab's built-in scanners. See
[`_SOURCES.md`](../plugins/act-gitlab-ci/skills/pipeline-standards/_SOURCES.md). This is not a coding
task; it needs a decision from whoever owns the standard. Finding out who that is, and getting an
answer, is the work.

### Recorded gaps: do not "fix" these without asking

- `docs/assets/` holds an **invented placeholder** wordmark. No ACT brand assets exist.
- `LicenseRef-ACT-Internal` is a provisional identifier. ACT's licensing posture is unconfirmed.
- `act-plugin-dev` is a fork, not a dependency, and does not track upstream. The divergence is
  deliberate and documented.

## Security and supply chain

### Before adding any dependency

```sh
socket package shallow npm pkg:npm/<name>@<version> --markdown
```

Five scores come back on a 0-100 scale: supply chain, maintenance, quality, vulnerability, license.
**Flag anything under 90** and get explicit confirmation before installing, naming which dimension is
low. Read the `[high]`/`[middle]`/`[low]` alerts line too; it is often more actionable than the
scores.

> [!NOTE]
> Both validators in `scripts/` import only `node:*` builtins by design. Keeping them
> dependency-free means the gate runs before any package install and cannot itself become a supply-chain
> surface. New validators should hold that line.

### Guards that will stop you

Two hooks intercept tool calls, and both fail loud rather than silently:

| Guard | Blocks |
|---|---|
| **No `/tmp`** | Anything created or stored under a system temp directory. Use the gitignored `.tmp/`. It matches the literal string, so it will fire on a `grep` pattern containing it too. |
| **Supply-chain denylist** | Known-malicious packages and publishers in commands and manifests |

The documented escape hatch for a demo or a genuine false positive is
`PATTERSON_ENGINEERING_HOOKS=off`. Reach for it rarely and say why.

### Secrets

Never commit a credential. The pre-commit hook runs trufflehog and trivy over the working tree when
they are installed, and skips with a printed notice when they are not. That skip is why the hook is
a convenience rather than the control: **you** are the control.

Plugin scripts read credentials from environment variables and never write them anywhere. Follow that
pattern.

## Team, access and communication

> [!IMPORTANT]
> This section is deliberately unfilled. The team structure, communication channels and access
> procedures for this repository were not available when this guide was written, and inventing them
> would be worse than leaving them blank: a confidently wrong contact list wastes a new joiner's
> first week.
>
> If you are onboarding and can answer any of these, filling them in is a genuinely useful first
> contribution.

- `[TBD: team structure, roles, and who owns which plugin]`
- `[TBD: communication channels, and which one is appropriate for what]`
- `[TBD: meeting cadence and which are expected of a new joiner]`
- `[TBD: mentor or buddy assignment process]`
- `[TBD: accounts and access to request on day one, and from whom]`
- `[TBD: escalation path for a blocked or ambiguous decision]`
- `[TBD: compliance or security training required before contributing]`

What is known and does not need escalating:

- Issue and pull request templates are in `.github/`, including a dedicated new-plugin proposal form.
- `CODEOWNERS` records review ownership.
- `SECURITY.md` documents vulnerability reporting.

## Keeping this guide honest

An onboarding guide decays faster than anything else in a repository, because the people best placed
to notice are the ones least confident about correcting it.

If you are working through this and something is wrong, stale or missing, change it in the same
branch as the work that revealed it. That is a `docs:` commit and needs no ceremony.

Two habits that keep it accurate:

- When a `[TBD]` gets answered, replace it here rather than only in the conversation where it was
  answered.
- When you hit something confusing that this guide should have warned you about, add the warning
  while you still remember being confused. Nobody has that perspective for long.

> [!NOTE]
> `[TBD: onboarding feedback mechanism and review cadence for this guide.]` Until one exists, the
> pull request that fixes something here is the feedback.
