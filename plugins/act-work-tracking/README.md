<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../docs/assets/act-wordmark-white.svg">
  <img src="../../docs/assets/act-wordmark.svg" alt="ACT Data" width="260">
</picture>

# act-work-tracking

Zoho Projects work tracking, and writing engineering work up so it can be acted on.

![skills](https://img.shields.io/badge/skills-2-00A8E1?labelColor=003767)
![agents](https://img.shields.io/badge/agents-1-003767)
![commands](https://img.shields.io/badge/commands-3-147EC2)
![config](https://img.shields.io/badge/config-driven-00817D)
![deps](https://img.shields.io/badge/dependencies-curl%20%2B%20jq-58585B)

</div>

---

## Table of contents

- [What this is](#what-this-is)
- [What ships](#what-ships)
- [Skills](#skills)
- [Commands](#commands)
- [Install](#install)
- [Configuration](#configuration)
- [Bulk creation](#bulk-creation)
- [What this plugin does NOT do](#what-this-plugin-does-not-do)
- [Layout](#layout)

## What this is

Two related jobs. Getting work into Zoho Projects correctly, which means knowing the task-versus-issue
distinction and the API's several sharp edges. And writing that work up -- issues, status reports,
assessment documents -- so the reader can act on it.

It ships **no portal IDs, project IDs or user IDs**. Those come from a settings file you write. See
[Configuration](#configuration).

## What ships

| Component | Count | What it is |
|---|---|---|
| Skills | 2 | Zoho Projects mechanics, and reporting and writing conventions |
| Agents | 1 | Deciding what is worth reporting and to whom |
| Commands | 3 | Draft an issue, draft a task, draft the weekly status |
| Scripts | 1 | Bulk creation from JSON, with a credential-free dry run |

## Skills

| Skill | What it covers |
|---|---|
| [`zoho-projects`](skills/zoho-projects/) | Task versus issue, drafting templates, API quirks, bulk creation |
| [`ops-reporting`](skills/ops-reporting/) | Writing conventions, weekly status structure, assessment document routing |

## Commands

| Command | Does |
|---|---|
| `/act-work-tracking:draft-issue` | Draft a concrete work item, checking for duplicates first |
| `/act-work-tracking:draft-task` | Draft a category that will contain issues |
| `/act-work-tracking:weekly-status` | Draft the week's status report |

## Install

```sh
claude plugin marketplace add patterson-agents/actdata-plugins
claude plugin install act-work-tracking@actdata-plugins
```

## Configuration

Create `.claude/act-work-tracking.local.md` in your project. It is gitignored by this repository's
`.gitignore` (`.claude/*.local.md`).

```markdown
# act-work-tracking settings

## Zoho

| Field | Value |
|-------|-------|
| Portal ID | 000000000 |
| Default assignee (zpuid) | 0000000000000000000 |

## Projects

| Project | ID | Prefix | Scope |
|---------|-----|--------|-------|
| Internal Needs | 0000000000000000000 | INT | Platform and infrastructure work |
| Sysadmin | 0000000000000000000 | SYS | Patching, access, hardware |
```

Discover project IDs through the projects list endpoint (use a large page size to avoid pagination),
then record them here rather than looking them up every run.

### Credentials

The bulk-creation script reads these from the environment. Supply them from a secrets manager, never
from a file on disk:

| Variable | Required for |
|---|---|
| `ZOHO_CLIENT_ID` | Live runs |
| `ZOHO_CLIENT_SECRET` | Live runs |
| `ZOHO_REFRESH_TOKEN` | Live runs |
| `ZOHO_PORTAL_ID` | Live runs |
| `ZOHO_PROJECT_ID` | Live runs |
| `ZOHO_ACCOUNTS_DOMAIN` | Optional; regional data centres |
| `ZOHO_API_DOMAIN` | Optional; regional data centres |

`scripts/zoho-create.sh --help` documents the one-time Self Client setup that produces the refresh
token.

> [!NOTE]
> Regional data centres use different top-level domains (`.eu`, `.in`, `.com.au`). A token issued in
> one region does not work against another, and the error does not say so. If authentication succeeds
> but every resource 404s, check the region first.

## Bulk creation

```sh
# Prints the intended API calls. Needs no credentials and makes no network calls.
plugins/act-work-tracking/scripts/zoho-create.sh --dry-run backlog.json

# Live
plugins/act-work-tracking/scripts/zoho-create.sh backlog.json
```

Input schema: [`skills/zoho-projects/examples/sample-backlog.json`](skills/zoho-projects/examples/sample-backlog.json).

> [!WARNING]
> Always dry-run first. The script has no undo, and the API's rate limit (100 requests per 2 minutes)
> means a large run that trips it leaves a half-created backlog to reconcile by hand.

Requires `curl` and `jq`.

## What this plugin does NOT do

> [!CAUTION]
> The bulk script writes to your tracker. It creates items and cannot remove them. `--dry-run` is the
> safety mechanism, and it is not the default.

- **No credential storage.** It reads environment variables and never writes them anywhere.
- **No editing or closing.** It creates items. Updating and closing happen in Zoho.
- **No CSV input.** Removed: the conversion needed an interpreter this repository forbids, and the
  quoting rules made it a reliable source of malformed descriptions. JSON only.
- **No opinion about your categories.** It reads the project structure you have.
- **Not a Zoho client.** For general Zoho work, use the Zoho MCP server.

## Layout

```text
act-work-tracking/
  .claude-plugin/plugin.json
  README.md
  agents/reporting-analyst.md
  commands/
    draft-issue.md  draft-task.md  weekly-status.md
  scripts/
    zoho-create.sh
    tests/run-tests.sh
  skills/
    zoho-projects/
      SKILL.md
      references/  zoho-api.md  task-template.md  issue-template.md
      examples/    sample-backlog.json
    ops-reporting/
      SKILL.md
      references/  writing-conventions.md  weekly-status.md  assessment-docs.md
```
