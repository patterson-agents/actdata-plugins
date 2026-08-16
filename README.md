<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/act-wordmark-white.svg">
  <img src="docs/assets/act-wordmark.svg" alt="ACT Data" width="300">
</picture>

# actdata-plugins

ACT Data's institutional knowledge, encoded as installable agent plugins for Claude Code,
ChatGPT, Codex, and GitHub Copilot.

![plugins](https://img.shields.io/badge/plugins-4-00A8E1?labelColor=003767)
![skills](https://img.shields.io/badge/skills-50-003767)
![agents](https://img.shields.io/badge/agents-12-147EC2)
![runtime](https://img.shields.io/badge/runtime-Bun_·_no_build_step-00817D)
![gate](https://img.shields.io/badge/gate-verify--all.sh-58585B)

</div>

---

## Table of contents

- [What this is](#what-this-is)
- [Quick start](#quick-start)
- [Plugin catalog](#plugin-catalog)
- [Repository layout](#repository-layout)
- [Conventions](#conventions)
- [Scripts and validation](#scripts-and-validation)
- [Adding a plugin](#adding-a-plugin)
- [Where it fits](#where-it-fits)
- [Contributing and governance](#contributing-and-governance)
- [Status and open items](#status-and-open-items)

## What this is

An agent plugin marketplace for ACT Data. It packages shared engineering and operations knowledge
for Claude Code, ChatGPT, Codex, and GitHub Copilot.

## Quick start

> [!TIP]
> New to this repository? [`docs/onboarding.md`](docs/onboarding.md) is the day-one guide: what a
> plugin marketplace is, how to get the gate running, what to read in what order, and real first
> tasks.

### Claude Code

```text
/plugin marketplace add patterson-agents/actdata-plugins
/plugin install act-plugin-dev@actdata-plugins
```

From a local checkout:

```sh
cd actdata-plugins
claude
/plugin marketplace add .
/plugin install act-plugin-dev@actdata-plugins
```

Then:

```text
"create a plugin for managing our deploy runbooks"   ← /act-plugin-dev:create-plugin
"validate this plugin before I open a PR"            ← delegates to plugin-validator
"how do I write a PreToolUse hook?"                  ← hook-development skill fires
```

### ChatGPT and Codex

The ChatGPT desktop app discovers `.agents/plugins/marketplace.json` from the repository. Restart
the app, open the Plugins Directory, choose **ACT Data Plugins**, and install a plugin. From Codex:

```sh
codex plugin marketplace add .
codex plugin add act-plugin-dev@actdata-plugins
```

### GitHub Copilot

GitHub Copilot CLI reads `.github/plugin/marketplace.json`:

```sh
copilot plugin marketplace add .
copilot plugin install act-plugin-dev@actdata-plugins
```

> [!WARNING]
> Marketplace names occupy one **flat global namespace**. Registering a second marketplace under
> the name `actdata-plugins` replaces this one rather than merging with it.

## Plugin catalog

| Plugin | What it is | Components |
|---|---|---|
| **[`act-plugin-dev`](plugins/act-plugin-dev/)**<br>Development | Build and review portable plugins while retaining host-specific guidance for commands, agents, hooks, and MCP. | 11 skills · 3 agents · 1 command |
| **[`act-platform-engineering`](plugins/act-platform-engineering/)**<br>Operations | Assessment and operations for PostgreSQL, ZFS, Linux hosts and Proxmox VE. | 23 skills · 7 agents · 9 commands |
| **[`act-work-tracking`](plugins/act-work-tracking/)**<br>Workflow | Zoho Projects work tracking and operations reporting. | 6 skills · 1 agent · 3 commands |
| **[`act-gitlab-ci`](plugins/act-gitlab-ci/)**<br>Engineering | GitLab CI/CD jobs, MCP, authentication, troubleshooting, and pipeline standards. | 10 skills · 1 agent · 3 commands · 1 MCP |
| **[`code-reviews`](plugins/code-reviews/)**<br>Engineering | Automated AI code review across GitHub, GitLab, and local agents: CI merge-request review with swappable engines, a pre-push hook, an in-session command, and Copilot review instructions. | 3 skills · 2 commands · 2 scripts |

### Not yet shipped

These directories exist under `plugins/` but are **not** registered in `marketplace.json`, and are
therefore not installable. That is deliberate — an unfinished plugin should not be discoverable.

| Directory | State |
|---|---|
| `standards` | Empty shell. |
| `git-workflows` | Empty shell. |

`scripts/verify-all.sh` recognises a scaffold by its TODO markers and reports it as a draft rather
than failing the build. Once a draft has real content, registering it becomes mandatory.

## Repository layout

```text
actdata-plugins/
├── .claude-plugin/marketplace.json       # Claude Code catalog
├── .agents/plugins/marketplace.json      # ChatGPT and Codex catalog
├── .github/plugin/marketplace.json       # GitHub Copilot catalog
├── plugins/
│   └── act-plugin-dev/
│       ├── .claude-plugin/plugin.json    # Claude manifest
│       ├── .codex-plugin/plugin.json     # OpenAI manifest
│       ├── plugin.json                   # Copilot manifest
│       ├── README.md
│       ├── skills/<name>/        # SKILL.md · references/ · examples/ · scripts/
│       ├── agents/
│       └── commands/
├── scripts/
│   ├── check-size.ts             # 2 MiB tracked-byte budget validator
│   ├── check-no-binaries.ts      # fonts / office / archive / oversized-raster validator
│   ├── verify-all.sh             # the gate battery -- CI and pre-commit both call this
│   └── tests/run-tests.sh        # TDD fixtures for the two validators
├── docs/                         # see docs/README.md for the index
│   ├── onboarding.md             # start here on day one
│   ├── architecture.md           # how the marketplace works
│   ├── verification.md           # every gate check, and what nothing checks
│   ├── troubleshooting.md        # symptom -> cause -> fix
│   ├── releasing.md · glossary.md
│   ├── assets/                   # placeholder wordmark -- see docs/assets/README.md
│   └── decisions/                # ADRs
├── .github/                      # issue + PR templates, ci.yml
├── .githooks/                    # pre-commit (opt in: git config core.hooksPath .githooks)
├── CONTRIBUTING.md · CODE_OF_CONDUCT.md · SECURITY.md · CODEOWNERS
└── README.md                     # you are here
```

## Conventions

Load-bearing, not stylistic. `scripts/verify-all.sh` enforces the mechanical ones.

| Rule | What it means |
|---|---|
| **kebab-case everywhere** | Plugin names, skill directory names, command and agent filenames. |
| **Skill name equals directory name** | `skills/foo/SKILL.md` must carry `name: foo`. Title Case fails the gate. The most common defect when importing a skill from elsewhere. |
| **Plugins live at `plugins/<name>/`** | `marketplace.json` declares `metadata.pluginRoot: "./plugins"`. |
| **Register, or it does not exist** | Every shipped plugin needs entries in the Claude, OpenAI, and Copilot marketplaces. |
| **Version everywhere** | All host manifests and versioned marketplace entries must agree. The gate checks them. |
| **`${CLAUDE_PLUGIN_ROOT}` stays literal** | Never an absolute path a tool happened to resolve. The gate greps for expanded forms. |
| **Bun only** | `bun install`, `bun run`, `bunx`, `bun test`. `bun.lock` is the only lockfile; an npm/yarn/pnpm lockfile here is a bug. |
| **No `/tmp`** | Scratch goes in the repository's gitignored `.tmp/`. |
| **No binaries** | No fonts, PDFs, Office documents, archives, or raster images over 50 KiB. SVG is exempt at any size. |
| **2 MiB tracked-byte budget** | Measured with `git ls-files`, not `du`. |
| **No emoji on ACT-authored surfaces** | READMEs, manifests, commands, agents. Use GFM alerts and tables. Vendored upstream reference content is exempt -- see [the divergence note](plugins/act-plugin-dev/README.md#upstream-and-divergence). |
| **Conventional commits** | `<type>(<scope>): <summary>`, e.g. `feat(act-plugin-dev): add skill-reviewer agent`. |

## Scripts and validation

The two validators are TypeScript importing only `node:*` builtins — no build step and no
dependency on this repository's `package.json`. They run under Bun.

```sh
bun scripts/check-size.ts .
bun scripts/check-no-binaries.ts .
```

| Contract | Value |
|---|---|
| Argument | a path to check |
| Exit `0` | pass |
| Exit `1` | violations found |
| Exit `2` | could not evaluate |
| Output | `LEVEL\|file\|line\|rule\|message` |

Run everything — the validator suites, the skill-name invariant, manifest parsing, marketplace
registration and version consistency, the two validators repository-wide, and the expanded-path
grep:

```sh
sh scripts/verify-all.sh
```

This is the single gate battery. `.github/workflows/ci.yml` and `.githooks/pre-commit` both call
it; it is the one place the repository's invariants are defined.

> [!IMPORTANT]
> `check-size.ts` and `check-no-binaries.ts` read **tracked** files via `git ls-files`. Until work
> is staged or committed, they have almost nothing to measure and will pass trivially. Stage your
> changes before trusting a green run.

## Adding a plugin

Use the guided workflow — it creates the directory, writes the manifest, registers the marketplace
entry, and runs the gate:

```text
/act-plugin-dev:create-plugin
```

Doing it by hand means, at minimum: `plugins/<name>/.claude-plugin/plugin.json`, a `README.md`, a
`marketplace.json` entry with a matching `version` and a `relevance` block, a row in the catalog
table above, and a green `sh scripts/verify-all.sh`.

## Where it fits

`actdata-plugins` is one of several sibling marketplaces in the
[`patterson-agents`](https://github.com/patterson-agents) organization. Each is an independent
repository with its own catalog.

| Marketplace | Role |
|---|---|
| `patterson-corp` | Enterprise — capability true for all of Patterson (engineering standards, brand) |
| `actdata-plugins` | ACT Data — this repository |
| `patterson-labs` | Incubating — work that has not yet earned durable status |
| `patterson-dental`, `patterson-vet` | Sub-org — segment-particular capability |

The repository furniture here — the gate battery, the validators, the README shape, the governance
files — follows `patterson-corp`, so someone moving between them finds the same structure.

## Contributing and governance

| File | Purpose |
|---|---|
| [`docs/`](docs/README.md) | Full documentation: onboarding, architecture, verification, troubleshooting, releasing, glossary |
| [`docs/onboarding.md`](docs/onboarding.md) | Start here on day one: environment setup, orientation, and first tasks |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Repository conventions, the gate, and how to add a plugin |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Contributor Covenant, adapted for a B2B engineering context |
| [`SECURITY.md`](SECURITY.md) | Private vulnerability reporting |
| [`CODEOWNERS`](CODEOWNERS) | A reviewing team for every top-level path |
| [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/) | Bug, feature, and new-plugin proposal forms |
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | Runs `scripts/verify-all.sh` on every push and pull request |
| [`.githooks/pre-commit`](.githooks/pre-commit) | The fast local gate (opt in with `git config core.hooksPath .githooks`) |
| [`docs/decisions/`](docs/decisions/README.md) | ADRs, with an index and the format |

## Status and open items

> [!NOTE]
> This repository is new. The items below are known gaps, recorded rather than papered over.

- **Brand assets are placeholders.** No ACT Data logo, wordmark, or palette exists. `docs/assets/`
  ships an invented mark using the inherited Patterson palette. See
  [`docs/assets/README.md`](docs/assets/README.md).
- **Three empty plugin shells** are unregistered, as described above.
- **`act-gitlab-ci`'s pipeline standards are derived, not authoritative.** They are translated from a
  standard written for Azure DevOps and GitHub, which does not permit GitLab and whose approved-tools
  list excludes GitLab's built-in scanners. The conflict is recorded rather than resolved; see
  [`_SOURCES.md`](plugins/act-gitlab-ci/skills/pipeline-standards/_SOURCES.md).
- **The license identifier `LicenseRef-ACT-Internal` is provisional.** ACT Data's licensing posture
  for internal agent tooling has not been confirmed.
- **`act-plugin-dev` is a fork, not a dependency.** It does not track upstream `plugin-dev`.
  Re-syncing is manual; the divergence is recorded in
  [its README](plugins/act-plugin-dev/README.md#upstream-and-divergence).
